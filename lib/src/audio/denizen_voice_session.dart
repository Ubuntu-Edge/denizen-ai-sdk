import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'offline_audio_service.dart';
import 'dart:io';

/// A session specifically designed for voice interactions.
class DenizenVoiceSession {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final String _systemPrompt;
  bool _isRecording = false;

  DenizenVoiceSession({String? systemPrompt})
      : _systemPrompt = systemPrompt ?? 'You are a helpful voice assistant.';

  bool get isRecording => _isRecording;

  /// Start recording audio from the microphone
  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'denizen_voice_temp.wav');
      
      // Whisper requires 16kHz, mono, 16-bit PCM WAV
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 16 * 16000,
        ),
        path: path,
      );
      _isRecording = true;
    } else {
      throw Exception('Microphone permission denied.');
    }
  }

  /// Stop recording and transcribe the audio
  /// 
  /// Returns the transcribed text. In a full implementation, this text would then
  /// be piped directly into `DenizenSession` to get the LLM response.
  Future<String> stopAndTranscribe() async {
    if (!_isRecording) return "";
    
    final path = await _audioRecorder.stop();
    _isRecording = false;
    
    if (path != null && await File(path).exists()) {
      final transcription = await OfflineAudioService.instance.transcribeAudio(path);
      return transcription;
    }
    
    return "Error: No audio recorded.";
  }

  /// Transcribe a pre-existing audio file
  Future<String> transcribeFile(String filePath) async {
    return await OfflineAudioService.instance.transcribeAudio(filePath);
  }
}
