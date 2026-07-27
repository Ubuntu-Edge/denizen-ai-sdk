import 'dart:io';
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
  Future<void> initialize({String? dbPath, bool inMemory = false}) async {}
  
  @override
  List<Map<String, dynamic>> search(List<double> queryEmbedding, {int limit = 5}) => [];
  
  @override
  void dispose() {}
  
  @override
  Future<File> exportDatabase(String destinationPath) async {
    return File(destinationPath);
  }
  
  @override
  Future<void> importDatabase(String sourceFilePath) async {}
}

void main() {
  group('DocumentIngestionService ingestFile Tests', () {
    late FakeEmbeddingProvider fakeEmbeddingProvider;
    late FakeVectorStorageService fakeStorageService;
    late DocumentIngestionService ingestionService;
    late Directory tempDir;

    setUp(() async {
      fakeEmbeddingProvider = FakeEmbeddingProvider();
      await fakeEmbeddingProvider.initialize();
      fakeStorageService = FakeVectorStorageService();
      ingestionService = DocumentIngestionService(fakeEmbeddingProvider, fakeStorageService);
      tempDir = await Directory.systemTemp.createTemp('ingest_file_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ingests .txt file content successfully', () async {
      final file = File('${tempDir.path}/test_doc.txt');
      await file.writeAsString('This is line one of the secret document. This is line two with instructions.');

      await ingestionService.ingestFile(101, file, chunkSizeWords: 5, overlapWords: 2);

      expect(fakeStorageService.insertedChunks, isNotEmpty);
      expect(fakeStorageService.insertedChunks.first['docId'], equals(101));
      expect(fakeStorageService.insertedChunks.first['textContent'], contains('This is line one'));
    });

    test('ingests .md file content successfully', () async {
      final file = File('${tempDir.path}/README.md');
      await file.writeAsString('# Title\n\nSection text about offline architecture.');

      await ingestionService.ingestFile(102, file);

      expect(fakeStorageService.insertedChunks, isNotEmpty);
      expect(fakeStorageService.insertedChunks.first['docId'], equals(102));
    });

    test('throws FileSystemException when file does not exist', () async {
      final nonExistentFile = File('${tempDir.path}/non_existent.txt');
      expect(
        () async => await ingestionService.ingestFile(103, nonExistentFile),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws UnsupportedError for unsupported extensions', () async {
      final file = File('${tempDir.path}/test.bin');
      await file.writeAsString('binary content');

      expect(
        () async => await ingestionService.ingestFile(104, file),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
