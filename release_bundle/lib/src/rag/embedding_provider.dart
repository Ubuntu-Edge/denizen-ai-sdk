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
