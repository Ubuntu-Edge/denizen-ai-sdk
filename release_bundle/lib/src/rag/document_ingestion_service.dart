import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:denizen_ai/src/rag/embedding_provider.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';

class DocumentIngestionService {
  final EmbeddingProvider _embeddingProvider;
  final VectorStorageService _storageService;

  DocumentIngestionService(this._embeddingProvider, this._storageService);

  /// Ingests a raw file directly (.txt, .md, .json, .csv, .log).
  /// Reads the text content and processes it into the vector database.
  Future<void> ingestFile(int docId, File file, {
    int chunkSizeWords = 200,
    int overlapWords = 30,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException("File does not exist: ${file.path}");
    }

    final ext = p.extension(file.path).toLowerCase();
    final allowedExts = ['.txt', '.md', '.json', '.csv', '.log', '.xml', '.yaml', '.yml'];
    if (!allowedExts.contains(ext) && ext.isNotEmpty) {
      throw UnsupportedError("File format '$ext' is not natively supported for raw text extraction. Please supply extracted text directly via ingestText.");
    }

    final content = await file.readAsString();
    return ingestText(docId, content, chunkSizeWords: chunkSizeWords, overlapWords: overlapWords);
  }

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
    if (chunks.isEmpty) return;

    // Use embedBatch for faster performance
    List<List<double>> embeddings;
    try {
      embeddings = await _embeddingProvider.embedBatch(chunks);
    } catch (_) {
      embeddings = [];
      for (final chunkText in chunks) {
        embeddings.add(await _embeddingProvider.embed(chunkText));
      }
    }

    for (int i = 0; i < chunks.length; i++) {
      _storageService.insertChunk(docId, chunks[i], i, embeddings[i]);
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
