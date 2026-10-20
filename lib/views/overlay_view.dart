import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/speech_model_info.dart';
import '../services/audio_recorder_service.dart';
import '../services/clean_speech_service.dart';
import '../services/database_service.dart';
import '../services/model_downloader_service.dart';
import '../services/overlay_service.dart';
import '../services/stt_service.dart';
import 'widgets/audio_visualizer.dart';

enum _OverlayUiState { bubble, recording, transcribing, result }

class VoiceOverlayWidget extends StatefulWidget {
  const VoiceOverlayWidget({super.key});

  @override
  State<VoiceOverlayWidget> createState() => _VoiceOverlayWidgetState();
}

class _VoiceOverlayWidgetState extends State<VoiceOverlayWidget> {
  _OverlayUiState _state = _OverlayUiState.bubble;
  String _transcribedText = '';
  double _amplitude = 0.0;
  Duration _duration = Duration.zero;
  bool _cleanSpeech = true;
  bool _isSaved = false;

  Timer? _timer;
  StreamSubscription<double>? _amplitudeSub;
  Timer? _autoCollapseTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _autoCollapseTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    _autoCollapseTimer?.cancel();
    setState(() {
      _state = _OverlayUiState.recording;
      _duration = Duration.zero;
      _isSaved = false;
    });

    await OverlayService.resizeToRecording();

    try {
      await AudioRecorderService.instance.startRecording();

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _duration = AudioRecorderService.instance.currentDuration;
        });
      });

      _amplitudeSub?.cancel();
      _amplitudeSub = AudioRecorderService.instance.amplitudeStream.listen((amp) {
        setState(() => _amplitude = amp);
      });
    } catch (e) {
      debugPrint('Error starting recording in overlay: $e');
      _collapseToBubble();
    }
  }

  Future<void> _stopAndTranscribe() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();

    setState(() => _state = _OverlayUiState.transcribing);

    final path = await AudioRecorderService.instance.stopRecording();
    if (path == null) {
      _collapseToBubble();
      return;
    }

    try {
      // Ensure model is loaded
      if (!SttService.instance.isModelLoaded) {
        final models = defaultModelCatalog.where((m) => m.type == SpeechModelType.stt);
        SpeechModelInfo? modelToLoad;
        for (final m in models) {
          if (await ModelDownloaderService.instance.isModelDownloaded(m)) {
            modelToLoad = m;
            break;
          }
        }
        if (modelToLoad != null) {
          await SttService.instance.initModel(modelToLoad);
        }
      }

      final rawText = await SttService.instance.transcribeWavFile(path);
      final polishedText = CleanSpeechService.instance.clean(rawText, enabled: _cleanSpeech);

      // Auto-copy to clipboard
      await Clipboard.setData(ClipboardData(text: polishedText));
      await HapticFeedback.mediumImpact();

      await OverlayService.resizeToResult();

      setState(() {
        _transcribedText = polishedText;
        _state = _OverlayUiState.result;
      });

      // Auto-collapse after 15 seconds of inactivity
      _autoCollapseTimer?.cancel();
      _autoCollapseTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _state == _OverlayUiState.result) {
          _collapseToBubble();
        }
      });
    } catch (e) {
      debugPrint('Overlay transcription error: $e');
      setState(() {
        _transcribedText = 'Transcription error: $e';
        _state = _OverlayUiState.result;
      });
      await OverlayService.resizeToResult();
    }
  }

  Future<void> _saveAsNote() async {
    if (_transcribedText.trim().isEmpty || _isSaved) return;

    final now = DateTime.now();
    final note = Note(
      id: const Uuid().v4(),
      title: 'Voice Clip (${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})',
      content: _transcribedText,
      createdAt: now,
      updatedAt: now,
      tags: ['voice-overlay'],
    );

    await DatabaseService.instance.insertNote(note);
    await HapticFeedback.lightImpact();

    setState(() => _isSaved = true);
  }

  Future<void> _collapseToBubble() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    _autoCollapseTimer?.cancel();

    if (AudioRecorderService.instance.isRecording) {
      await AudioRecorderService.instance.cancelRecording();
    }

    setState(() {
      _state = _OverlayUiState.bubble;
      _duration = Duration.zero;
      _amplitude = 0.0;
    });

    await OverlayService.resizeToBubble();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: switch (_state) {
          _OverlayUiState.bubble => _buildBubble(),
          _OverlayUiState.recording => _buildRecordingPill(),
          _OverlayUiState.transcribing => _buildTranscribingPill(),
          _OverlayUiState.result => _buildResultCard(),
        },
      ),
    );
  }

  /// State 1: Collapsed Draggable Bubble (64x64)
  Widget _buildBubble() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF1E222D),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6366F1), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// State 2: Active Recording Pill
  Widget _buildRecordingPill() {
    return Container(
      width: 260,
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(36.0),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Red Pulsing Indicator + Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4.0),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),

          // 120Hz Audio Waveform Visualizer
          Expanded(
            child: AudioVisualizer(
              amplitude: _amplitude,
              isRecording: true,
              barColor: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 8.0),

          // Stop Button
          GestureDetector(
            onTap: _stopAndTranscribe,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4.0),

          // Cancel
          GestureDetector(
            onTap: _collapseToBubble,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// State 3: Transcribing Spinner Pill
  Widget _buildTranscribingPill() {
    return Container(
      width: 250,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(color: const Color(0xFF6366F1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
          SizedBox(width: 12.0),
          Text(
            'Whisper transcribing...',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// State 4: Result Window with Auto-Copy and Save to Note
  Widget _buildResultCard() {
    return Container(
      width: 310,
      height: 170,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Copied Badge + Clean Speech Toggle + Close
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6.0),
              const Text(
                'Copied to Clipboard!',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              // Clean speech toggle
              GestureDetector(
                onTap: () {
                  setState(() => _cleanSpeech = !_cleanSpeech);
                  final cleaned = CleanSpeechService.instance.clean(_transcribedText, enabled: _cleanSpeech);
                  Clipboard.setData(ClipboardData(text: cleaned));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: _cleanSpeech
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    _cleanSpeech ? 'Clean: ON' : 'Clean: OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _cleanSpeech ? const Color(0xFF818CF8) : Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              GestureDetector(
                onTap: _collapseToBubble,
                child: const Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8.0),

          // Transcribed Text (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _transcribedText,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8.0),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                label: const Text('Record Again', style: TextStyle(color: Colors.white70, fontSize: 12)),
                onPressed: _startRecording,
              ),
              const SizedBox(width: 8.0),
              FilledButton.icon(
                icon: Icon(_isSaved ? Icons.check : Icons.bookmark_add_outlined, size: 16),
                label: Text(_isSaved ? 'Saved' : 'Save Note', style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _isSaved ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _saveAsNote,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
