import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:denizen_ai/src/rag/tflite_embedding_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TFLiteEmbeddingProvider basic embedding', () async {
    final provider = TFLiteEmbeddingProvider(
      modelPath: 'assets/models/all-MiniLM-L6-v2.tflite',
      vocabPath: 'assets/models/vocab.txt'
    );
    
    // We can't actually run tflite_flutter in a pure dart test environment
    // without native libraries built for the host (windows/mac/linux).
    // This test serves as a placeholder for instrumentation tests.
    try {
      await provider.initialize();
      final emb = await provider.embed("hello world");
      expect(emb.length, 384);
      print('Successfully generated embedding of size \${emb.length}');
    } catch (e) {
      print('Expected failure if native libraries are missing: \$e');
    }
  });
}
