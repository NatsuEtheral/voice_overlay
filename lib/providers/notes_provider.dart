import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class NotesState {
  final List<Note> notes;
  final bool isLoading;
  final String searchQuery;
  final String? selectedTag;

  NotesState({
    this.notes = const [],
    this.isLoading = true,
    this.searchQuery = '',
    this.selectedTag,
  });

  NotesState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? searchQuery,
    String? selectedTag,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTag: selectedTag,
    );
  }

  List<Note> get filteredNotes {
    var result = notes;
    if (selectedTag != null && selectedTag!.isNotEmpty) {
      result = result.where((n) => n.tags.contains(selectedTag)).toList();
    }
    return result;
  }

  List<String> get allTags {
    final Set<String> tagSet = {};
    for (final note in notes) {
      tagSet.addAll(note.tags);
    }
    return tagSet.toList();
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  NotesNotifier() : super(NotesState()) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    state = state.copyWith(isLoading: true);
    final notes = await DatabaseService.instance.getAllNotes();
    state = state.copyWith(notes: notes, isLoading: false);
  }

  Future<void> searchNotes(String query) async {
    state = state.copyWith(searchQuery: query, isLoading: true);
    final notes = await DatabaseService.instance.searchNotes(query);
    state = state.copyWith(notes: notes, isLoading: false);
  }

  void selectTag(String? tag) {
    state = state.copyWith(selectedTag: tag == state.selectedTag ? null : tag);
  }

  Future<void> addNote(Note note) async {
    await DatabaseService.instance.insertNote(note);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await DatabaseService.instance.updateNote(note);
    await loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await DatabaseService.instance.deleteNote(id);
    await loadNotes();
  }

  Future<void> togglePin(String id, bool isPinned) async {
    await DatabaseService.instance.togglePin(id, !isPinned);
    await loadNotes();
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier();
});
