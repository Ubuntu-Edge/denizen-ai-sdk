import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class FakeOfflineAIService implements OfflineAIService {
  @override
  OfflineModel? get loadedModel => OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2390000000,
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description: 'Mock',
        contextSize: 600, // Make context small for easy testing
        isDownloaded: true,
        downloadProgress: 100,
      );

  @override
  bool get isModelLoaded => true;

  @override
  String? get loadedModelPath => '/mock/path/phi.gguf';

  @override
  Future<String> generateHistoryChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    return 'Assistant Reply';
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
    yield 'Streaming Assistant Reply';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Session initializes with optional system prompt', () {
    final service = FakeOfflineAIService();
    
    final session1 = DenizenSession(service);
    expect(session1.history.isEmpty, isTrue);

    final session2 = DenizenSession(service, systemPrompt: 'System Instruction');
    expect(session2.history.length, equals(1));
    expect(session2.history.first.role, equals(DenizenRole.system));
    expect(session2.history.first.content, equals('System Instruction'));
  });

  test('Session keeps messages within context budget', () async {
    final service = FakeOfflineAIService();
    
    // Budget = 1000 tokens (derived from FakeOfflineAIService model)
    // Safety buffer = 512. Max allowed = 488 tokens.
    // 488 tokens * 4 characters/token = 1952 characters allowed.
    final session = DenizenSession(service, systemPrompt: 'System Prompt');

    // Send a message that fits easily
    final reply = await session.chat('Hello');
    expect(reply, equals('Assistant Reply'));
    expect(session.history.length, equals(3)); // System, User, Assistant
  });

  test('Session sliding window evicts oldest non-system message when budget is exceeded', () async {
    final service = FakeOfflineAIService();
    
    // Context size = 1000. Max allowed = 488 tokens (~1952 chars).
    final session = DenizenSession(service, systemPrompt: 'System Prompt');

    // Add multiple turns
    await session.chat('Small User Message 1'); // Turn 1 (User + Assistant)
    await session.chat('Small User Message 2'); // Turn 2 (User + Assistant)

    expect(session.history.length, equals(5)); // System, User1, Asst1, User2, Asst2

    // Now send a giant message that triggers eviction but leaves room for System + newest User
    // Giant message has ~1500 chars (375 tokens).
    // System (13 chars / 3 tokens).
    // Total = ~378 tokens. Fits under 488!
    // But adding old turns would push it over. So Turn 1 & Turn 2 should get evicted.
    final giantMessage = 'Giant User Message: ' + 'A' * 290;
    await session.chat(giantMessage);

    // Invariant: System prompt at index 0 must be preserved.
    expect(session.history.first.role, equals(DenizenRole.system));
    
    // Turn 1 and Turn 2 should have been evicted.
    // History should now contain: System, Giant User, Assistant Reply
    expect(session.history.length, equals(3));
    expect(session.history[1].content, contains('Giant User Message'));
  });

  test('Session throws ContextOverflowException and rolls back user message if budget is absolutely exceeded', () async {
    final service = FakeOfflineAIService();
    
    // Max allowed = 488 tokens (~1952 chars).
    // Send a single user message that is 2500 chars (625 tokens).
    // This exceeds the budget on its own even without history!
    final session = DenizenSession(service, systemPrompt: 'System Prompt');

    final superGiantMessage = 'Super Giant: ' + 'A' * 500;

    expect(
      session.chat(superGiantMessage),
      throwsA(isA<ContextOverflowException>()),
    );

    // Rollback validation: failed user message should have been discarded.
    // History should only contain the system prompt.
    expect(session.history.length, equals(1));
    expect(session.history.first.role, equals(DenizenRole.system));
  });

  test('Session accumulates streaming chunks and appends assistant message on completion', () async {
    final service = FakeOfflineAIService();
    final session = DenizenSession(service);

    final stream = session.streamChat('Test streaming prompt');
    
    final resultList = await stream.toList();
    expect(resultList.join(''), equals('Streaming Assistant Reply'));

    // Check that assistant reply got appended to history
    expect(session.history.length, equals(2));
    expect(session.history.last.role, equals(DenizenRole.assistant));
    expect(session.history.last.content, equals('Streaming Assistant Reply'));
  });
}
