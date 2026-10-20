import 'dart:math' as math;
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final double amplitude; // 0.0 to 1.0
  final bool isRecording;
  final Color? barColor;

  const AudioVisualizer({
    super.key,
    required this.amplitude,
    required this.isRecording,
    this.barColor,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Smooth 120Hz animated loop for idle wave motion
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.barColor ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(24, (index) {
              final phase = (index / 24) * 2 * math.pi;
              final sinValue = math.sin(_animController.value * 2 * math.pi + phase).abs();

              double height;
              if (widget.isRecording) {
                // Combine real mic amplitude with randomized harmonic jitter
                final randomJitter = _random.nextDouble() * 0.3;
                height = 6.0 + (widget.amplitude * 34.0) + (sinValue * 6.0) + randomJitter;
              } else {
                height = 6.0 + (sinValue * 8.0);
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 3.5,
                height: height.clamp(4.0, 48.0),
                decoration: BoxDecoration(
                  color: widget.isRecording
                      ? color.withValues(alpha: 0.6 + (widget.amplitude * 0.4).clamp(0.0, 0.4))
                      : color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4.0),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
