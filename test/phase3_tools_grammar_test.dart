import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

class BatteryTool extends DenizenTool {
  BatteryTool()
      : super(
          name: 'get_battery_level',
          description: 'Returns the current device battery percentage.',
          parametersSchema: {'type': 'object', 'properties': {}},
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    return {'battery_level': 85, 'is_charging': false};
  }
}

void main() {
  group('Phase 3: GBNF Grammar Tests', () {
    test('DenizenGrammar generates valid JSON object grammar', () {
      final grammar = DenizenGrammar.json();
      expect(grammar.gbnfString, contains('root   ::= object'));
      expect(grammar.gbnfString, contains('string ::='));
    });

    test('DenizenGrammar generates valid Enum choice grammar', () {
      final grammar = DenizenGrammar.choice(['red', 'green', 'blue']);
      expect(grammar.gbnfString, contains('root ::= "\\"red\\"" | "\\"green\\"" | "\\"blue\\""'));
    });
  });

  group('Phase 3: Tool Use & Function Calling Tests', () {
    late DenizenToolRegistry registry;

    setUp(() {
      registry = DenizenToolRegistry();
      registry.register(BatteryTool());
    });

    test('registers tool and formats system prompt', () {
      expect(registry.tools.length, 1);
      final prompt = registry.generateSystemPrompt();
      expect(prompt, contains('Tool: get_battery_level'));
      expect(prompt, contains('Returns the current device battery percentage.'));
    });

    test('parses valid LLM tool call output', () {
      const llmOutput = 'I will check for you. {"tool": "get_battery_level", "args": {}}';
      final call = registry.parseToolCall(llmOutput);
      
      expect(call, isNotNull);
      expect(call!.toolName, 'get_battery_level');
      expect(call.arguments, isEmpty);
    });

    test('executes tool natively', () async {
      final tool = registry.getTool('get_battery_level');
      expect(tool, isNotNull);
      final result = await tool!.execute({});
      expect(result['battery_level'], 85);
    });
  });
}
