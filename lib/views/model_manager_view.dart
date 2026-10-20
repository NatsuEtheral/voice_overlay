import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/speech_model_info.dart';
import '../../providers/models_provider.dart';

class ModelManagerView extends ConsumerWidget {
  const ModelManagerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsState = ref.watch(modelsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Speech Models (Offline)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.record_voice_over), text: 'STT (Whisper)'),
              Tab(icon: Icon(Icons.volume_up), text: 'TTS (Voice Output)'),
            ],
          ),
        ),
        body: modelsState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _ModelList(
                    models: modelsState.models
                        .where((m) => m.type == SpeechModelType.stt)
                        .toList(),
                    activeModelId: modelsState.activeSttModelId,
                  ),
                  _ModelList(
                    models: modelsState.models
                        .where((m) => m.type == SpeechModelType.tts)
                        .toList(),
                    activeModelId: modelsState.activeTtsModelId,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ModelList extends ConsumerWidget {
  final List<SpeechModelInfo> models;
  final String? activeModelId;

  const _ModelList({
    required this.models,
    required this.activeModelId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final isSelected = model.id == activeModelId;
        final isDownloading = model.downloadProgress > 0.0 && model.downloadProgress < 1.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: isSelected ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Active indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Description
                Text(
                  model.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Tags: Size, Speed, Accuracy
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    _InfoChip(label: model.formattedSize, icon: Icons.storage),
                    _InfoChip(label: model.speedRating),
                    _InfoChip(label: 'Accuracy: ${model.accuracyRating}'),
                  ],
                ),
                const SizedBox(height: 14.0),

                // Download progress bar
                if (isDownloading) ...[
                  LinearProgressIndicator(
                    value: model.downloadProgress,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    'Downloading & unpacking ${(model.downloadProgress * 100).toStringAsFixed(0)}%...',
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                  ),
                  const SizedBox(height: 10.0),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (model.isDownloaded && !model.isDefaultBuiltIn)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        onPressed: () {
                          ref.read(modelsProvider.notifier).deleteModel(model.id);
                        },
                      ),
                    const SizedBox(width: 8.0),
                    if (!model.isDownloaded && !model.isDefaultBuiltIn)
                      FilledButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download'),
                        onPressed: isDownloading
                            ? null
                            : () {
                                ref.read(modelsProvider.notifier).downloadModel(model.id);
                              },
                      )
                    else if (!isSelected)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Set as Active'),
                        onPressed: () {
                          ref.read(modelsProvider.notifier).selectModel(model.id);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _InfoChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4.0),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
