import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../services/offline_ai_service.dart';
import '../rag/vector_storage_service.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' show ChatMessage;

/// Base classes for Isolate Communication
abstract class OrchestratorCommand {}

class InitCommand extends OrchestratorCommand {
  final SendPort sendPort;
  final bool inMemoryStorage;
  
  InitCommand(this.sendPort, {this.inMemoryStorage = false});
}

class ChatStreamCommand extends OrchestratorCommand {
  final int id;
  final List<ChatMessage> messages;
  
  ChatStreamCommand(this.id, this.messages);
}

class ChatCommand extends OrchestratorCommand {
  final int id;
  final List<ChatMessage> messages;
  
  ChatCommand(this.id, this.messages);
}

class VectorSearchCommand extends OrchestratorCommand {
  final int id;
  final List<double> queryEmbedding;
  final int limit;

  VectorSearchCommand(this.id, this.queryEmbedding, {this.limit = 3});
}

abstract class OrchestratorEvent {}

class IsolateReadyEvent extends OrchestratorEvent {
  final SendPort commandPort;
  IsolateReadyEvent(this.commandPort);
}

class ChatStreamEvent extends OrchestratorEvent {
  final int id;
  final String token;
  final bool isDone;
  final String? error;

  ChatStreamEvent(this.id, this.token, {this.isDone = false, this.error});
}

class ChatResponseEvent extends OrchestratorEvent {
  final int id;
  final String response;
  final String? error;

  ChatResponseEvent(this.id, this.response, {this.error});
}

class VectorSearchResponseEvent extends OrchestratorEvent {
  final int id;
  final List<Map<String, dynamic>> results;
  final String? error;

  VectorSearchResponseEvent(this.id, this.results, {this.error});
}

/// The DenizenOrchestrator manages a persistent background isolate
/// for heavy AI operations (LLM generation and Vector search).
class DenizenOrchestrator {
  static final DenizenOrchestrator _instance = DenizenOrchestrator._internal();
  factory DenizenOrchestrator() => _instance;
  
  DenizenOrchestrator._internal();

  Isolate? _isolate;
  SendPort? _commandPort;
  
  int _requestIdCounter = 0;
  final Map<int, Completer<String>> _chatCompleters = {};
  final Map<int, Completer<List<Map<String, dynamic>>>> _searchCompleters = {};
  final Map<int, StreamController<String>> _streamControllers = {};

  bool get isReady => _commandPort != null;

  Future<void> initialize({bool inMemoryStorage = false}) async {
    if (_isolate != null) return;

    final receivePort = ReceivePort();
    
    _isolate = await Isolate.spawn(
      _isolateEntrypoint,
      InitCommand(receivePort.sendPort, inMemoryStorage: inMemoryStorage),
    );

    final readyCompleter = Completer<void>();

    receivePort.listen((message) {
      if (message is IsolateReadyEvent) {
        _commandPort = message.commandPort;
        readyCompleter.complete();
      } else if (message is ChatResponseEvent) {
        final completer = _chatCompleters.remove(message.id);
        if (completer != null) {
          if (message.error != null) {
            completer.completeError(Exception(message.error));
          } else {
            completer.complete(message.response);
          }
        }
      } else if (message is VectorSearchResponseEvent) {
        final completer = _searchCompleters.remove(message.id);
        if (completer != null) {
          if (message.error != null) {
            completer.completeError(Exception(message.error));
          } else {
            completer.complete(message.results);
          }
        }
      } else if (message is ChatStreamEvent) {
        final controller = _streamControllers[message.id];
        if (controller != null) {
          if (message.error != null) {
            controller.addError(Exception(message.error));
            controller.close();
            _streamControllers.remove(message.id);
          } else {
            if (message.token.isNotEmpty) {
              controller.add(message.token);
            }
            if (message.isDone) {
              controller.close();
              _streamControllers.remove(message.id);
            }
          }
        }
      }
    });

    await readyCompleter.future;
  }

  void dispose() {
    _commandPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  /// Entry point for the background isolate
  static void _isolateEntrypoint(InitCommand initCommand) async {
    final receivePort = ReceivePort();
    final sendPort = initCommand.sendPort;
    
    // Initialize heavy services inside the isolate
    final aiService = OfflineAIService.instance;
    final vectorStorage = VectorStorageService();
    
    try {
      await vectorStorage.initialize(inMemory: initCommand.inMemoryStorage);
    } catch (e) {
      debugPrint('Failed to initialize vector storage in isolate: $e');
    }

    sendPort.send(IsolateReadyEvent(receivePort.sendPort));

    receivePort.listen((message) async {
      if (message is ChatCommand) {
        try {
          final response = await aiService.generateHistoryChat(messages: message.messages);
          sendPort.send(ChatResponseEvent(message.id, response));
        } catch (e) {
          sendPort.send(ChatResponseEvent(message.id, '', error: e.toString()));
        }
      } else if (message is ChatStreamCommand) {
        try {
          final stream = aiService.generateHistoryChatStream(messages: message.messages);
          await for (final token in stream) {
            sendPort.send(ChatStreamEvent(message.id, token));
          }
          sendPort.send(ChatStreamEvent(message.id, '', isDone: true));
        } catch (e) {
          sendPort.send(ChatStreamEvent(message.id, '', error: e.toString()));
        }
      } else if (message is VectorSearchCommand) {
        try {
          final results = vectorStorage.search(message.queryEmbedding, limit: message.limit);
          sendPort.send(VectorSearchResponseEvent(message.id, results));
        } catch (e) {
          sendPort.send(VectorSearchResponseEvent(message.id, [], error: e.toString()));
        }
      }
    });
  }

  /// Sends a chat request to the background isolate.
  Future<String> chat(List<ChatMessage> messages) {
    if (_commandPort == null) throw Exception('Orchestrator not initialized');
    
    final id = _requestIdCounter++;
    final completer = Completer<String>();
    _chatCompleters[id] = completer;
    
    _commandPort!.send(ChatCommand(id, messages));
    return completer.future;
  }

  /// Sends a streaming chat request to the background isolate.
  Stream<String> streamChat(List<ChatMessage> messages) {
    if (_commandPort == null) throw Exception('Orchestrator not initialized');
    
    final id = _requestIdCounter++;
    final controller = StreamController<String>();
    _streamControllers[id] = controller;
    
    _commandPort!.send(ChatStreamCommand(id, messages));
    return controller.stream;
  }

  /// Offloads vector similarity search to the background isolate.
  Future<List<Map<String, dynamic>>> searchVector(List<double> queryEmbedding, {int limit = 3}) {
    if (_commandPort == null) throw Exception('Orchestrator not initialized');

    final id = _requestIdCounter++;
    final completer = Completer<List<Map<String, dynamic>>>();
    _searchCompleters[id] = completer;

    _commandPort!.send(VectorSearchCommand(id, queryEmbedding, limit: limit));
    return completer.future;
  }
}
