/// VCTCrypt - File Info Dialog (v1.2.0)
/// Shows public header metadata of a .VCT file without any password.
///
/// Deniability: only format-level facts are shown. V2 files always
/// contain all three slots (real/decoy/duress), so nothing here can
/// reveal whether a decoy or duress password exists.

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../crypto/vct_crypto.dart' as crypto;
import '../i18n/strings.dart';
import '../main.dart';
import '../utils/usage_stats.dart';

Future<void> showFileInfoDialog(
  BuildContext context,
  String path,
) async {
  final theme = Theme.of(context);
  final strings = VCTCryptApp.of(context).strings;

  late final crypto.VctFileInfo info;
  try {
    info = crypto.inspectVctFile(path);
  } catch (_) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.inspectTitle),
        content: Text(strings.errRead),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.dialogOk),
          ),
        ],
      ),
    );
    return;
  }

  if (!context.mounted) return;

  final formatLabel = info.isV2
      ? strings.infoFormatV2
      : info.isValid
          ? strings.infoFormatV1
          : strings.infoFormatInvalid;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(strings.inspectTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: strings.infoFileName, value: p.basename(path)),
            const SizedBox(height: 8),
            _Row(label: strings.infoFormat, value: formatLabel),
            const SizedBox(height: 8),
            _Row(
              label: strings.infoFileSize,
              value: UsageStats.formatBytes(info.fileSize, strings.bytes),
            ),
            if (info.realCtLen != null) ...[
              const SizedBox(height: 8),
              _Row(
                label: strings.infoPayload,
                value: UsageStats.formatBytes(
                    info.realCtLen!, strings.bytes),
              ),
            ],
            const SizedBox(height: 8),
            _Row(label: strings.infoHeader, value: '${info.headerLen}'),
            const SizedBox(height: 8),
            _Row(
              label: strings.infoAlgo,
              value: 'AES-256-GCM ×3',
            ),
            const SizedBox(height: 8),
            _Row(
              label: strings.infoKdf,
              value: strings.infoKdfValue,
            ),
            const SizedBox(height: 8),
            _Row(
              label: strings.infoModified,
              value:
                  '${info.modified.year}-${_two(info.modified.month)}-${_two(info.modified.day)} '
                  '${_two(info.modified.hour)}:${_two(info.modified.minute)}',
            ),
            if (info.isValid && info.isV2) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.infoDeniableNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(strings.dialogOk),
        ),
      ],
    ),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
