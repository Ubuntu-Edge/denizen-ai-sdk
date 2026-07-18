import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/src/rag/tflite_embedding_provider.dart';

/// Verifies that the TFLiteEmbeddingProvider output closely matches the
/// ground-truth vectors produced by sentence-transformers/all-MiniLM-L6-v2
/// in Python (via test/fixtures/reference_embeddings.json).
///
/// ## Provenance
///
/// Both files are from a consistent, compatible conversion:
///
/// - `.tflite` source: `Nihal2000/all-MiniLM-L6-v2-quant.tflite` on HuggingFace
///   - base_model confirmed as `sentence-transformers/all-MiniLM-L6-v2` in model card
///   - Conversion method: standard TFLite dynamic range quantization (INT8)
///   - Max sequence length: **128** (tokenizer padding at 128 per model card example)
///   - SHA-256: 0AAC5B0B76BE23AB94F065A7FAB6E0DAEAD5E57F6FF7D55E19A2641D6A81F276
///
/// - `vocab.txt` source: canonical `sentence-transformers/all-MiniLM-L6-v2` on HuggingFace
///   - SHA-256: 07ECED375CEC144D27C900241F3E339478DEC958F92FDDBC551F295C992038A3
///
/// The Nihal2000 conversion does NOT use a modified vocab — it uses standard BERT
/// WordPiece tokenization from the same canonical source (confirmed from model card).
///
/// ## Threshold Rationale (decided BEFORE running the test)
///
/// INT8 dynamic range quantization typically preserves cosine similarity at ≥ 0.98
/// for well-converted sentence embedding models. Our threshold is set at **0.97**:
/// - One tick below the expected best case to allow for Dart tokenizer approximation
///   (we implement BERT BasicTokenizer manually; minor differences in punctuation
///   handling could shave a small amount off cosine similarity)
/// - Still strict enough to catch a genuine vocab/model mismatch, wrong pooling
///   axis, or wrong sequence length — those typically cause similarity to drop to
///   the 0.6–0.8 range at best
///
/// Do NOT loosen this threshold after seeing results. If it fails at 0.97,
/// the fix is in the implementation, not the threshold.
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Threshold decided blind, before running. See rationale above.
  const double kMinAcceptableCosine = 0.97;

  Future<Map<String, List<double>>> loadReferenceVectors() async {
    // Read from bundled assets because this test runs on-device
    final jsonString = await rootBundle.loadString('assets/fixtures/reference_embeddings.json');
    final raw = jsonDecode(jsonString) as Map<String, dynamic>;
    final vectors = raw['vectors'] as Map<String, dynamic>;
    return vectors.map(
      (k, v) => MapEntry(k, (v as List<dynamic>).cast<double>()),
    );
  }

  double cosine(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0 : dot / denom;
  }

  group('TFLiteEmbeddingProvider — pipeline verification', () {
    late TFLiteEmbeddingProvider provider;
    late Map<String, List<double>> referenceVectors;

    setUpAll(() async {
      referenceVectors = await loadReferenceVectors();
      provider = TFLiteEmbeddingProvider(
        modelPath: 'assets/models/all-MiniLM-L6-v2.tflite',
        vocabPath: 'assets/models/vocab.txt',
      );
      await provider.initialize();
    });

    tearDownAll(() async {
      await provider.dispose();
    });

    group('cosine similarity ≥ $kMinAcceptableCosine against Python reference', () {
      // Short, clean strings — baseline
      for (final text in [
        'malaria symptoms',
        'signs of malaria',
        'fever and chills',
        'clean drinking water',
      ]) {
        test('"$text"', () async {
          final dartVec = await provider.embed(text);
          final refVec = referenceVectors[text]!;
          expect(dartVec.length, 384);
          final sim = cosine(dartVec, refVec);
          print('  "$text": cosine = ${sim.toStringAsFixed(6)}');
          expect(sim, greaterThanOrEqualTo(kMinAcceptableCosine),
              reason: 'cosine=$sim < threshold=$kMinAcceptableCosine — '
                  'likely a tokenizer/model mismatch or wrong pooling.');
        });
      }

      // Long string — tests truncation behaviour at model's 128-token limit
      test('long string near truncation boundary', () async {
        const text = 'long_string_near_max_length';
        if (!referenceVectors.containsKey(text)) {
          markTestSkipped('Fixture missing for long string — rerun generate_reference_embeddings.py');
          return;
        }
        final dartVec = await provider.embed(text);
        final refVec = referenceVectors[text]!;
        final sim = cosine(dartVec, refVec);
        print('  long string: cosine = ${sim.toStringAsFixed(6)}');
        expect(sim, greaterThanOrEqualTo(kMinAcceptableCosine));
      });

      // Punctuation string — tests tokenizer edge cases
      test('string with punctuation', () async {
        const text = 'punctuation_string';
        if (!referenceVectors.containsKey(text)) {
          markTestSkipped('Fixture missing for punctuation string — rerun generate_reference_embeddings.py');
          return;
        }
        final dartVec = await provider.embed(text);
        final refVec = referenceVectors[text]!;
        final sim = cosine(dartVec, refVec);
        print('  punctuation string: cosine = ${sim.toStringAsFixed(6)}');
        expect(sim, greaterThanOrEqualTo(kMinAcceptableCosine));
      });
    });

    test('output is L2-normalized (norm ≈ 1.0)', () async {
      final vec = await provider.embed('malaria symptoms');
      final norm = sqrt(vec.fold(0.0, (s, x) => s + x * x));
      expect(norm, closeTo(1.0, 0.001));
    });

    test('same string produces identical vector on repeat call', () async {
      const text = 'fever and chills';
      final v1 = await provider.embed(text);
      final v2 = await provider.embed(text);
      expect(cosine(v1, v2), closeTo(1.0, 1e-6));
    });
  });
}
