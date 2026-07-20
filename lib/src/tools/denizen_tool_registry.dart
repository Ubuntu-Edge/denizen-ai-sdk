import 'dart:convert';
import 'denizen_tool.dart';

/// Registry for managing available on-device tools and parsing tool calls.
class DenizenToolRegistry {
  final Map<String, DenizenTool> _tools = {};

  List<DenizenTool> get tools => _tools.values.toList();

  /// Register a new tool.
  void register(DenizenTool tool) {
    _tools[tool.name] = tool;
  }

  /// Look up a tool by name.
  DenizenTool? getTool(String name) => _tools[name];

  /// Formats all registered tools into a system prompt injection.
  String generateSystemPrompt() {
    if (_tools.isEmpty) return '';

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('\nYou have access to the following local tools:');
    
    for (final tool in _tools.values) {
      buffer.writeln('\nTool: ${tool.name}');
      buffer.writeln('Description: ${tool.description}');
      buffer.writeln('Parameters: ${jsonEncode(tool.parametersSchema)}');
    }

    buffer.writeln('\nIf you decide to call a tool, reply ONLY with a JSON object in this format:');
    buffer.writeln('{"tool": "<tool_name>", "args": {<argument_key>: <value>}}');

    return buffer.toString();
  }

  /// Attempts to parse an LLM response string into a tool call.
  DenizenToolCall? parseToolCall(String llmOutput) {
    try {
      final trimmed = llmOutput.trim();
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;

      final jsonSub = trimmed.substring(start, end + 1);
      final decoded = jsonDecode(jsonSub) as Map<String, dynamic>;

      if (decoded.containsKey('tool') && decoded.containsKey('args')) {
        final toolName = decoded['tool'] as String;
        final args = decoded['args'] as Map<String, dynamic>;

        if (_tools.containsKey(toolName)) {
          return DenizenToolCall(toolName: toolName, arguments: args);
        }
      }
    } catch (_) {}
    return null;
  }
}
