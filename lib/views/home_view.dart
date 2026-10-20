import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notes_provider.dart';
import '../../providers/models_provider.dart';
import '../services/overlay_service.dart';
import 'note_editor_view.dart';
import 'model_manager_view.dart';
import 'widgets/note_card.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  bool _isOverlayActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlayStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOverlayStatus();
    }
  }

  Future<void> _checkOverlayStatus() async {
    final active = await OverlayService.instance.isOverlayActive();
    if (mounted) setState(() => _isOverlayActive = active);
  }

  Future<void> _toggleOverlay(bool enable) async {
    if (enable) {
      await OverlayService.instance.showOverlay();
    } else {
      await OverlayService.instance.closeOverlay();
    }
    await _checkOverlayStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notesState = ref.watch(notesProvider);
    final modelsState = ref.watch(modelsProvider);

    final filteredNotes = notesState.filteredNotes;
    final allTags = notesState.allTags;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VoiceNotes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (modelsState.activeSttModel != null)
              Text(
                '⚡ ${modelsState.activeSttModel!.name} (Offline)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Speech Models & Offline Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelManagerView()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search notes or tags...',
              leading: const Icon(Icons.search),
              trailing: _searchController.text.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(notesProvider.notifier).searchNotes('');
                        },
                      ),
                    ]
                  : null,
              onChanged: (val) {
                ref.read(notesProvider.notifier).searchNotes(val);
              },
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              ),
            ),
          ),

          // Floating Bubble Dictation Quick Control
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: _isOverlayActive
                      ? colorScheme.primary.withValues(alpha: 0.6)
                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: _isOverlayActive ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: _isOverlayActive
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bubble_chart,
                      size: 20,
                      color: _isOverlayActive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Floating Voice Bubble',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isOverlayActive
                            ? 'Active over WhatsApp, Slack, etc.'
                            : 'Dictate anywhere without typing',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOverlayActive,
                    onChanged: (val) => _toggleOverlay(val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6.0),

          // Tags Filter Carousel
          if (allTags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: notesState.selectedTag == null,
                      onSelected: (_) => ref.read(notesProvider.notifier).selectTag(null),
                    ),
                  ),
                  ...allTags.map((tag) {
                    final isSelected = notesState.selectedTag == tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text('#$tag'),
                        selected: isSelected,
                        onSelected: (_) => ref.read(notesProvider.notifier).selectTag(tag),
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Notes List or Empty State
          Expanded(
            child: notesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotes.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return NoteCard(
                            note: note,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoteEditorView(initialNote: note),
                                ),
                              );
                            },
                            onTogglePin: () {
                              ref.read(notesProvider.notifier).togglePin(note.id, note.isPinned);
                            },
                            onDelete: () {
                              ref.read(notesProvider.notifier).deleteNote(note.id);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorView()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
        elevation: 3,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none_outlined,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16.0),
            Text(
              'No Voice Notes Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Record your thoughts on-device with Whisper.\n100% private, works in Airplane Mode.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
