import 'dart:convert';

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

  @override
  String toString() => gbnfString;
}
