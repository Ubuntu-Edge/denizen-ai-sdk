import 'dart:convert';
import '../../denizen_ai.dart';
import 'denizen_tool.dart';
import 'denizen_tool_registry.dart';

/// A Session subclass that automatically intercepts tool calls requested by the LLM,
/// executes them on-device, feeds the results back into the context, and generates the final reply.
class DenizenToolSession extends DenizenSession {
  final DenizenToolRegistry registry;

  DenizenToolSession(
    super.aiService,
    this.registry, {
    String? systemPrompt,
    super.maxTokens,
  }) : super(
         systemPrompt: (systemPrompt ?? 'You are a helpful assistant.') + registry.generateSystemPrompt(),
       );

  @override
  Future<String> chat(String prompt) async {
    // 1. Initial chat turn
    final rawReply = await super.chat(prompt);

    // 2. Check if reply is a tool call request
    final toolCall = registry.parseToolCall(rawReply);
    if (toolCall != null) {
      final tool = registry.getTool(toolCall.toolName);
      if (tool != null) {
        try {
          // 3. Execute tool natively
          final result = await tool.execute(toolCall.arguments);

          // 4. Inject tool result back into session as user context message
          final resultMessage = 'System Tool Result (${toolCall.toolName}): ${jsonEncode(result)}';
          return await super.chat(resultMessage);
        } catch (e) {
          final errorMessage = 'System Tool Error (${toolCall.toolName}): $e';
          return await super.chat(errorMessage);
        }
      }
    }

    return rawReply;
  }
}
