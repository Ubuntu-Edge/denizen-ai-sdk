import '../tools/denizen_tool.dart';

/// Represents a GBNF (GGML BNF) Grammar for constraining LLM token outputs.
class DenizenGrammar {
  final String gbnfString;

  const DenizenGrammar(this.gbnfString);

  /// Pre-built GBNF grammar for enforcing valid JSON objects.
  static DenizenGrammar json() {
    const jsonGbnf = '''
root   ::= object
value  ::= object | array | string | number | "true" | "false" | "null"
object ::= "{" ws ( string ":" ws value ( "," ws string ":" ws value )* )? "}" ws
array  ::= "[" ws ( value ( "," ws value )* )? "]" ws
string ::= "\\"" ( [^"\\\\] | "\\\\" [\\"\\\\/bfnrt] | "\\\\" "u" [0-9a-fA-F]{4} )* "\\"" ws
number ::= "-"? ([0-9]+) ("." [0-9]+)? ([eE] [+-]? [0-9]+)? ws
ws     ::= ([ \\t\\n\\r])*
''';
    return const DenizenGrammar(jsonGbnf);
  }

  /// Generates a GBNF grammar string targeting a specific list of allowed JSON keys/types.
  static DenizenGrammar jsonWithKeys(List<String> keys) {
    final keyRules = keys.map((k) => '"\\"$k\\"" ":" ws value').join(' "," ws ');
    final gbnf = '''
root   ::= "{" ws $keyRules "}" ws
value  ::= string | number | "true" | "false" | "null"
string ::= "\\"" ( [^"\\\\] | "\\\\" [\\"\\\\/bfnrt] )* "\\"" ws
number ::= "-"? ([0-9]+) ("." [0-9]+)? ws
ws     ::= ([ \\t\\n\\r])*
''';
    return DenizenGrammar(gbnf);
  }

  /// Generates a GBNF grammar that forces the model to select one of the allowed strings (Enum).
  static DenizenGrammar choice(List<String> options) {
    final choices = options.map((opt) => '"\\"$opt\\""').join(' | ');
    final gbnf = '''
root ::= $choices
''';
    return DenizenGrammar(gbnf);
  }

  /// Generates a GBNF grammar matching a specific set of tools for perfect structured output.
  static DenizenGrammar tools(List<DenizenTool> tools) {
    if (tools.isEmpty) return json();

    final buffer = StringBuffer();
    buffer.writeln('root ::= text | tool_call');
    buffer.writeln('text ::= [^\\{\\[]*'); // simple fallback text
    
    final toolChoices = tools.map((t) => '${t.name}_call').join(' | ');
    buffer.writeln('tool_call ::= "{" ws "\\"tool\\"" ":" ws ( $toolChoices ) "}" ws');

    for (final tool in tools) {
      final name = tool.name;
      // Compile parameter schema keys if present
      final propsRaw = tool.parametersSchema['properties'];
      final props = propsRaw is Map ? Map<String, dynamic>.from(propsRaw) : const <String, dynamic>{};
      final keysGbnf = props.keys.map((k) => '"\\"$k\\"" ":" ws value').join(' "," ws ');
      final argsPattern = keysGbnf.isEmpty ? '"{" ws "}"' : '"{" ws $keysGbnf "}"';
      
      buffer.writeln('"${name}_call" ::= "\\"tool\\"" ":" ws "\\"$name\\"" "," ws "\\"args\\"" ":" ws $argsPattern');
    }

    buffer.writeln('value  ::= string | number | "true" | "false" | "null"');
    buffer.writeln('string ::= "\\"" ( [^"\\\\] | "\\\\" [\\"\\\\/bfnrt] )* "\\"" ws');
    buffer.writeln('number ::= "-"? ([0-9]+) ("." [0-9]+)? ws');
    buffer.writeln('ws     ::= ([ \\t\\n\\r])*');

    return DenizenGrammar(buffer.toString());
  }

  @override
  String toString() => gbnfString;
}
