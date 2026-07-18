import 'dart:math';
import 'package:denizen_ai/src/rag/embedding_provider.dart';

/// A deterministic test double for the EmbeddingProvider.
/// Generates reproducible pseudo-vectors based on string hashes.
/// 
/// Note: This does NOT provide natural semantic similarity (similar strings 
/// do not produce similar vectors). It is designed for testing storage/retrieval 
/// plumbing. To test semantic relevance ranking, inject hand-crafted vectors 
/// via the [overrides] map to force specific strings to be "close" or "far".
class FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  final int dimension = 384; // Mocking all-MiniLM-L6-v2 size

  final Map<String, List<double>> _overrides;
  final Set<String> _failOn;
  bool _isInitialized = false;

  FakeEmbeddingProvider({
    Map<String, List<double>>? overrides,
    Set<String>? failOn,
  })  : _overrides = overrides ?? {},
        _failOn = failOn ?? {};

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
    
    // Simulate failure mid-batch
    if (_failOn.contains(text)) {
      throw Exception('Simulated embedding failure for: $text');
    }
    
    // Controlled vectors for ranking tests
    if (_overrides.containsKey(text)) {
      return _overrides[text]!;
    }
    
    // Use the string's hashCode as a seed to ensure deterministic output for plumbing tests.
    // This allows us to assert that identical strings produce identical vectors.
    final random = Random(text.hashCode);
    
    // Generate raw pseudo-vector with values between -1.0 and 1.0
    final rawVector = List<double>.generate(dimension, (_) => random.nextDouble() * 2 - 1);
    
    return _normalize(rawVector);
  }

  List<double> _normalize(List<double> v) {
    final sumSquares = v.fold(0.0, (sum, x) => sum + x * x);
    final magnitude = sqrt(sumSquares);
    if (magnitude == 0) return v;
    return v.map((x) => x / magnitude).toList();
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    // In a real implementation this would ideally be batched natively
    return Future.wait(texts.map((t) => embed(t)));
  }
}
