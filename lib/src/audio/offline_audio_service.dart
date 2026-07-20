import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'dart:io';

/// Service for offline audio transcription using whisper.cpp via whisper_flutter_new package.
class OfflineAudioService {
  static final OfflineAudioService _instance = OfflineAudioService._internal();
  static OfflineAudioService get instance => _instance;

  OfflineAudioService._internal();

  Whisper? _whisper;
  bool _isModelLoaded = false;
  
  bool get isModelLoaded => _isModelLoaded;

  /// Load a Whisper GGML model from device storage
  Future<bool> loadModel({WhisperModel modelType = WhisperModel.base, String? modelDir}) async {
    try {
      _whisper = Whisper(model: modelType, modelDir: modelDir);
      _isModelLoaded = true;
      debugPrint('✅ Whisper model initialized for ${modelType.modelName}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load Whisper model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Transcribe a 16kHz WAV file
  Future<String> transcribeAudio(String audioFilePath) async {
    if (!_isModelLoaded || _whisper == null) {
      return "Error: Whisper model not loaded.";
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
