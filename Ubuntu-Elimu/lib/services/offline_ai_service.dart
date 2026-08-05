import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'package:collection/collection.dart';
import '../models/offline_model.dart';
import '../models/offline_context_params.dart';

class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  static OfflineAIService get instance => _instance;
  OfflineAIService._internal();

  llama.LlamaController? _controller;
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  String? _loadedModelPath;
  OfflineModel? _loadedModel;
  bool _stopRequested = false;

  // ─── Model Lifecycle ────────────────────────────────────────

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ OfflineAIService: Android only. Skipping init.');
      return;
    }
    debugPrint('✅ OfflineAIService initialized');
  }

  Future<bool> loadModel({
    required String modelPath,
    required OfflineModel model,
    dynamic contextParams,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('⚠️ loadModel: Android only.');
      return false;
    }

    try {
      debugPrint('🔄 Loading model: $modelPath');

      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('❌ Model file not found: $modelPath');
        return false;
      }

      if (_isModelLoaded) await unloadModel();

      final params = contextParams is OfflineContextParams
          ? contextParams
          : const OfflineContextParams();

      _controller = llama.LlamaController();
      await _controller!.loadModel(
        modelPath: modelPath,
        threads: params.nThreads,
        contextSize: params.nCtx,
        gpuLayers: params.nGpuLayers > 0 ? params.nGpuLayers : null,
      );

      _isModelLoaded = true;
      _loadedModelPath = modelPath;
      _loadedModel = model;

      debugPrint('✅ Model loaded: ${model.name}');
      return true;
    } catch (e, stack) {
      debugPrint('❌ Failed to load model: $e\n$stack');
      _isModelLoaded = false;
      _loadedModelPath = null;
      _loadedModel = null;
      _controller = null;
      return false;
    }
  }

  Future<void> unloadModel() async {
    try {
      if (_isModelLoaded && _controller != null) {
        await _controller!.dispose();
        debugPrint('✅ Model unloaded');
      }
    } catch (e) {
      debugPrint('⚠️ Unload error: $e');
    } finally {
      _isModelLoaded = false;
      _loadedModelPath = null;
      _loadedModel = null;
      _controller = null;
    }
  }

  // ─── Core Generation (streaming) ────────────────────────────

  Stream<String> generateResponseStream({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 512,
    double temperature = 0.2,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!_isModelLoaded || _controller == null) {
      yield 'Error: No model loaded.';
      return;
    }

    _stopRequested = false;

    try {
      final messages = [
        llama.ChatMessage(role: 'system', content: systemPrompt),
        llama.ChatMessage(role: 'user', content: prompt),
      ];

      final stream = _controller!.generateChat(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      );

      await for (final token in stream) {
        if (_stopRequested) {
          await _controller!.stop();
          break;
        }
        yield token;
      }
    } catch (e) {
      debugPrint('❌ Stream error: $e');
      yield '\n\nError: $e';
    }
  }

  // ─── Core Generation (non-streaming) ────────────────────────

  Future<String> generateResponse({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    final buffer = StringBuffer();
    await for (final token in generateResponseStream(
      prompt: prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
      topK: topK,
      repeatPenalty: repeatPenalty,
    )) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }

  // ─── JSON Generation (with retry) ───────────────────────────

  Future<Map<String, dynamic>?> generateJson({
    required String prompt,
    required String systemPrompt,
    int maxTokens = 800,
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final raw = await generateResponse(
          prompt: prompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens,
          temperature: 0.3,
        );

        final cleaned = _extractJson(raw);
        if (cleaned != null) {
          return jsonDecode(cleaned) as Map<String, dynamic>;
        }

        debugPrint('⚠️ JSON parse failed attempt $attempt — retrying');
      } catch (e) {
        debugPrint('⚠️ JSON generation error attempt $attempt: $e');
      }
    }

    debugPrint('❌ JSON generation failed after $maxRetries retries');
    return null;
  }

  String? _extractJson(String raw) {
    String cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;

    return cleaned.substring(start, end + 1);
  }

  // ─── Education Feature Methods ───────────────────────────────

  Future<Map<String, dynamic>?> summarizeChunks(List<String> chunks) async {
    final context = chunks.join('\n\n---\n\n');

    return generateJson(
      systemPrompt:
          'You are an expert study assistant. You help students understand '
          'academic material clearly and concisely. Always respond with valid '
          'JSON only. No preamble, no explanation, no markdown fences.',
      prompt: '''
Analyze the following study material and return a JSON object with this exact structure:
{
  "title": "short topic title",
  "summary": "2-3 sentence overview",
  "key_concepts": ["concept 1", "concept 2", "concept 3"],
  "exam_focus": ["important point 1", "important point 2"],
  "notes": ["detailed note 1", "detailed note 2", "detailed note 3"]
}

Study material:
$context
''',
      maxTokens: 800,
    );
  }

  Future<List<Map<String, dynamic>>?> generateFlashcards(
    List<String> chunks, {
    int count = 8,
  }) async {
    final context = chunks.join('\n\n---\n\n');

    final result = await generateJson(
      systemPrompt:
          'You are a flashcard generator for students. Create clear, concise '
          'question-answer pairs from the provided material. Always respond '
          'with valid JSON only. No preamble or markdown.',
      prompt: '''
Create exactly $count flashcards from this material. Return a JSON object:
{
  "flashcards": [
    {"q": "question text", "a": "answer text"},
    {"q": "question text", "a": "answer text"}
  ]
}

Material:
$context
''',
      maxTokens: 800,
    );

    if (result == null) return null;
    final list = result['flashcards'];
    if (list is! List) return null;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> generateStudyPlan(
    List<String> chunks, {
    int days = 3,
  }) async {
    final context = chunks.take(3).join('\n\n---\n\n');

    return generateJson(
      systemPrompt:
          'You are an academic study planner. Create structured, realistic '
          'study plans for students. Always respond with valid JSON only.',
      prompt: '''
Create a $days-day study plan for this material. Return:
{
  "plan": [
    {
      "day": 1,
      "focus": "topic name",
      "tasks": ["task 1", "task 2"],
      "duration_minutes": 60
    }
  ],
  "tips": ["study tip 1", "study tip 2"]
}

Material overview:
$context
''',
      maxTokens: 700,
    );
  }

  Stream<String> tutorStream({
    required String userMessage,
    required List<String> contextChunks,
    required List<Map<String, String>> history,
    bool socratic = true,
    String language = 'the same language the student uses',
  }) {
    final context = contextChunks.take(2).join('\n\n---\n\n');

    final recentHistory =
        history.length > 6 ? history.sublist(history.length - 6) : history;
    final historyText = recentHistory.map((m) {
      final role = m['role'] == 'user' ? 'Student' : 'Tutor';
      return '$role: ${m["content"]}';
    }).join('\n');

    final prompt = '''
${historyText.isNotEmpty ? "Previous conversation:\n$historyText\n\n" : ""}Student: $userMessage
''';

    final systemPrompt = socratic
        ? 'You are a Socratic tutor helping a student understand their study '
            'material. Never give direct answers — instead ask guiding questions '
            'that help the student think through the problem themselves. '
            'Be encouraging, patient, and concise. Respond in $language. '
            'Use this document as your knowledge base:\n\n$context'
        : 'You are a clear, direct study assistant helping a student understand '
            'their study material. Answer questions plainly, with worked examples '
            'where useful. Be encouraging, patient, and concise. Respond in '
            '$language. Use this document as your knowledge base:\n\n$context';

    return generateResponseStream(
      systemPrompt: systemPrompt,
      prompt: prompt,
      maxTokens: 400,
      temperature: 0.8,
    );
  }

  Future<Map<String, dynamic>?> gradeAnswer({
    required String question,
    required String correctAnswer,
    required String studentAnswer,
  }) async {
    return generateJson(
      systemPrompt:
          'You are an exam grader. Grade student answers fairly and provide '
          'constructive feedback. Always respond with valid JSON only.',
      prompt: '''
Grade this student answer:

Question: $question
Correct answer: $correctAnswer
Student answer: $studentAnswer

Return:
{
  "score": 8,
  "max_score": 10,
  "feedback": "explanation of what was right/wrong",
  "correct": true
}
''',
      maxTokens: 300,
    );
  }

  Future<String> generateReport({
    required String topic,
    required String depth,
    required String length,
    required List<String> contextChunks,
  }) async {
    final context = contextChunks.join('\n\n---\n\n');

    final depthGuidance = _getDepthGuidance(depth);
    final lengthGuidance = _getLengthGuidance(length);

    return generateResponse(
      systemPrompt:
          'You are a research expert who writes clear, comprehensive reports. '
          'Your reports are well-structured, accurate, and use the provided '
          'material as the knowledge base. Write in a professional tone.',
      prompt: '''
Write a research report on the following topic:

Topic: $topic
Depth: $depthGuidance
Length: $lengthGuidance

Based on this material:
$context

Structure your report with clear sections including an introduction, main findings, and conclusion.
''',
      maxTokens: _getMaxTokensForLength(length),
      temperature: 0.7,
    );
  }

  String _getDepthGuidance(String depth) {
    switch (depth.toLowerCase()) {
      case 'shallow':
        return 'Surface level overview with basic concepts';
      case 'medium':
        return 'Moderate depth with key points and explanations';
      case 'deep':
        return 'In-depth analysis with detailed explanations and nuances';
      default:
        return 'Moderate depth with key points and explanations';
    }
  }

  String _getLengthGuidance(String length) {
    switch (length.toLowerCase()) {
      case 'short':
        return 'Concise (2-3 pages equivalent)';
      case 'medium':
        return 'Moderate length (4-6 pages equivalent)';
      case 'long':
        return 'Comprehensive (7-10 pages equivalent)';
      default:
        return 'Moderate length (4-6 pages equivalent)';
    }
  }

  int _getMaxTokensForLength(String length) {
    switch (length.toLowerCase()) {
      case 'short':
        return 600;
      case 'medium':
        return 1200;
      case 'long':
        return 2000;
      default:
        return 1200;
    }
  }

  Future<void> stopGeneration() async {
    _stopRequested = true;
    if (_controller != null) await _controller!.stop();
  }

  Future<void> dispose() async {
    await stopGeneration();
    await unloadModel();
  }

  bool get isAvailable => Platform.isAndroid && _isModelLoaded;

  Map<String, dynamic>? getModelInfo() {
    if (!_isModelLoaded || _loadedModel == null) return null;
    return {
      'name': _loadedModel!.name,
      'path': _loadedModelPath,
      'status': 'loaded',
    };
  }

  OfflineModel? get loadedModel => _loadedModel;
  String? get loadedModelPath => _loadedModelPath;
}
