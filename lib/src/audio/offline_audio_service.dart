import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

/// Service for audio transcription (system speech-to-text / Whisper) and text-to-speech (flutter_tts).
class OfflineAudioService {
  static final OfflineAudioService _instance = OfflineAudioService._internal();
  static OfflineAudioService get instance => _instance;

  factory OfflineAudioService() => _instance;

  OfflineAudioService._internal();

  Whisper? _whisper;
  bool _isWhisperLoaded = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeechInitialized = false;

  bool get isWhisperLoaded => _isWhisperLoaded;
  bool get isSpeechInitialized => _isSpeechInitialized;

  /// Initialize system Text-to-Speech (flutter_tts)
  Future<void> initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('❌ Failed to initialize FlutterTts: $e');
    }
  }

  /// Speak text out loud using system TTS engine (flutter_tts)
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      if (text.isNotEmpty) {
        await _tts.speak(text);
      }
    } catch (e) {
      debugPrint('❌ TTS Speak Error: $e');
    }
  }

  /// Stop current TTS playback
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ TTS Stop Error: $e');
    }
  }

  /// Initialize native system speech recognition (speech_to_text)
  Future<bool> initSpeech() async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
      );
      return _isSpeechInitialized;
    } catch (e) {
      debugPrint('❌ Speech to Text init failed: $e');
      return false;
    }
  }

  /// Listen to speech from the microphone using system Speech-to-Text
  Future<void> startListening({
    required Function(String recognizedText) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 60),
  }) async {
    bool available = await initSpeech();
    if (available) {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
      );
    } else {
      onResult("Speech recognition not available on device.");
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Load a Whisper GGML model from device storage if using offline Whisper file
  Future<bool> loadWhisperModel({WhisperModel modelType = WhisperModel.base, String? modelDir}) async {
    try {
      _whisper = Whisper(model: modelType, modelDir: modelDir);
      _isWhisperLoaded = true;
      debugPrint('✅ Whisper model initialized for ${modelType.modelName}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load Whisper model: $e');
      _isWhisperLoaded = false;
      return false;
    }
  }

  /// Transcribe a 16kHz WAV file using Whisper if loaded
  Future<String> transcribeAudio(String audioFilePath) async {
    if (!_isWhisperLoaded || _whisper == null) {
      return "Whisper model not loaded. Use system speech-to-text instead.";
    }

    try {
      debugPrint('🎙️ Transcribing audio file: $audioFilePath');
      final result = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioFilePath,
          language: "en",
          isTranslate: false,
          isNoTimestamps: true,
        ),
      );
      
      return result.text ?? "";
    } catch (e) {
      debugPrint('❌ Transcription error: $e');
      return "Error during transcription: $e";
    }
  }
}
