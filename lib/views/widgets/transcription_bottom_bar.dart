import 'package:flutter/material.dart';
import '../../providers/speech_state_provider.dart';
import 'audio_visualizer.dart';

class TranscriptionBottomBar extends StatelessWidget {
  final SpeechState speechState;
  final VoidCallback onStartRecord;
  final VoidCallback onStopAndTranscribe;
  final VoidCallback onCancel;

  const TranscriptionBottomBar({
    super.key,
    required this.speechState,
    required this.onStartRecord,
    required this.onStopAndTranscribe,
    required this.onCancel,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (speechState.status == RecordingStatus.transcribing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14.0),
            Text(
              'Transcribing on-device with Whisper...',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    if (speechState.status == RecordingStatus.recording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waveform & Duration
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.0),
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
                      const SizedBox(width: 6.0),
                      Text(
                        _formatDuration(speechState.recordingDuration),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: AudioVisualizer(
                    amplitude: speechState.currentAmplitude,
                    isRecording: true,
                    barColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: onCancel,
                  tooltip: 'Cancel Recording',
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop & Transcribe'),
                  onPressed: onStopAndTranscribe,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Default Idle Bar
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Speak your thoughts offline',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FloatingActionButton.small(
              heroTag: 'record_button',
              onPressed: onStartRecord,
              elevation: 2,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.mic, color: colorScheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
