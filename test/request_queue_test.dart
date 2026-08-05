import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class SlowFakeOfflineAIService implements OfflineAIService {
  final List<String> callLog = [];
  final List<List<ChatMessage>> capturedMessagesHistory = [];

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
    final userMsg = messages.last.content;
    callLog.add('start:$userMsg');
    capturedMessagesHistory.add(List.from(messages));
    await Future.delayed(const Duration(milliseconds: 50));
    callLog.add('end:$userMsg');
    return 'Reply for $userMsg';
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
    final userMsg = messages.last.content;
    callLog.add('start_stream:$userMsg');
    capturedMessagesHistory.add(List.from(messages));
    await Future.delayed(const Duration(milliseconds: 30));
    yield 'Token1_$userMsg';
    await Future.delayed(const Duration(milliseconds: 30));
    yield 'Token2_$userMsg';
    callLog.add('end_stream:$userMsg');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AsyncSequentialQueue Unit Tests', () {
    test('AsyncSequentialQueue runs tasks in strict FIFO order', () async {
      final queue = AsyncSequentialQueue();
      final executionOrder = <int>[];

      final future1 = queue.run(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        executionOrder.add(1);
        return 'res1';
      });

      final future2 = queue.run(() async {
        executionOrder.add(2);
        return 'res2';
      });

      final results = await Future.wait([future1, future2]);

      expect(results, equals(['res1', 'res2']));
      expect(executionOrder, equals([1, 2]));
    });

    test('AsyncSequentialQueue continues next task even if previous task fails', () async {
      final queue = AsyncSequentialQueue();
      final executionOrder = <int>[];

      final future1 = queue.run(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        throw Exception('Task 1 failed');
      });

      final future2 = queue.run(() async {
        executionOrder.add(2);
        return 'res2';
      });

      expect(future1, throwsA(isA<Exception>()));
      final res2 = await future2;
      expect(res2, equals('res2'));
      expect(executionOrder, equals([2]));
    });
  });

  group('Session Concurrent Request Queuing', () {
    test('Concurrent non-streaming chat requests are executed sequentially and retain history context', () async {
      final service = SlowFakeOfflineAIService();
      final session = DenizenSession(service);

      // Trigger two chat calls concurrently
      final f1 = session.chat('First message');
      final f2 = session.chat('Second message');

      final results = await Future.wait([f1, f2]);

      expect(results[0], equals('Reply for First message'));
      expect(results[1], equals('Reply for Second message'));

      // Execution log must show First started and finished before Second started
      expect(service.callLog, equals([
        'start:First message',
        'end:First message',
        'start:Second message',
        'end:Second message',
      ]));

      // History of second message must include First message and its reply
      expect(service.capturedMessagesHistory.length, equals(2));
      final secondCallMessages = service.capturedMessagesHistory[1];
      expect(secondCallMessages.map((m) => m.content).toList(), equals([
        'First message',
        'Reply for First message',
        'Second message',
      ]));
    });

    test('Concurrent streaming chat requests are executed sequentially without error', () async {
      final service = SlowFakeOfflineAIService();
      final session = DenizenSession(service);

      final stream1Tokens = <String>[];
      final stream2Tokens = <String>[];

      // Trigger two streamChat calls concurrently
      final stream1 = session.streamChat('First stream');
      final stream2 = session.streamChat('Second stream');

      final sub1 = stream1.listen((token) => stream1Tokens.add(token));
      final sub2 = stream2.listen((token) => stream2Tokens.add(token));

      await Future.wait([
        sub1.asFuture(),
        sub2.asFuture(),
      ]);

      expect(stream1Tokens, equals(['Token1_First stream', 'Token2_First stream']));
      expect(stream2Tokens, equals(['Token1_Second stream', 'Token2_Second stream']));

      expect(service.callLog, equals([
        'start_stream:First stream',
        'end_stream:First stream',
        'start_stream:Second stream',
        'end_stream:Second stream',
      ]));

      // Verify final session history contains both complete turns
      expect(session.history.length, equals(4));
      expect(session.history[0].content, equals('First stream'));
      expect(session.history[1].content, equals('Token1_First streamToken2_First stream'));
      expect(session.history[2].content, equals('Second stream'));
      expect(session.history[3].content, equals('Token1_Second streamToken2_Second stream'));
    });
  });
}
