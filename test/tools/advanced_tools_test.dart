import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class FakeAIServiceForTools implements OfflineAIService {
  final List<String> chatResponses = [];
  int _callCount = 0;

  @override
  bool get isModelLoaded => true;

  @override
  OfflineModel? get loadedModel => OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2390000000,
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description: 'Mock',
        contextSize: 2048,
        isDownloaded: true,
        downloadProgress: 100,
      );

  @override
  Future<String> generateHistoryChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    if (_callCount < chatResponses.length) {
      return chatResponses[_callCount++];
    }
    return "Fallback response";
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestBatteryTool extends DenizenTool {
  TestBatteryTool() : super(
    name: 'get_battery',
    description: 'Battery tool',
    parametersSchema: {'type': 'object', 'properties': {}},
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    return {'level': 95};
  }
}

class TestLocationTool extends DenizenTool {
  TestLocationTool() : super(
    name: 'get_location',
    description: 'Location tool',
    parametersSchema: {'type': 'object', 'properties': {}},
  );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    return {'city': 'Nairobi'};
  }
}

void main() {
  group('Advanced Tools - Parallel Execution & Chaining Tests', () {
    late DenizenToolRegistry registry;
    late FakeAIServiceForTools mockAIService;

    setUp(() {
      registry = DenizenToolRegistry();
      registry.register(TestBatteryTool());
      registry.register(TestLocationTool());
      mockAIService = FakeAIServiceForTools();
    });

    test('DenizenToolRegistry parseToolCalls parses single JSON object', () {
      const llmOutput = '{"tool": "get_battery", "args": {}}';
      final calls = registry.parseToolCalls(llmOutput);
      expect(calls.length, 1);
      expect(calls[0].toolName, 'get_battery');
    });

    test('DenizenToolRegistry parseToolCalls parses JSON array with multiple tools', () {
      const llmOutput = '[{"tool": "get_battery", "args": {}}, {"tool": "get_location", "args": {}}]';
      final calls = registry.parseToolCalls(llmOutput);
      expect(calls.length, 2);
      expect(calls[0].toolName, 'get_battery');
      expect(calls[1].toolName, 'get_location');
    });

    test('DenizenToolSession performs parallel tool execution and multi-turn loops', () async {
      mockAIService.chatResponses.addAll([
        // Turn 1: LLM triggers parallel tools
        '[{"tool": "get_battery", "args": {}}, {"tool": "get_location", "args": {}}]',
        // Turn 2: LLM receives results and outputs final text answer
        'Battery is at 95% and you are in Nairobi.'
      ]);

      final session = DenizenToolSession(mockAIService, registry);
      final finalReply = await session.chat("Get my battery and location.");

      expect(finalReply, contains('Nairobi'));
      expect(finalReply, contains('95%'));
      expect(mockAIService._callCount, 2); // 2 LLM calls made successfully
    });

    test('DenizenGrammar.tools compiles GBNF with dynamic tools rules', () {
      final grammar = DenizenGrammar.tools(registry.tools);
      expect(grammar.gbnfString, contains('root ::= text | tool_call'));
      expect(grammar.gbnfString, contains('get_battery_call'));
      expect(grammar.gbnfString, contains('get_location_call'));
    });
  });
}
