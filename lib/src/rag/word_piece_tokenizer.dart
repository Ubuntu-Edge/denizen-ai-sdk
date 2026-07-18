import 'package:flutter/services.dart';

/// A custom WordPiece tokenizer that matches the BERT specification used by
/// models like all-MiniLM-L6-v2.
///
/// IMPORTANT: maxLen must be 128, not 256. The Nihal2000 TFLite conversion
/// was performed with tokenizer padding at length=128 (as documented in the
/// model card). Using a different sequence length will produce input tensors
/// of the wrong shape and cause inference errors or wrong outputs.
class WordPieceTokenizer {
  final Map<String, int> _vocab = {};
  final String unkToken = '[UNK]';
  final String clsToken = '[CLS]';
  final String sepToken = '[SEP]';
  final String padToken = '[PAD]';

  late final int unkTokenId;
  late final int clsTokenId;
  late final int sepTokenId;
  late final int padTokenId;

  /// Loads the vocabulary from the given asset path.
  Future<void> loadVocab(String vocabPath) async {
    final vocabString = await rootBundle.loadString(vocabPath);
    final lines = vocabString.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        _vocab[token] = i;
      }
    }

    unkTokenId = _vocab[unkToken] ?? 100;
    clsTokenId = _vocab[clsToken] ?? 101;
    sepTokenId = _vocab[sepToken] ?? 102;
    padTokenId = _vocab[padToken] ?? 0;
  }

  /// Tokenizes text into a list of token IDs, adding [CLS] and [SEP] tokens.
  ///
  /// [maxLen] must be 128 to match the TFLite model's conversion parameters.
  List<int> tokenize(String text, {int maxLen = 128}) {
    final List<int> tokenIds = [clsTokenId];
    
    // Basic whitespace splitting and lowercasing.
    // In a full implementation, you'd also want to handle punctuation 
    // splitting correctly according to BERT's BasicTokenizer.
    final words = text.toLowerCase().split(RegExp(r'\s+'));

    for (var word in words) {
      if (word.isEmpty) continue;

      final subTokens = _wordpieceTokenize(word);
      for (var token in subTokens) {
        tokenIds.add(_vocab[token] ?? unkTokenId);
      }
    }

    tokenIds.add(sepTokenId);

    // Truncate if necessary
    if (tokenIds.length > maxLen) {
      final truncated = tokenIds.sublist(0, maxLen - 1);
      truncated.add(sepTokenId);
      return truncated;
    }

    // Pad if necessary
    while (tokenIds.length < maxLen) {
      tokenIds.add(padTokenId);
    }

    return tokenIds;
  }

  /// WordPiece tokenization for a single word.
  List<String> _wordpieceTokenize(String word) {
    final List<String> outputTokens = [];
    int start = 0;
    
    while (start < word.length) {
      int end = word.length;
      String? matchedToken;

      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) {
          substr = '##$substr';
        }
        
        if (_vocab.containsKey(substr)) {
          matchedToken = substr;
          break;
        }
        end--;
      }

      if (matchedToken == null) {
        outputTokens.add(unkToken);
        start++;
      } else {
        outputTokens.add(matchedToken);
        start = end;
      }
    }

    return outputTokens;
  }
}
