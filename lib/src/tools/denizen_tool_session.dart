import 'dart:convert';
import '../../denizen_ai.dart';

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

  /// Runs the conversational turn with support for parallel execution and up to [maxTurns] recursive execution loops.
  @override
  Future<String> chat(String prompt, {int maxTurns = 5}) async {
    String currentPrompt = prompt;
    String latestResponse = "";
    int turnCount = 0;

    while (turnCount < maxTurns) {
      // 1. Generate text response
      latestResponse = await super.chat(currentPrompt);

      // 2. Parse tool calls
      final toolCalls = registry.parseToolCalls(latestResponse);
      if (toolCalls.isEmpty) {
        // No tool calls detected; we are done!
        break;
      }

      // 3. Execute all tool calls in parallel
      final resultsList = await Future.wait(toolCalls.map((call) async {
        final tool = registry.getTool(call.toolName);
        if (tool == null) {
          return 'System Tool Error (${call.toolName}): Tool not found.';
        }
        try {
          final result = await tool.execute(call.arguments);
          return 'System Tool Result (${call.toolName}): ${jsonEncode(result)}';
        } catch (e) {
          return 'System Tool Error (${call.toolName}): $e';
        }
      }));

      // 4. Merge all outputs into a single message for the next iteration
      currentPrompt = resultsList.join('\n');
      turnCount++;
    }

    return latestResponse;
  }

  /// Streams the conversational turn, automatically intercepting tool calls,
  /// executing them, and streaming the final text response.
  @override
  Stream<String> streamChat(String prompt, {int maxTurns = 5}) async* {
    String currentPrompt = prompt;
    int turnCount = 0;

    while (turnCount < maxTurns) {
      final responseBuffer = StringBuffer();
      final stream = super.streamChat(currentPrompt);

      await for (final token in stream) {
        responseBuffer.write(token);
      }

      final latestResponse = responseBuffer.toString();
      final toolCalls = registry.parseToolCalls(latestResponse);
      
      if (toolCalls.isEmpty) {
        yield latestResponse;
        break;
      }

      // Execute tools
      final resultsList = await Future.wait(toolCalls.map((call) async {
        final tool = registry.getTool(call.toolName);
        if (tool == null) {
          return 'System Tool Error (${call.toolName}): Tool not found.';
        }
        try {
          final result = await tool.execute(call.arguments);
          return 'System Tool Result (${call.toolName}): ${jsonEncode(result)}';
        } catch (e) {
          return 'System Tool Error (${call.toolName}): $e';
        }
      }));

      currentPrompt = resultsList.join('\n');
      turnCount++;
    }
  }
}
