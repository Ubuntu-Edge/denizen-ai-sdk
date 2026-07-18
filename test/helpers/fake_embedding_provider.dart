import 'dart:math';
import 'package:denizen_ai/src/rag/embedding_provider.dart';

/// A deterministic test double for the EmbeddingProvider.
/// Generates reproducible pseudo-vectors based on string hashes, allowing 
/// for predictable semantic similarity tests without a real model.
class FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  final int dimension = 384; // Mocking all-MiniLM-L6-v2 size

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  @override
  Future<List<double>> embed(String text) async {
    if (!_isInitialized) throw StateError('FakeEmbeddingProvider not initialized');
    
    // Use the string's hashCode as a seed to ensure deterministic output for testing.
    // This allows us to assert that identical strings produce identical vectors.
    final random = Random(text.hashCode);
    
    // Generate raw pseudo-vector with values between -1.0 and 1.0
    final rawVector = List<double>.generate(dimension, (_) => random.nextDouble() * 2 - 1);
    
    // L2 Normalize the vector to simulate Cosine Similarity readiness (which 
    // sqlite-vec expects for optimized dot product calculations).
    double sumSquares = 0.0;
    for (final val in rawVector) {
      sumSquares += val * val;
    }
    final magnitude = sqrt(sumSquares);
    
    if (magnitude == 0) return rawVector;
    
    return rawVector.map((val) => val / magnitude).toList();
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    // In a real implementation this would ideally be batched natively
    return Future.wait(texts.map((t) => embed(t)));
  }
}
