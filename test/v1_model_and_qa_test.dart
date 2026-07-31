import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/services/model_download_service.dart';

class MockOfflineAIService extends Fake implements OfflineAIService {
  OfflineModel? _model;
  bool _isLoaded = false;
  String? _loadedPath;

  @override
  bool get isModelLoaded => _isLoaded;

  @override
  String? get loadedModelPath => _loadedPath;

  @override
  OfflineModel? get loadedModel => _model;

  @override
  Future<bool> loadModel({
    required String modelPath,
    required OfflineModel model,
    dynamic contextParams,
  }) async {
    _loadedPath = modelPath;
    _model = model;
    _isLoaded = true;
    return true;
  }

  @override
  Future<String> generateHistoryChat({
    required List<dynamic> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    return 'Mock response for: ${messages.last.content}';
  }

  @override
  Stream<String> generateHistoryChatStream({
    required List<dynamic> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    yield 'Mock ';
    yield 'stream ';
    yield 'reply';
  }
}

void main() {
  group('v1.0 SDK Release Audit - Model Management & Q&A', () {
    late MockOfflineAIService mockAiService;
    late DenizenModelManager modelManager;

    setUp(() {
      mockAiService = MockOfflineAIService();
      modelManager = DenizenModelManager(
        ModelDownloadService.instance,
        mockAiService,
      );
    });

    test('DenizenSession supports chat and sendMessage alias', () async {
      final session = DenizenSession(
        mockAiService,
        systemPrompt: 'You are a helpful assistant',
      );

      final reply1 = await session.chat('Hello world');
      expect(reply1, contains('Mock response for: Hello world'));

      final reply2 = await session.sendMessage('How are you?');
      expect(reply2, contains('Mock response for: How are you?'));

      expect(session.history.length, equals(5)); // System + 2 * (User + Assistant)
    });

    test('DenizenSession supports streamChat and sendMessageStream alias', () async {
      final session = DenizenSession(mockAiService);

      final tokens1 = await session.streamChat('Test stream').toList();
      expect(tokens1.join(), equals('Mock stream reply'));

      final tokens2 = await session.sendMessageStream('Test stream alias').toList();
      expect(tokens2.join(), equals('Mock stream reply'));
    });

    test('DenizenModelManager loadFromFile loads GGUF model file into engine', () async {
      final tempDir = Directory.systemTemp.createTempSync('denizen_test_');
      final modelFile = File('${tempDir.path}/test_model.gguf');
      await modelFile.writeAsBytes(List.generate(2000, (i) => i % 256));

      try {
        final loaded = await modelManager.loadFromFile(
          modelFile,
          contextSize: 2048,
        );

        expect(loaded, isTrue);
        expect(mockAiService.isModelLoaded, isTrue);
        expect(mockAiService.loadedModelPath, equals(modelFile.path));
        expect(mockAiService.loadedModel?.filename, equals('test_model.gguf'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('DenizenModelManager handles model deletion gracefully', () async {
      // Deleting a non-existent model ID should complete without throwing
      await expectLater(
        modelManager.deleteModel('non_existent_model_id'),
        completes,
      );
    });
  });
}
