import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:denizen_ai/src/rag/embedding_provider.dart';
import 'package:denizen_ai/src/rag/word_piece_tokenizer.dart';

/// A concrete implementation of [EmbeddingProvider] using tflite_flutter.
/// Designed specifically for all-MiniLM-L6-v2 (dimension 384).
class TFLiteEmbeddingProvider implements EmbeddingProvider {
  final String modelPath;
  final String vocabPath;
  
  Interpreter? _interpreter;
  final WordPieceTokenizer _tokenizer = WordPieceTokenizer();
  final FastHashEmbeddingProvider _fallback = FastHashEmbeddingProvider();
  bool _useFallback = false;
  
  // all-MiniLM-L6-v2 outputs 384-dimensional vectors.
  @override
  int get dimension => 384;

  TFLiteEmbeddingProvider({
    this.modelPath = 'assets/models/all-MiniLM-L6-v2.tflite',
    this.vocabPath = 'assets/models/vocab.txt',
  });

  @override
  Future<void> initialize() async {
    try {
      await _tokenizer.loadVocab(vocabPath);
      _interpreter = await Interpreter.fromAsset(modelPath);
    } catch (e) {
      debugPrint('⚠️ TFLite embedding provider initialization failed ($e). Using FastHash embedding fallback.');
      _useFallback = true;
    }
  }

  @override
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }

  @override
  Future<List<double>> embed(String text) async {
    if (_useFallback || _interpreter == null) {
      return _fallback.embed(text);
    }

    try {

    // 1. Tokenize
    final maxLen = 128; // Fixed: must match the model's expected sequence length
    final tokenIds = _tokenizer.tokenize(text, maxLen: maxLen);
    
    // Create inputs (batch size 1)
    final inputIds = [tokenIds];
    
    // attention_mask is 1 for real tokens, 0 for padding.
    final attentionMask = [
      tokenIds.map((id) => id == _tokenizer.padTokenId ? 0 : 1).toList()
    ];
    
    // token_type_ids is usually all 0s for single sequence.
    final tokenTypeIds = [
      List.filled(maxLen, 0)
    ];

    // Inspect interpreter inputs to see what it requires
    final inputTensors = _interpreter!.getInputTensors();
    final Map<int, Object> inputs = {};
    
    for (var i = 0; i < inputTensors.length; i++) {
      final name = inputTensors[i].name.toLowerCase();
      if (name.contains('input_ids') || name.contains('input_1')) {
        inputs[i] = inputIds;
      } else if (name.contains('attention_mask') || name.contains('input_2')) {
        inputs[i] = attentionMask;
      } else if (name.contains('token_type_ids') || name.contains('input_3')) {
        inputs[i] = tokenTypeIds;
      } else {
        // Fallback: assume order is input_ids, attention_mask, token_type_ids
        if (i == 0) inputs[i] = inputIds;
        if (i == 1) inputs[i] = attentionMask;
        if (i == 2) inputs[i] = tokenTypeIds;
      }
    }

    // 2. Output Tensor setup
    // The output is usually [1, maxLen, 384] for token embeddings, 
    // or [1, 384] if pooled.
    final outputTensors = _interpreter!.getOutputTensors();
    final outputShape = outputTensors[0].shape;
    
    bool isPooled = outputShape.length == 2; // [1, 384]
    
    final output = isPooled 
      ? [List.filled(dimension, 0.0)]
      : [List.generate(maxLen, (_) => List.filled(dimension, 0.0))];

    final Map<int, Object> outputs = {0: output};

    // 3. Inference
    _interpreter!.runForMultipleInputs(inputs.values.toList(), outputs);

    // 4. Pooling
    List<double> finalEmbedding;
    if (isPooled) {
      finalEmbedding = (output as List<List<double>>)[0];
    } else {
      // Mean pooling (ignoring padding tokens)
      final tokenEmbeddings = (output as List<List<List<double>>>)[0];
      finalEmbedding = _meanPooling(tokenEmbeddings, attentionMask[0]);
    }

    // 5. L2 Normalize
    return _l2Normalize(finalEmbedding);
    } catch (e) {
      debugPrint('⚠️ TFLite embed error ($e). Falling back to FastHash vector.');
      return _fallback.embed(text);
    }
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (_useFallback || _interpreter == null) {
      return _fallback.embedBatch(texts);
    }
    final List<List<double>> results = [];
    for (var text in texts) {
      results.add(await embed(text));
    }
    return results;
  }

  /// Mean pooling: takes the average of all token embeddings, masked by attention.
  List<double> _meanPooling(List<List<double>> tokenEmbeddings, List<int> attentionMask) {
    List<double> sum = List.filled(dimension, 0.0);
    int count = 0;
    
    for (int i = 0; i < tokenEmbeddings.length; i++) {
      if (attentionMask[i] == 1) {
        for (int j = 0; j < dimension; j++) {
          sum[j] += tokenEmbeddings[i][j];
        }
        count++;
      }
    }
    
    if (count == 0) return sum;
    
    for (int j = 0; j < dimension; j++) {
      sum[j] /= count;
    }
    return sum;
  }

  /// L2 Normalization
  List<double> _l2Normalize(List<double> vec) {
    double norm = 0.0;
    for (var val in vec) {
      norm += val * val;
    }
    norm = sqrt(norm);
    if (norm == 0) return vec;
    
    return vec.map((v) => v / norm).toList();
  }
}
