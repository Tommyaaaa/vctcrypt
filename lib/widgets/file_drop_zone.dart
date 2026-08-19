/// VCTCrypt - File Selection Card
/// Displays file state, handles tap + drag-and-drop on desktop

import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileSelectionCard extends StatefulWidget {
  final String? filePath;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final ValueChanged<String> onFileDropped;

  const FileSelectionCard({
    super.key,
    this.filePath,
    required this.hint,
    this.icon = Icons.upload_file,
    required this.onTap,
    required this.onFileDropped,
  });

  @override
  State<FileSelectionCard> createState() => _FileSelectionCardState();
}

class _FileSelectionCardState extends State<FileSelectionCard> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = widget.filePath != null && widget.filePath!.isNotEmpty;
    final fileName = hasFile ? p.basename(widget.filePath!) : null;

    Color bgColor;
    if (_isDragging) {
      bgColor = theme.colorScheme.primaryContainer;
    } else if (hasFile) {
      bgColor = theme.colorScheme.secondaryContainer;
    } else {
      bgColor = theme.colorScheme.surfaceContainerHighest;
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          final path = details.files.first.path;
          if (File(path).existsSync()) {
            widget.onFileDropped(path);
          }
        }
        setState(() => _isDragging = false);
      },
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 130),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: _isDragging
                  ? Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasFile ? Icons.check_circle_rounded : widget.icon,
                  size: 48,
                  color: hasFile
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                if (hasFile) ...[
                  Text(
                    fileName!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.filePath!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    widget.hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
