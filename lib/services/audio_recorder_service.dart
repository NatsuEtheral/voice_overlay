import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

class AudioRecorderService {
  static final AudioRecorderService instance = AudioRecorderService._internal();
  AudioRecorderService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  String? _currentRecordingPath;
  String? get currentRecordingPath => _currentRecordingPath;

  DateTime? _recordingStartTime;
  Duration get currentDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<String?> startRecording() async {
    if (_isRecording) return null;

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.wav';
    final filePath = p.join(tempDir.path, fileName);
    _currentRecordingPath = filePath;

    // Whisper requires 16000Hz 16-bit mono PCM wav
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 256000,
    );

    await _audioRecorder.start(config, path: filePath);
    _isRecording = true;
    _recordingStartTime = DateTime.now();

    // Listen to amplitude for visualizer (polls every 50ms for smooth 120Hz waveform)
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
      // amp.current is typically -160 to 0 dB. Normalize to 0.0 - 1.0
      double normalized = (amp.current + 60) / 60.0;
      if (normalized < 0.0) normalized = 0.0;
      if (normalized > 1.0) normalized = 1.0;
      _amplitudeController.add(normalized);
    });

    return filePath;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _audioRecorder.stop();
    _isRecording = false;
    _recordingStartTime = null;

    return path ?? _currentRecordingPath;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    final path = await stopRecording();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  void dispose() {
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _amplitudeController.close();
    _audioRecorder.dispose();
  }
}
