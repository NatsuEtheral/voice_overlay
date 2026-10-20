import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_recorder_service.dart';
import '../services/clean_speech_service.dart';
import '../services/stt_service.dart';
import 'models_provider.dart';

enum RecordingStatus { idle, recording, transcribing, success, error }

class SpeechState {
  final RecordingStatus status;
  final String? recordedAudioPath;
  final String transcribedText;
  final Duration recordingDuration;
  final double currentAmplitude;
  final String? errorMessage;

  SpeechState({
    this.status = RecordingStatus.idle,
    this.recordedAudioPath,
    this.transcribedText = '',
    this.recordingDuration = Duration.zero,
    this.currentAmplitude = 0.0,
    this.errorMessage,
  });

  SpeechState copyWith({
    RecordingStatus? status,
    String? recordedAudioPath,
    String? transcribedText,
    Duration? recordingDuration,
    double? currentAmplitude,
    String? errorMessage,
  }) {
    return SpeechState(
      status: status ?? this.status,
      recordedAudioPath: recordedAudioPath ?? this.recordedAudioPath,
      transcribedText: transcribedText ?? this.transcribedText,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      errorMessage: errorMessage,
    );
  }
}

class SpeechNotifier extends StateNotifier<SpeechState> {
  final Ref ref;
  Timer? _durationTimer;
  StreamSubscription<double>? _amplitudeSub;

  SpeechNotifier(this.ref) : super(SpeechState());

  Future<void> startRecording() async {
    try {
      state = state.copyWith(
        status: RecordingStatus.recording,
        recordingDuration: Duration.zero,
        errorMessage: null,
        transcribedText: '',
      );

      final path = await AudioRecorderService.instance.startRecording();

      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        state = state.copyWith(
          recordingDuration: AudioRecorderService.instance.currentDuration,
        );
      });

      _amplitudeSub?.cancel();
      _amplitudeSub = AudioRecorderService.instance.amplitudeStream.listen((amp) {
        state = state.copyWith(currentAmplitude: amp);
      });

      state = state.copyWith(recordedAudioPath: path);
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Microphone error: $e',
      );
    }
  }

  Future<String?> stopAndTranscribe() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();

    final path = await AudioRecorderService.instance.stopRecording();
    if (path == null) {
      state = state.copyWith(status: RecordingStatus.idle);
      return null;
    }

    state = state.copyWith(
      status: RecordingStatus.transcribing,
      recordedAudioPath: path,
    );

    try {
      final modelsState = ref.read(modelsProvider);
      final activeStt = modelsState.activeSttModel;

      if (activeStt == null || !activeStt.isDownloaded) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: 'No Whisper model is downloaded. Please download one in Model Settings.',
        );
        return null;
      }

      if (!SttService.instance.isModelLoaded) {
        final ready = await SttService.instance.initModel(activeStt);
        if (!ready) {
          state = state.copyWith(
            status: RecordingStatus.error,
            errorMessage: 'Failed to initialize Whisper model files.',
          );
          return null;
        }
      }

      final rawText = await SttService.instance.transcribeWavFile(path);
      final text = CleanSpeechService.instance.clean(rawText);

      state = state.copyWith(
        status: RecordingStatus.success,
        transcribedText: text,
      );
      return text;
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Transcription failed: $e',
      );
      return null;
    }
  }

  Future<void> cancelRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    await AudioRecorderService.instance.cancelRecording();
    state = SpeechState();
  }

  void reset() {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    state = SpeechState();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    super.dispose();
  }
}

final speechProvider = StateNotifierProvider<SpeechNotifier, SpeechState>((ref) {
  return SpeechNotifier(ref);
});
