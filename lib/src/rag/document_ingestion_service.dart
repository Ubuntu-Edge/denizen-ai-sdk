import 'package:denizen_ai/src/rag/embedding_provider.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';

class DocumentIngestionService {
  final EmbeddingProvider _embeddingProvider;
  final VectorStorageService _storageService;

  DocumentIngestionService(this._embeddingProvider, this._storageService);

  /// Ingests a raw text document by splitting it into overlapping chunks,
  /// embedding each chunk, and storing it in the vector database.
  Future<void> ingestText(int docId, String fullText, {
    int chunkSizeWords = 200,
    int overlapWords = 30,
  }) async {
    if (!_storageService.isInitialized) {
      throw StateError("VectorStorageService must be initialized before ingestion.");
    }

    final chunks = _createSlidingWindowChunks(fullText, chunkSizeWords, overlapWords);

    int chunkIndex = 0;
    for (final chunkText in chunks) {
      // Get embedding from provider
      final embedding = await _embeddingProvider.embed(chunkText);
      
      // Store chunk and embedding
      _storageService.insertChunk(docId, chunkText, chunkIndex, embedding);
      
      chunkIndex++;
    }
  }

  /// Creates overlapping text chunks using a sliding window approach.
  /// This implementation splits by whitespace to approximate word boundaries.
  List<String> _createSlidingWindowChunks(String text, int chunkSize, int overlapSize) {
    if (text.trim().isEmpty) return [];

    final words = text.split(RegExp(r'\s+'));
    final List<String> chunks = [];

    int start = 0;
    while (start < words.length) {
      int end = start + chunkSize;
      if (end > words.length) {
        end = words.length;
      }

      final chunkWords = words.sublist(start, end);
      chunks.add(chunkWords.join(' '));

      if (end == words.length) break;

      start = end - overlapSize;
    }

    return chunks;
  }
}
