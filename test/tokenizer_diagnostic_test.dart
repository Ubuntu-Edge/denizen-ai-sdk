import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/src/rag/word_piece_tokenizer.dart';

/// Diagnostic test that dumps token IDs from the Dart WordPieceTokenizer
/// for side-by-side comparison with Python's HuggingFace tokenizer output.
///
/// Run: flutter test test/tokenizer_diagnostic_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dump token IDs for diagnostic comparison', () async {
    final tokenizer = WordPieceTokenizer();
    await tokenizer.loadVocab('assets/models/vocab.txt');

    final testStrings = {
      'fever_and_chills': 'fever and chills',
      'malaria_symptoms': 'malaria symptoms',
      'punctuation_string':
          'Signs & symptoms: fever (>38\u00b0C), chills, headache \u2014 seek care immediately!',
      'long_string':
          'The patient presented with a history of high-grade fever for five days, '
          'associated with rigors, chills, and profuse sweating, particularly at night. '
          'She also reported headache, myalgia, and nausea without vomiting. '
          'On examination, she was febrile at 39.8 degrees Celsius, with mild pallor '
          'and tender hepatosplenomegaly. A peripheral blood smear confirmed the '
          'presence of Plasmodium falciparum ring-stage trophozoites at high parasitemia, '
          'indicating severe malaria requiring immediate treatment with parenteral artesunate.',
    };

    for (final entry in testStrings.entries) {
      final label = entry.key;
      final text = entry.value;

      // Use maxLen=128 to match the model
      final tokenIds = tokenizer.tokenize(text, maxLen: 128);

      // Build attention mask the same way the embedding provider does
      final attentionMask = tokenIds
          .map((id) => id == tokenizer.padTokenId ? 0 : 1)
          .toList();

      final realCount = attentionMask.where((m) => m == 1).length;

      print('\n${"=" * 60}');
      print('=== $label ===');
      print('Text: ${text.length > 80 ? text.substring(0, 80) + "..." : text}');
      print('Real tokens (non-pad): $realCount');
      print('input_ids (${ tokenIds.length }): $tokenIds');
      print('attention_mask: $attentionMask');

      // Also print just real token IDs for easy comparison
      final realIds = <int>[];
      for (var i = 0; i < tokenIds.length; i++) {
        if (attentionMask[i] == 1) realIds.add(tokenIds[i]);
      }
      print('real_ids_only: $realIds');
    }
  });
}
