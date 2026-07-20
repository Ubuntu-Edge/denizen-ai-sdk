import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('DenizenVoiceSession', () {
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
