import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:denizen_ai/src/rag/document_ingestion_service.dart';
import 'package:denizen_ai/src/rag/vector_storage_service.dart';
import '../test/helpers/fake_embedding_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  List<double> padTo384(List<double> shortVec) {
    final padded = List<double>.filled(384, 0.0);
    for (int i = 0; i < shortVec.length; i++) {
      padded[i] = shortVec[i];
    }
    return padded;
  }

  group('RAG Pipeline E2E', () {
    late FakeEmbeddingProvider fakeEmbeddingProvider;
    late VectorStorageService storageService;
    late DocumentIngestionService ingestionService;

    setUp(() async {
      fakeEmbeddingProvider = FakeEmbeddingProvider(
        overrides: {
          // Force similar strings to have similar vectors for test
          "Apple is a fruit": padTo384([1.0, 0.0, 0.0]),
          "What is an apple?": padTo384([0.9, 0.1, 0.0]), // close to apple
          "Car is a vehicle": padTo384([0.0, 1.0, 0.0]),
        }
      );
      await fakeEmbeddingProvider.initialize();
      
      storageService = VectorStorageService();
      await storageService.initialize();
      
      ingestionService = DocumentIngestionService(fakeEmbeddingProvider, storageService);
    });

    tearDown(() {
      storageService.dispose();
    });

    testWidgets('Ingests document and retrieves via similarity search', (WidgetTester tester) async {
      await ingestionService.ingestText(
        1,
        "Apple is a fruit",
        chunkSizeWords: 10,
        overlapWords: 0
      );

      await ingestionService.ingestText(
        2,
        "Car is a vehicle",
        chunkSizeWords: 10,
        overlapWords: 0
      );

      // Query for apple
      final queryEmbedding = await fakeEmbeddingProvider.embed("What is an apple?");
      
      final results = storageService.search(queryEmbedding, limit: 1);
      
      expect(results.length, 1);
      // Because "Apple is a fruit" vector is closer to "What is an apple?" than "Car is a vehicle"
      expect(results.first['text_content'], "Apple is a fruit");
    });
  });
}
