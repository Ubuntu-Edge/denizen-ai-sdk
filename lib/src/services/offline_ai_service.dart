import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import '../models/offline_model.dart';
import '../models/offline_context_params.dart';

/// Service for offline AI inference using llama.cpp via llama_flutter_android package.
///
/// This service provides true on-device AI inference with GGUF models on Android.
/// Wraps LlamaController to provide streaming and non-streaming text generation.
///
/// **Features:**
/// - Android only (uses llama.cpp with ARM64 NEON optimizations)
/// - Streaming token generation
/// - Stop generation mid-process
/// - ChatML prompt formatting
/// - 18 generation parameters for fine control
///
/// **Performance:**
/// - Typical: 4-15 tokens/sec on mid-range Android devices
/// - Supports Q2_K to Q8_0 quantization levels
/// - Context sizes up to 8192 tokens (device-dependent)
class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._internal();
  static OfflineAIService get instance => _instance;

  OfflineAIService._internal();

  /// LlamaController instance for inference
  LlamaController? _controller;
  
  /// Track if model is currently loaded
  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  /// Currently loaded model info
  String? _loadedModelPath;
  OfflineModel? _loadedModel;

  /// Flag to stop generation
  bool _stopRequested = false;

  /// Initialize service
  Future<void> initialize() async {
    debugPrint('✅ OfflineAIService initialized');
  }

  /// Load a GGUF model from device storage
  /// Returns true if model loaded successfully
  Future<bool> loadModel({
    required String modelPath,
    required OfflineModel model,
    dynamic contextParams,
  }) async {
    try {
      debugPrint('🔄 Loading model from: $modelPath');
      
      // Check if file exists
      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('❌ Model file not found: $modelPath');
        return false;
      }
      
      // Unload existing model if any
      if (_isModelLoaded) {
        await unloadModel();
      }
      
      // Extract context params
      OfflineContextParams params;
      if (contextParams is OfflineContextParams) {
        params = contextParams;
      } else {
        params = const OfflineContextParams();
      }
      
      // Create new controller
      _controller = LlamaController();
      
      // Load the model using LlamaController with hardware acceleration fallback
      try {
        await _controller!.loadModel(
          modelPath: modelPath,
          threads: params.nThreads,
          contextSize: params.nCtx,
          gpuLayers: params.nGpuLayers > 0 ? params.nGpuLayers : null,
        );
      } catch (e) {
        if (params.nGpuLayers > 0) {
          debugPrint('⚠️ Hardware acceleration failed: $e. Falling back to CPU (NEON) inference.');
          // Dispose the failed controller and create a fresh one for fallback
          await _controller!.dispose();
          _controller = LlamaController();
          
          await _controller!.loadModel(
            modelPath: modelPath,
            threads: params.nThreads,
            contextSize: params.nCtx,
            gpuLayers: 0, // Force CPU
          );
        } else {
          // If already on CPU or an unexpected error occurred, rethrow
          rethrow;
        }
      }
      
      _isModelLoaded = true;
      _loadedModelPath = modelPath;
      _loadedModel = model;
      
      debugPrint('✅ Model loaded successfully: ${model.name}');
      debugPrint('   Context size: ${params.nCtx}');
      debugPrint('   Threads: ${params.nThreads}');
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load model: $e');
      debugPrint('Stack trace: $stackTrace');
      _isModelLoaded = false;
      _loadedModelPath = null;
      _loadedModel = null;
      _controller = null;
      return false;
    }
  }

  /// Unload current model
  Future<void> unloadModel() async {
    try {
      if (_isModelLoaded && _controller != null) {
        await _controller!.dispose();
        debugPrint('✅ Model unloaded');
      }
    } catch (e) {
      debugPrint('⚠️ Error unloading model: $e');
    } finally {
      _isModelLoaded = false;
      _loadedModelPath = null;
      _loadedModel = null;
      _controller = null;
    }
  }

  /// Generate text (non-streaming) - collects all tokens and returns full response
  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
    List<String>? stopSequences,
  }) async {
    if (!_isModelLoaded || _controller == null) {
      return 'Error: No model loaded. Please load an offline AI model first.';
    }

    try {
      final StringBuffer result = StringBuffer();
      
      final stream = _controller!.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      );
      
      await for (final token in stream) {
        result.write(token);
        
        // Check for stop sequences manually
        if (stopSequences != null) {
          final current = result.toString();
          for (final stopSeq in stopSequences) {
            if (current.contains(stopSeq)) {
              await _controller!.stop();
              return current.split(stopSeq).first;
            }
          }
        }
      }
      
      return result.toString();
    } catch (e) {
      debugPrint('❌ Generation error: $e');
      return 'Error during generation: $e';
    }
  }

  /// Generate response (non-streaming) with chat prompt formatting
  Future<String> generateResponse({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    if (!_isModelLoaded || _controller == null) {
      return 'Error: No model loaded. Please load an offline AI model first.';
    }
    
    try {
      final StringBuffer result = StringBuffer();
      final messages = [
        ChatMessage(
          role: 'system',
          content: systemPrompt ?? 'You are a helpful medical assistant for Community Health Workers.',
        ),
        ChatMessage(
          role: 'user',
          content: prompt,
        ),
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
        result.write(token);
      }
      
      return result.toString();
    } catch (e) {
      debugPrint('❌ Generation error: $e');
      return 'Error during generation: $e';
    }
  }

  /// Generate response (non-streaming) with full chat history
  Future<String> generateHistoryChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    if (!_isModelLoaded || _controller == null) {
      return 'Error: No model loaded. Please load an offline AI model first.';
    }
    
    try {
      final StringBuffer result = StringBuffer();
      final stream = _controller!.generateChat(
        messages: messages,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      );
      
      await for (final token in stream) {
        result.write(token);
      }
      
      return result.toString();
    } catch (e) {
      debugPrint('❌ Generation error: $e');
      return 'Error during generation: $e';
    }
  }

  /// Generate response with streaming and full chat history
  Stream<String> generateHistoryChatStream({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!_isModelLoaded || _controller == null) {
      yield 'Error: No model loaded. Please load an offline AI model first.';
      return;
    }

    _stopRequested = false;
    
    try {
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
          debugPrint('⚠️ Generation stopped by user');
          await _controller!.stop();
          break;
        }
        yield token;
      }
    } catch (e) {
      debugPrint('❌ Streaming generation error: $e');
      yield '\n\nError during generation: $e';
    }
  }


  /// Generate text with streaming
  Stream<String> generateStream({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    int topK = 40,
    double repeatPenalty = 1.1,
    List<String>? stopSequences,
  }) async* {
    if (!_isModelLoaded || _controller == null) {
      yield 'Error: No model loaded. Please load an offline AI model first.';
      return;
    }

    _stopRequested = false;
    
    try {
      final stream = _controller!.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      );
      
      final StringBuffer accumulated = StringBuffer();
      
      await for (final token in stream) {
        if (_stopRequested) {
          debugPrint('⚠️ Generation stopped by user');
          await _controller!.stop();
          break;
        }
        
        accumulated.write(token);
        
        // Check for stop sequences manually
        if (stopSequences != null) {
          final current = accumulated.toString();
          for (final stopSeq in stopSequences) {
            if (current.contains(stopSeq)) {
              await _controller!.stop();
              return;
            }
          }
        }
        
        yield token;
      }
    } catch (e) {
      debugPrint('❌ Streaming generation error: $e');
      yield '\n\nError during generation: $e';
    }
  }

  /// Generate response with streaming and chat formatting
  Stream<String> generateResponseStream({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!_isModelLoaded || _controller == null) {
      yield 'Error: No model loaded. Please load an offline AI model first.';
      return;
    }

    _stopRequested = false;
    
    try {
      final messages = [
        ChatMessage(
          role: 'system',
          content: systemPrompt ?? 'You are a helpful medical assistant for Community Health Workers. Provide clear, evidence-based medical guidance.',
        ),
        ChatMessage(
          role: 'user',
          content: prompt,
        ),
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
          debugPrint('⚠️ Generation stopped by user');
          await _controller!.stop();
          break;
        }
        yield token;
      }
    } catch (e) {
      debugPrint('❌ Streaming generation error: $e');
      yield '\n\nError during generation: $e';
    }
  }

  /// Generate with token batching for smoother UI updates
  Stream<String> generateResponseWithBatching({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
    int batchSize = 3,
  }) async* {
    StringBuffer batch = StringBuffer();
    int tokenCount = 0;
    
    await for (final token in generateResponseStream(
      prompt: prompt,
      systemPrompt: systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
      topK: topK,
      repeatPenalty: repeatPenalty,
    )) {
      batch.write(token);
      tokenCount++;
      
      // Emit batch when size reached or on newlines
      if (tokenCount >= batchSize || token.contains('\n')) {
        yield batch.toString();
        batch.clear();
        tokenCount = 0;
      }
    }
    
    // Emit any remaining tokens
    if (batch.isNotEmpty) {
      yield batch.toString();
    }
  }

  /// Stop current generation
  Future<void> stopGeneration() async {
    _stopRequested = true;
    if (_controller != null) {
      await _controller!.stop();
    }
    debugPrint('✅ Generation stop requested');
  }

  /// Get model info
  Map<String, dynamic>? getModelInfo() {
    if (!_isModelLoaded || _loadedModel == null) {
      return null;
    }
    return {
      'name': _loadedModel!.name,
      'path': _loadedModelPath,
      'contextSize': _loadedModel!.contextSize,
      'status': 'loaded',
    };
  }

  /// Format prompt for chat using ChatML format (kept for compatibility)
  String formatChatPrompt({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required String userMessage,
  }) {
    StringBuffer prompt = StringBuffer();
    prompt.writeln('<|im_start|>system');
    prompt.writeln(systemPrompt);
    prompt.writeln('<|im_end|>');

    for (var msg in messages) {
      String role = msg['role'] ?? 'user';
      String content = msg['content'] ?? '';
      prompt.writeln('<|im_start|>$role');
      prompt.writeln(content);
      prompt.writeln('<|im_end|>');
    }

    prompt.writeln('<|im_start|>user');
    prompt.writeln(userMessage);
    prompt.writeln('<|im_end|>');
    prompt.writeln('<|im_start|>assistant');

    return prompt.toString();
  }

  /// Check if a model file exists
  Future<bool> modelExists(String modelPath) async {
    final file = File(modelPath);
    return await file.exists();
  }

  /// Get currently loaded model
  OfflineModel? get loadedModel => _loadedModel;
  String? get loadedModelPath => _loadedModelPath;

  /// Dispose resources
  Future<void> dispose() async {
    await stopGeneration();
    await unloadModel();
  }
}
