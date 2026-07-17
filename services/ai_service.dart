import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static final AIService instance = AIService._init();
  AIService._init();

  late final String _apiToken;
  static const String _inferenceApiUrl =
      'https://router.huggingface.co/v1/chat/completions';

  double _temperature = 0.6; // Lowered for more consistent safety
  double _topP = 0.9;
  int _maxNewTokens = 450;

  bool _isInferenceRunning = false;

  bool get isLoaded => true;
  bool get isInferenceRunning => _isInferenceRunning;

  Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
      _apiToken = dotenv.env['HF_API_TOKEN'] ?? '';
    } catch (e) {
      _apiToken = '';
      debugPrint('⚠️ .env file not loaded - online AI mode unavailable');
    }

    debugPrint(_apiToken.isEmpty
        ? '⚠️ HF_API_TOKEN missing - online AI unavailable (use offline mode)'
        : '✅ Medical AI (Gemma-3-27B) with guardrails ready');
  }

  String getModelInfo() => 'Medical AI: Medgemma 27b (Safe Mode)';

  void setTemperature(double temp) => _temperature = temp.clamp(0.0, 1.0);
  void setTopP(double topP) => _topP = topP.clamp(0.0, 1.0);
  void setContextSize(int tokens) => _maxNewTokens = tokens.clamp(128, 500);

  // Detect if text is primarily in Kiswahili
  String _detectLanguage(String text) {
    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+'));

    // Swahili-specific words and medical terms
    final swahiliWords = [
      'habari',
      'jambo',
      'mambo',
      'mzuri',
      'nzuri',
      'sana',
      'asante',
      'tafadhali',
      'ndio',
      'hapana',
      'ndiyo',
      'sawa',
      'pole',
      'homa',
      'maumivu',
      'mguu',
      'mkono',
      'kichwa',
      'tumbo',
      'daktari',
      'hospitali',
      'mgonjwa',
      'ugonjwa',
      'vipi',
      'gani',
      'nini',
      'wapi',
      'lini',
      'je',
      'mtoto',
      'mteja',
      'mtu',
      'kwa',
      'kutoka',
      'kwenda',
      'leo',
      'jana',
      'kesho',
      'heri',
      'ahsante',
      'karibu',
      'shikamoo',
      'marahaba',
      'upele',
      'kikohozi',
      'kuhara',
      'kutapika',
      'uzito',
      'urefu',
      'miaka',
      'wiki',
      'siku',
      'mwezi',
      'kipimo',
      'joto',
      'baridi',
      'uchovu',
      'kichefuchefu',
      'kitunguu'
    ];

    // English-specific words and medical terms
    final englishWords = [
      'child', 'patient', 'fever', 'cough', 'cold', 'flu', 'pain', 'ache',
      'headache', 'stomach', 'vomit', 'diarrhea', 'rash', 'symptoms',
      'symptom', 'sick', 'ill', 'hurt', 'injury', 'treatment', 'doctor',
      'hospital', 'clinic', 'nurse', 'health', 'medical', 'care', 'help',
      'please', 'thank', 'need', 'have', 'has', 'feel', 'feeling', 'year',
      'month', 'week', 'day', 'old', 'years', 'months', 'weeks', 'days',
      'temperature', 'high', 'low', 'better', 'worse', 'throat', 'chest',
      'back', 'leg', 'arm', 'hand', 'foot', 'eye', 'ear', 'nose', 'mouth',
      'body', 'breathing', 'breathe', 'tired', 'weak', 'dizzy', 'nausea'
    ];

    int swahiliCount = 0;
    int englishCount = 0;

    for (final word in words) {
      if (swahiliWords.any((sw) => word == sw || word.startsWith(sw))) {
        swahiliCount++;
      }
      if (englishWords.any((ew) => word == ew || word.startsWith(ew))) {
        englishCount++;
      }
    }

    if (swahiliCount > englishCount) {
      return 'sw';
    } else if (englishCount > swahiliCount) {
      return 'en';
    } else {
      if (lowerText.contains('homa') ||
          lowerText.contains('mtoto') ||
          lowerText.contains('mgonjwa') ||
          lowerText.contains('vipi')) {
        return 'sw';
      }
      return 'en';
    }
  }

  // Check if message is a greeting
  bool _isGreeting(String text) {
    final lowerText = text.toLowerCase().trim();

    final exactGreetings = [
      'hello', 'hi', 'hey', 'howdy', 'hola', 'morning', 'afternoon',
      'evening', 'habari', 'jambo', 'mambo', 'shikamoo', 'hujambo',
      'hamjambo', 'vipi', 'sasa', 'poa', 'niaje'
    ];

    final containsGreetings = [
      'good morning', 'good afternoon', 'good evening', 'good day',
      'what\'s up', 'whats up', 'how are you', 'how are you doing',
      'how do you do', 'nice to meet', 'pleased to meet', 'habari yako',
      'habari za asubuhi', 'habari za mchana', 'habari za jioni',
      'u hali gani', 'hali gani', 'mambo vipi', 'habari za leo',
      'habari gani', 'salama', 'sijambo'
    ];

    if (text.split(RegExp(r'\s+')).length <= 2) {
      if (exactGreetings.any(
          (g) => lowerText == g || lowerText == '$g!' || lowerText == '$g?')) {
        return true;
      }
    }

    return containsGreetings.any((greeting) => lowerText.contains(greeting));
  }

  // MEDICAL GUARDRAIL + SAFE STRUCTURE
  List<Map<String, String>> _buildMessages(String userPrompt) {
    final language = _detectLanguage(userPrompt);
    final isGreeting = _isGreeting(userPrompt);

    debugPrint('🌍 Language detected: $language');
    debugPrint('👋 Is greeting: $isGreeting');
    debugPrint('💬 User prompt: $userPrompt');

    if (isGreeting) {
      final greetingSystemContent = language == 'sw'
          ? '''Wewe ni msaidizi wa afya mwenye upole. Pokea salamu kwa urafiki na uliza jinsi unavyoweza kusaidia.'''
          : '''You are a friendly medical assistant. Respond to greetings warmly and ask how you can help.''';

      return [
        {'role': 'system', 'content': greetingSystemContent},
        {'role': 'user', 'content': userPrompt}
      ];
    }

    final systemContent = language == 'sw'
        ? '''Wewe ni msaidizi wa huduma ya afya kwa wafanyakazi wa afya ya jamii nchini Kenya.

KANUNI ZA USALAMA:
- USITOE utambuzi wa ugonjwa wowote
- USIPENDEKEZE dawa au kipimo chochote
- USISEME "dharura" isipokuwa kuna dalili za hatari ya maisha
- USIAHIDI uponyaji au matokeo
- USISAIDIE maswali kuhusu utoaji mimba, kujitia, vurugu, au vitendo haramu
- USIJIFANYE kuwa daktari au mtaalamu wa afya

JUKUMU LAKO:
- Tathmini dalili ambazo mfanyakazi wa afya anaripoti
- Pendekeza hali za kawaida zinazowezekana (kwa mfano: "inaweza kuhusiana na...")
- Toa ushauri wa jumla wa usalama (kupumzika, maji, ufuatiliaji)
- Daima elekeza kwa huduma ya kitaalamu inapohitajika
- Endelea na heshima, huruma, na maarifa

MUUNDO WA JIBU (kila wakati tumia Kiswahili):
Tathmini: [Sentensi 1-2 kuhusu dalili - hakuna utambuzi]
Hatua:
- [hatua ya kwanza]
- [hatua ya pili]
- [hatua ya tatu kama inahitajika]
Muhimu: [Sentensi moja: lini kutafuta msaada wa kitaalamu]

Jibu kwa ufupi. Maandishi ya kawaida tu - hakuna nyota, herufi maalum, wala alama.'''
        : '''You are a medical triage assistant for community health workers in Kenya.

SAFETY RULES:
- NEVER diagnose any disease or condition
- NEVER recommend specific medicines or dosages
- NEVER say "urgent" or "emergency" unless life-threatening
- NEVER guarantee recovery or outcomes
- NEVER answer questions about abortion, suicide, violence, or illegal acts
- NEVER pretend to be a doctor or medical professional

YOUR ROLE:
- Analyze symptoms reported by the community health worker
- Suggest possible common conditions (e.g., "may be related to...")
- Give safe general advice (rest, fluids, observation)
- Always direct to professional care when needed
- Keep calm, caring, and evidence-based

RESPONSE FORMAT (always use English):
Assessment: [1-2 sentences on what symptoms may suggest. No diagnosis.]
Action:
- [first thing to do]
- [second action]
- [third action if needed]
Important: [One sentence: when to seek professional care or red flags]

Keep each section brief. No asterisks, hashtags, numbered lists, or markdown. Plain text only.''';

    return [
      {'role': 'system', 'content': systemContent},
      {'role': 'user', 'content': userPrompt}
    ];
  }

  // FINAL SAFETY FILTER — catches anything the model missed
  String _applySafetyFilter(String response) {
    final lower = response.toLowerCase();

    final blockedTriggers = [
      'prescription', 'medicine', 'tablet', 'syrup', 'injection',
      'dosage', 'mg ', 'ml ', 'antibiotic', 'amoxicillin', 'ibuprofen',
      'paracetamol', 'rush to hospital',
      'cancer', 'hiv', 'tb ', 'tuberculosis', 'seizure', 'unconscious',
      'abortion', 'miscarriage', 'suicide', 'poison', 'overdose',
      'dawa', 'sindano', 'kliniki ya dharura', 'saratani', 'kifafa'
    ];

    if (blockedTriggers.any((trigger) => lower.contains(trigger))) {
      final hasSwahili = lower.contains('tathmini') ||
          lower.contains('hatua') ||
          lower.contains('muhimu');

      if (hasSwahili) {
        return '''Siwezi kutoa utambuzi wa matibabu au kupendekeza dawa yoyote.
Tafadhali peleka mgonjwa kwenye kituo cha afya au hospitali iliyo karibu.
AI hii ni kwa msaada wa jumla tu na haiwezi kubadilisha daktari mwenye sifa.'''
            .trim();
      }

      return '''I cannot give medical diagnosis or recommend any treatment or medicine.
Please take the patient to the nearest health center or hospital immediately.
This AI is only for general support and cannot replace a qualified doctor.'''
          .trim();
    }

    final hasEnglishFormat =
        lower.contains('assessment:') && lower.contains('action:');
    final hasSwahiliFormat =
        lower.contains('tathmini:') && lower.contains('hatua:');

    if (!hasEnglishFormat && !hasSwahiliFormat) {
      return '''Assessment: Unable to provide specific medical assessment
Action: Continue monitoring and follow local health guidelines
Important: Please visit a qualified doctor or clinic soon'''
          .trim();
    }

    return response.trim();
  }

  String _cleanResponse(String raw) {
    return raw
        .replaceAll(RegExp(r'(?m)^\*\s+'), '- ')
        .replaceAll(RegExp(r'[#✦✓❌⚠\[\]]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Takes any model response format and normalises it into
  /// Assessment / Action / Important sections.
  String _reformatToSections(String response) {
    final lower = response.toLowerCase();

    final lines = response
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final introLines = <String>[];
    final bulletLines = <String>[];
    String closingLine = '';
    bool inList = false;

    final skipPatterns = RegExp(
      r"^(okay|ok|i understand|i see|sure|certainly|here'?s|here is|based on|let me|i'll|i will)",
      caseSensitive: false,
    );

    for (final line in lines) {
      final isBullet = RegExp(r'^(\d+[.)\-]|[-•*])\s*').hasMatch(line);

      if (isBullet) {
        inList = true;
        final cleaned = line
            .replaceFirst(RegExp(r'^\d+[.)\-]\s*'), '')
            .replaceFirst(RegExp(r'^[-•*]\s*'), '')
            .trim();
        if (cleaned.isNotEmpty) bulletLines.add(cleaned);
      } else if (!inList) {
        if (!skipPatterns.hasMatch(line) && line.length > 15) {
          introLines.add(line);
        }
      } else {
        final isClosing = RegExp(
          r'seek|doctor|clinic|hospital|health center|professional|care',
          caseSensitive: false,
        ).hasMatch(line);
        if (isClosing && closingLine.isEmpty) closingLine = line;
      }
    }

    final sb = StringBuffer();

    if (introLines.isNotEmpty) {
      sb.writeln('Assessment: ${introLines.take(2).join(' ')}');
    } else {
      sb.writeln(
          'Assessment: Symptoms may be related to a common infection or condition.');
    }

    if (bulletLines.isNotEmpty) {
      sb.writeln('Action:');
      for (final bullet in bulletLines.take(4)) {
        final short = bullet.contains('.') && bullet.indexOf('.') < 90
            ? bullet.substring(0, bullet.indexOf('.') + 1)
            : bullet.length > 90
                ? '${bullet.substring(0, bullet.lastIndexOf(' ', 90))}...'
                : bullet;
        sb.writeln('- $short');
      }
    } else {
      sb.writeln(
          'Action:\n- Rest and stay hydrated\n- Monitor temperature and symptoms');
    }

    if (closingLine.isNotEmpty) {
      sb.writeln('Important: $closingLine');
    } else {
      sb.writeln(
          'Important: Seek medical care if symptoms worsen or persist beyond 3 days.');
    }

    return sb.toString().trim();
  }

  Future<String> generateResponse(String userPrompt) async {
    if (_apiToken.isEmpty) {
      throw AIServiceException(
          'Missing API token. Please configure HF_API_TOKEN in .env file.',
          isConfigError: true);
    }

    if (_isInferenceRunning) {
      throw AIServiceException(
          'Please wait for the current request to complete.');
    }

    _isInferenceRunning = true;

    try {
      final response = await http
          .post(
            Uri.parse(_inferenceApiUrl),
            headers: {
              'Authorization': 'Bearer $_apiToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': 'google/medgemma-4b-it',
              'messages': _buildMessages(userPrompt),
              'max_tokens': _maxNewTokens,
              'temperature': _temperature,
              'top_p': _topP,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';

        String safe = _cleanResponse(content);
        String structured = _reformatToSections(safe);
        String finalResponse = _applySafetyFilter(structured);

        _isInferenceRunning = false;
        return finalResponse;
      } else {
        _isInferenceRunning = false;
        throw AIServiceException(
            'Service temporarily unavailable (${response.statusCode}). Try again soon.',
            isServerError: true);
      }
    } catch (e) {
      _isInferenceRunning = false;
      if (e is AIServiceException) rethrow;
      throw AIServiceException('No internet connection', isNetworkError: true);
    }
  }

  Stream<String> generateResponseStream(String prompt) async* {
    final full = await generateResponse(prompt);
    for (final word in full.split(' ')) {
      await Future.delayed(const Duration(milliseconds: 40));
      yield '$word ';
    }
  }

  /// System prompt to use when running the offline GGUF model.
  /// Pass this to [OfflineAIService.generateResponseStream].
  static const String offlineSystemPrompt =
      'You are a CHW (Community Health Worker) assistant. '
      'Give brief, safe, evidence-based guidance only. '
      'Never prescribe medicine or make diagnoses.\n\n'
      'RESPONSE FORMAT (always use English):\n'
      'Assessment: [1-2 sentences on what symptoms may suggest. No diagnosis.]\n'
      'Action:\n'
      '- [first thing to do]\n'
      '- [second action]\n'
      '- [third action if needed]\n'
      'Important: [One sentence: when to seek professional care or red flags]\n\n'
      'Keep each section brief. No asterisks, hashtags, numbered lists, or markdown. Plain text only.';

  /// Post-process a completed offline model response the same way the online
  /// pipeline does: strip markdown, normalise sections, apply safety filter.
  String processOfflineResponse(String raw) {
    final cleaned = _cleanResponse(raw);
    final structured = _reformatToSections(cleaned);
    return _applySafetyFilter(structured);
  }

  Future<void> loadModel() async {}
  Future<void> reloadModel() async {}
  Future<void> unloadModel() async {}
  void resetConversation() {}
  void dispose() {}
}

/// Exception thrown by AIService
class AIServiceException implements Exception {
  final String message;
  final bool isNetworkError;
  final bool isServerError;
  final bool isConfigError;

  AIServiceException(
    this.message, {
    this.isNetworkError = false,
    this.isServerError = false,
    this.isConfigError = false,
  });

  @override
  String toString() => message;
}
