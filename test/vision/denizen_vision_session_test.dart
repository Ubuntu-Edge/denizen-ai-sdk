import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() {
  group('DenizenVisionSession', () {
    test('Initialization with default prompt', () {
      final session = DenizenVisionSession();
      expect(session, isNotNull);
    });

    test('Initialization with custom prompt', () {
      final session = DenizenVisionSession(systemPrompt: 'You are a dog expert.');
      expect(session, isNotNull);
    });

    test('analyzeImage returns placeholder text before C++ integration', () async {
      final session = DenizenVisionSession();
      // Mock an empty 1x1 image byte array
      final mockBytes = Uint8List.fromList([0, 1, 2, 3]);
      
      final result = await session.analyzeImage(mockBytes);
      
      expect(result, contains('initializing'));
    });
  });
}
