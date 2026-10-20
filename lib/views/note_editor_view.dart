import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../providers/speech_state_provider.dart';
import '../../providers/models_provider.dart';
import '../../services/tts_service.dart';
import 'widgets/transcription_bottom_bar.dart';

class NoteEditorView extends ConsumerStatefulWidget {
  final Note? initialNote;

  const NoteEditorView({super.key, this.initialNote});

  @override
  ConsumerState<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends ConsumerState<NoteEditorView> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late List<String> _tags;
  String? _audioPath;
  bool _isPinned = false;
  bool _isNew = true;
  String? _noteId;

  final TtsService _ttsService = TtsService.instance;

  @override
  void initState() {
    super.initState();
    _isNew = widget.initialNote == null;
    _noteId = widget.initialNote?.id ?? const Uuid().v4();
    _titleController = TextEditingController(text: widget.initialNote?.title ?? '');
    _contentController = TextEditingController(text: widget.initialNote?.content ?? '');
    _tags = List.from(widget.initialNote?.tags ?? []);
    _audioPath = widget.initialNote?.audioPath;
    _isPinned = widget.initialNote?.isPinned ?? false;

    _ttsService.init();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && _audioPath == null) {
      Navigator.pop(context);
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: _noteId!,
      title: title,
      content: content,
      createdAt: widget.initialNote?.createdAt ?? now,
      updatedAt: now,
      audioPath: _audioPath,
      tags: _tags,
      isPinned: _isPinned,
    );

    if (_isNew) {
      ref.read(notesProvider.notifier).addNote(note);
    } else {
      ref.read(notesProvider.notifier).updateNote(note);
    }

    Navigator.pop(context);
  }

  void _addTagDialog() {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: tagCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. ideas, work, personal',
            prefixText: '#',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final tag = tagCtrl.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
              if (tag.isNotEmpty && !_tags.contains(tag)) {
                setState(() => _tags.add(tag));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showTtsSpeedSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Speech Speed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                final isSelected = (_ttsService.speechRate - speed).abs() < 0.05;
                return ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _ttsService.setRate(speed));
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final speechState = ref.watch(speechProvider);
    final modelsState = ref.watch(modelsProvider);

    // Show error snackbar if transcription had an issue
    ref.listen<SpeechState>(speechProvider, (prev, next) {
      if (next.status == RecordingStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveNote();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New Note' : 'Edit Note'),
          actions: [
            // Read Aloud (TTS) Button
            ValueListenableBuilder<TtsState>(
              valueListenable: _ttsService.stateNotifier,
              builder: (context, ttsState, child) {
                final isPlaying = ttsState == TtsState.playing;
                return IconButton(
                  icon: Icon(
                    isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    color: isPlaying ? colorScheme.primary : null,
                  ),
                  tooltip: isPlaying ? 'Stop reading' : 'Read note aloud',
                  onPressed: () {
                    if (isPlaying) {
                      _ttsService.stop();
                    } else {
                      final textToRead = '${_titleController.text}. ${_contentController.text}'.trim();
                      if (textToRead.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note has no text to read')),
                        );
                        return;
                      }
                      _ttsService.speak(textToRead, activeModel: modelsState.activeTtsModel);
                    }
                  },
                  onLongPress: _showTtsSpeedSheet,
                );
              },
            ),

            // Pin Note
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              onPressed: () => setState(() => _isPinned = !_isPinned),
            ),

            // Done / Save
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save Note',
              onPressed: _saveNote,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Input
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8.0),

                    // Tags Bar
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ..._tags.map((tag) => Chip(
                              label: Text('#$tag'),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _tags.remove(tag)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Add Tag'),
                          onPressed: _addTagDialog,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const Divider(height: 24.0),

                    // Content Input
                    TextField(
                      controller: _contentController,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: 'Type your note or tap the microphone below to record and transcribe offline with Whisper...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Audio Recording Bar
            TranscriptionBottomBar(
              speechState: speechState,
              onStartRecord: () async {
                await ref.read(speechProvider.notifier).startRecording();
              },
              onStopAndTranscribe: () async {
                final transcribed = await ref.read(speechProvider.notifier).stopAndTranscribe();
                if (transcribed != null && transcribed.isNotEmpty) {
                  setState(() {
                    if (_contentController.text.trim().isNotEmpty) {
                      _contentController.text = '${_contentController.text.trim()}\n\n$transcribed';
                    } else {
                      _contentController.text = transcribed;
                    }
                    _audioPath = speechState.recordedAudioPath;
                  });
                }
              },
              onCancel: () async {
                await ref.read(speechProvider.notifier).cancelRecording();
              },
            ),
          ],
        ),
      ),
    );
  }
}
