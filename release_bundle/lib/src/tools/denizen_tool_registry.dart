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

    buffer.writeln('\nIf you decide to call one or more tools, reply ONLY with a JSON array in this format:');
    buffer.writeln('[{"tool": "<tool_name>", "args": {<argument_key>: <value>}}]');

    return buffer.toString();
  }

  /// Attempts to parse an LLM response string into a list of tool calls (supports both single and multiple/parallel tool calls).
  List<DenizenToolCall> parseToolCalls(String llmOutput) {
    final List<DenizenToolCall> calls = [];
    try {
      final trimmed = llmOutput.trim();
      final startBracket = trimmed.indexOf('[');
      final startBrace = trimmed.indexOf('{');
      
      // 1. Array format: [{"tool": ...}]
      if (startBracket != -1 && (startBrace == -1 || startBracket < startBrace)) {
        final endBracket = trimmed.lastIndexOf(']');
        if (endBracket != -1 && endBracket > startBracket) {
          final jsonSub = trimmed.substring(startBracket, endBracket + 1);
          final decodedList = jsonDecode(jsonSub) as List<dynamic>;
          for (final item in decodedList) {
            if (item is Map<String, dynamic> && item.containsKey('tool') && item.containsKey('args')) {
              final name = item['tool'] as String;
              final args = item['args'] as Map<String, dynamic>;
              if (_tools.containsKey(name)) {
                calls.add(DenizenToolCall(toolName: name, arguments: args));
              }
            }
          }
        }
      } 
      // 2. Fallback single object format: {"tool": ...}
      else if (startBrace != -1) {
        final endBrace = trimmed.lastIndexOf('}');
        if (endBrace != -1 && endBrace > startBrace) {
          final jsonSub = trimmed.substring(startBrace, endBrace + 1);
          final decoded = jsonDecode(jsonSub) as Map<String, dynamic>;
          if (decoded.containsKey('tool') && decoded.containsKey('args')) {
            final name = decoded['tool'] as String;
            final args = decoded['args'] as Map<String, dynamic>;
            if (_tools.containsKey(name)) {
              calls.add(DenizenToolCall(toolName: name, arguments: args));
            }
          }
        }
      }
    } catch (_) {}
    return calls;
  }

  /// Attempts to parse an LLM response string into a single tool call.
  DenizenToolCall? parseToolCall(String llmOutput) {
    final calls = parseToolCalls(llmOutput);
    return calls.isEmpty ? null : calls.first;
  }
}
