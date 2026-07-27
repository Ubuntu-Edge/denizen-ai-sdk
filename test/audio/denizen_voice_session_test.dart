import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('DenizenVoiceSession', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('com.llfbandit.record/messages'), (methodCall) async {
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (methodCall) async {
        return null;
      });
    });

    test('Initialization with default prompt', () {
      final session = DenizenVoiceSession();
      expect(session, isNotNull);
      expect(session.isRecording, isFalse);
    });

    test('Initialization with custom prompt', () {
      final session = DenizenVoiceSession(systemPrompt: 'You are a transcriber.');
      expect(session, isNotNull);
    });

    // Note: Testing actual startRecording() would require native permissions and platform channels
    // which fail in a headless test environment. We only test the abstraction here.
  });
}
