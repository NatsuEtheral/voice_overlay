import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedDate = DateFormat('MMM d, h:mm a').format(note.updatedAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: note.isPinned
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: note.isPinned ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title + Pin button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isNotEmpty ? note.title : 'Untitled Note',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: note.title.isNotEmpty
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20,
                        color: note.isPinned
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      onPressed: onTogglePin,
                      visualDensity: VisualDensity.compact,
                      tooltip: note.isPinned ? 'Unpin' : 'Pin to top',
                    ),
                  ],
                ),
                const SizedBox(height: 6.0),

                // Content snippet
                Text(
                  note.content.isNotEmpty ? note.content : 'No content yet...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12.0),

                // Tags & Badges
                if (note.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          '#$tag',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10.0),
                ],

                // Footer: Date + Audio badge + word count
                Row(
                  children: [
                    Text(
                      formattedDate,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const Spacer(),
                    if (note.audioPath != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 14, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 3.0),
                            Text(
                              'Voice',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                    ],
                    Text(
                      '${note.wordCount} words',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
