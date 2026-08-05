import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class MockEmbeddingProvider implements EmbeddingProvider {
  @override
  int get dimension => 384;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<double>> embed(String text) async {
    return List.filled(384, 0.1);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    return texts.map((_) => List.filled(384, 0.1)).toList();
  }
}

class ErrorEmbeddingProvider implements EmbeddingProvider {
  @override
  int get dimension => 384;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<double>> embed(String text) async {
    throw Exception('Embedding model failed to load');
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    throw Exception('Embedding model failed to load');
  }
}

class FakeAIServiceForRag implements OfflineAIService {
  List<ChatMessage> lastReceivedMessages = [];

  @override
  OfflineModel? get loadedModel => OfflineModel(
        id: 'mock-model',
        name: 'Mock Model',
        author: 'Test',
        size: 1000000,
        filename: 'mock.gguf',
        contextSize: 4096,
        isDownloaded: true,
      );

  @override
  bool get isModelLoaded => true;

  @override
  String? get loadedModelPath => '/mock/path/mock.gguf';

  @override
  Future<String> generateHistoryChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    lastReceivedMessages = List.from(messages);
    return 'RAG Answer';
  }

  @override
  Stream<String> generateHistoryChatStream({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    lastReceivedMessages = List.from(messages);
    yield 'Streaming RAG Answer';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DenizenRagSession Tests', () {
    test('DenizenRagSession falls back gracefully if vector storage is uninitialized', () async {
      final aiService = FakeAIServiceForRag();
      final embeddingProvider = MockEmbeddingProvider();
      final storageService = VectorStorageService(); // Not initialized

      final ragSession = DenizenRagSession(
        aiService,
        embeddingProvider,
        storageService,
        baseSystemPrompt: 'You are a medical assistant.',
      );

      final reply = await ragSession.chat('What are malaria symptoms?');

      expect(reply, equals('RAG Answer'));
      expect(aiService.lastReceivedMessages.first.role, equals('system'));
      expect(aiService.lastReceivedMessages.first.content, contains('You are a medical assistant.'));
    });

    test('DenizenRagSession falls back gracefully if embedding provider throws exception', () async {
      final aiService = FakeAIServiceForRag();
      final embeddingProvider = ErrorEmbeddingProvider();
      final storageService = VectorStorageService();

      final ragSession = DenizenRagSession(
        aiService,
        embeddingProvider,
        storageService,
        baseSystemPrompt: 'You are a medical assistant.',
      );

      final reply = await ragSession.chat('What is malaria?');

      expect(reply, equals('RAG Answer'));
      expect(aiService.lastReceivedMessages.last.content, equals('What is malaria?'));
    });

    test('DenizenRagSession streams response cleanly without crashing', () async {
      final aiService = FakeAIServiceForRag();
      final embeddingProvider = MockEmbeddingProvider();
      final storageService = VectorStorageService();

      final ragSession = DenizenRagSession(
        aiService,
        embeddingProvider,
        storageService,
        baseSystemPrompt: 'You are a medical assistant.',
      );

      final stream = ragSession.streamChat('Explain fever');
      final tokens = await stream.toList();

      expect(tokens, equals(['Streaming RAG Answer']));
      expect(aiService.lastReceivedMessages.last.content, equals('Explain fever'));
    });
  });
}
