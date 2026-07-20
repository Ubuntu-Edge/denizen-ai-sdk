import 'dart:async';

/// Abstract definition of an executable on-device tool/function.
abstract class DenizenTool {
  /// The unique identifier name of the tool (e.g. 'get_battery_level').
  final String name;

  /// Human readable description of what the tool does.
  final String description;

  /// Parameter definitions (JSON Schema representation of parameters).
  final Map<String, dynamic> parametersSchema;

  DenizenTool({
    required this.name,
    required this.description,
    required this.parametersSchema,
  });

  /// The execution handler invoked when the LLM triggers this tool.
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments);
}

/// Represents an extracted tool call requested by the LLM.
class DenizenToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;

  DenizenToolCall({
    required this.toolName,
    required this.arguments,
  });
}
