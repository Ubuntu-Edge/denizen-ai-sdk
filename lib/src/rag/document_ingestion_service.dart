import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:denizen_ai/src/rag/embedding_provider.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';

class DocumentIngestionService {
  final EmbeddingProvider _embeddingProvider;
  final VectorStorageService _storageService;

  DocumentIngestionService(this._embeddingProvider, this._storageService);

  /// Ingests a raw file directly (.txt, .md, .pdf, .json, .csv, .log, etc.).
  /// Reads or extracts the text content and processes it into the vector database.
  Future<void> ingestFile(int docId, File file, {
    int chunkSizeWords = 200,
    int overlapWords = 30,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException("File does not exist: ${file.path}");
    }

    final ext = p.extension(file.path).toLowerCase();
    String content = '';

    if (ext == '.pdf') {
      final bytes = await file.readAsBytes();
      content = _extractTextFromPdfBytes(bytes);
    } else {
      try {
        content = await file.readAsString();
      } catch (_) {
        final bytes = await file.readAsBytes();
        content = _extractPrintableStrings(bytes);
      }
    }

    if (content.trim().isEmpty) {
      throw FormatException("Could not extract readable text from file '${p.basename(file.path)}'.");
    }

    return ingestText(docId, content, chunkSizeWords: chunkSizeWords, overlapWords: overlapWords);
  }

  String _extractTextFromPdfBytes(List<int> bytes) {
    final rawStr = String.fromCharCodes(bytes);
    final StringBuffer sb = StringBuffer();

    final tjRegex = RegExp(r'\(([^)]+)\)\s*Tj', multiLine: true);
    for (final m in tjRegex.allMatches(rawStr)) {
      final g = m.group(1);
      if (g != null && g.trim().isNotEmpty) {
        sb.writeln(g.trim());
      }
    }

    final arrayTjRegex = RegExp(r'\[\s*(((?:\([^)]+\)\s*|-?\d+\s*)+))\]\s*TJ', multiLine: true);
    for (final m in arrayTjRegex.allMatches(rawStr)) {
      final rawGroup = m.group(1) ?? '';
      final innerRegex = RegExp(r'\(([^)]+)\)');
      for (final inner in innerRegex.allMatches(rawGroup)) {
        final text = inner.group(1);
        if (text != null && text.trim().isNotEmpty) {
          sb.write(text.trim());
          sb.write(' ');
        }
      }
      sb.writeln();
    }

    if (sb.length < 50) {
      return _extractPrintableStrings(bytes);
    }

    return sb.toString();
  }

  String _extractPrintableStrings(List<int> bytes) {
    final rawStr = String.fromCharCodes(bytes);
    final asciiRegex = RegExp(r'[A-Za-z0-9\s.,!?:;()\'"-]{4,}');
    final StringBuffer sb = StringBuffer();

    for (final m in asciiRegex.allMatches(rawStr)) {
      final s = m.group(0)!.trim();
      if (s.length >= 4 &&
          !s.startsWith('/Font') &&
          !s.startsWith('/ProcSet') &&
          !s.startsWith('/Type') &&
          !s.startsWith('/Catalog') &&
          !s.startsWith('/Pages')) {
        sb.writeln(s);
      }
    }

    return sb.toString();
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
