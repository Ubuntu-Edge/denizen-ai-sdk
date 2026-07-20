import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('VectorStorageService Tests', () {
    late VectorStorageService storageService;

    setUp(() async {
      storageService = VectorStorageService();
      // Initialize might fail in standard flutter test environment if sqlite-vec
      // is not built for the host machine (e.g. Windows).
      // We wrap the tests to gracefully skip or assert failure if the extension is missing.
    });

    tearDown(() {
      if (storageService.isInitialized) {
        storageService.dispose();
      }
    });

    test('initialize throws or succeeds depending on vec0 availability', () async {
      // Now that we download vec0.dll for windows host testing, this should simply succeed.
      await storageService.initialize(inMemory: true);
      expect(storageService.isInitialized, true);
    });

    test('insert and search chunks', () async {
      await storageService.initialize(inMemory: true);

      // 1. Insert a document record (bypassing service for now just to get a doc_id, 
      // or using the foreign key bypass if PRAGMA foreign_keys=OFF is default)
      // Actually, since foreign keys are enforced only if PRAGMA foreign_keys=ON,
      // and we didn't explicitly enable it, we can just use an arbitrary docId.
      final docId = 999;
      
      final embedding1 = List.filled(384, 0.1);
      final embedding2 = List.filled(384, 0.9);
      final query = List.filled(384, 0.1); // exactly matches embedding1

      final chunkId1 = storageService.insertChunk(docId, "Chunk A", 0, embedding1);
      final chunkId2 = storageService.insertChunk(docId, "Chunk B", 1, embedding2);

      expect(chunkId1, isPositive);
      expect(chunkId2, isPositive);

      // Search for query (should return Chunk A first because distance is 0)
      final results = storageService.search(query, limit: 1);
      
      expect(results.length, 1);
      expect(results.first['text_content'], "Chunk A");
      // sqlite-vec distance for identical vectors is 0
      expect(results.first['distance'], lessThan(0.0001));
    });
  });
}
