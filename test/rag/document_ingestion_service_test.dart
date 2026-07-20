import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/src/rag/document_ingestion_service.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';
import '../helpers/fake_embedding_provider.dart';

class FakeVectorStorageService implements VectorStorageService {
  final List<Map<String, dynamic>> insertedChunks = [];

  @override
  bool get isInitialized => true;

  @override
  int insertChunk(int docId, String textContent, int chunkIndex, List<double> embedding) {
    insertedChunks.add({
      'docId': docId,
      'textContent': textContent,
      'chunkIndex': chunkIndex,
      'embedding': embedding,
    });
    return insertedChunks.length;
  }
  
  @override
  Future<void> initialize({bool inMemory = false}) async {}
  
  @override
  List<Map<String, dynamic>> search(List<double> queryEmbedding, {int limit = 5}) => [];
  
  @override
  void dispose() {}
}

void main() {
  group('DocumentIngestionService Tests', () {
    late FakeEmbeddingProvider fakeEmbeddingProvider;
    late FakeVectorStorageService fakeStorageService;
    late DocumentIngestionService ingestionService;

    setUp(() async {
      fakeEmbeddingProvider = FakeEmbeddingProvider();
      await fakeEmbeddingProvider.initialize();
      fakeStorageService = FakeVectorStorageService();
      ingestionService = DocumentIngestionService(fakeEmbeddingProvider, fakeStorageService);
    });

    test('ingests text and splits into correct chunks', () async {
      // Create a test string with 10 words
      final text = "Word1 Word2 Word3 Word4 Word5 Word6 Word7 Word8 Word9 Word10";
      
      // We will set chunkSizeWords to 4 and overlap to 2.
      // Chunks should be:
      // 1: Word1 Word2 Word3 Word4
      // 2: Word3 Word4 Word5 Word6
      // 3: Word5 Word6 Word7 Word8
      // 4: Word7 Word8 Word9 Word10
      
      await ingestionService.ingestText(
        1, 
        text, 
        chunkSizeWords: 4, 
        overlapWords: 2
      );

      final chunks = fakeStorageService.insertedChunks;
      expect(chunks.length, 4);

      expect(chunks[0]['textContent'], "Word1 Word2 Word3 Word4");
      expect(chunks[0]['chunkIndex'], 0);
      
      expect(chunks[1]['textContent'], "Word3 Word4 Word5 Word6");
      expect(chunks[1]['chunkIndex'], 1);
      
      expect(chunks[2]['textContent'], "Word5 Word6 Word7 Word8");
      expect(chunks[2]['chunkIndex'], 2);
      
      expect(chunks[3]['textContent'], "Word7 Word8 Word9 Word10");
      expect(chunks[3]['chunkIndex'], 3);
      
      // Ensure embeddings were actually generated
      expect(chunks[0]['embedding'], isNotEmpty);
    });

    test('handles small text that is less than one chunk size', () async {
      final text = "Just three words.";
      
      await ingestionService.ingestText(
        2, 
        text, 
        chunkSizeWords: 10, 
        overlapWords: 2
      );

      final chunks = fakeStorageService.insertedChunks;
      expect(chunks.length, 1);
      expect(chunks[0]['textContent'], "Just three words.");
    });
    
    test('handles empty text gracefully', () async {
      await ingestionService.ingestText(
        3, 
        "   \n  ", 
        chunkSizeWords: 10, 
        overlapWords: 2
      );

      final chunks = fakeStorageService.insertedChunks;
      expect(chunks.isEmpty, true);
    });
  });
}
