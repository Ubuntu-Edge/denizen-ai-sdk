import 'dart:math';

/// Interface for text embedding models.
/// 
/// Implementing classes should handle tokenization, model inference, and 
/// optional L2 normalization of the output vectors.
abstract class EmbeddingProvider {
  /// The fixed size of the vector output (e.g. 384 for all-MiniLM-L6-v2).
  /// This must be known upfront to configure the vector database schema.
  int get dimension;

  /// Initialize the embedding provider (e.g., loading model weights into memory).
  Future<void> initialize();

  /// Dispose of any native resources held by the provider.
  Future<void> dispose();

  /// Generate an embedding vector for a single string.
  /// Implementations should ensure the output is L2 normalized if required
  /// by the chosen distance metric (e.g. Cosine Similarity).
  Future<List<double>> embed(String text);

  /// Generate embedding vectors for a batch of strings.
  /// Useful for processing document chunks efficiently.
  Future<List<List<double>>> embedBatch(List<String> texts);
}

/// A lightweight, deterministic term-frequency / feature-hashing embedding provider
/// of dimension 384. Used as a high-speed, zero-dependency fallback for RAG.
class FastHashEmbeddingProvider implements EmbeddingProvider {
  @override
  int get dimension => 384;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<double>> embed(String text) async {
    final vector = List<double>.filled(384, 0.0);
    final tokens = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);

    if (tokens.isEmpty) {
      return List<double>.filled(384, 0.0);
    }

    for (final token in tokens) {
      final hash = _hashString(token);
      final index = hash.abs() % 384;
      final sign = hash >= 0 ? 1.0 : -1.0;
      vector[index] += sign;

      // Also hash character 3-grams for substring / partial word matching
      if (token.length >= 3) {
        for (var i = 0; i <= token.length - 3; i++) {
          final gram = token.substring(i, i + 3);
          final gramHash = _hashString(gram);
          final gramIndex = gramHash.abs() % 384;
          vector[gramIndex] += (gramHash >= 0 ? 0.5 : -0.5);
        }
      }
    }

    // L2 Normalize
    double sumSq = 0.0;
    for (final v in vector) {
      sumSq += v * v;
    }

    if (sumSq > 0) {
      final norm = sqrt(sumSq);
      for (var i = 0; i < 384; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final results = <List<double>>[];
    for (final text in texts) {
      results.add(await embed(text));
    }
    return results;
  }

  int _hashString(String s) {
    var h = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h > 0x7FFFFFFF ? h - 0x100000000 : h;
  }
}
