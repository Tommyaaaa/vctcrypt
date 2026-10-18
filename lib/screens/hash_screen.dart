/// VCTCrypt - Checksum / Hash Screen (v2.3.0)
/// Compute SHA-256 / SHA-512 / SHA-3-256 of any file (streamed, so it
/// works on large files without loading them into memory), then compare
/// against an expected checksum to verify integrity.

import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../crypto/vendor/mlkem/common/keccak.dart' show Sha3256Sink;
import '../i18n/strings.dart';
import '../main.dart';

class HashScreen extends StatefulWidget {
  const HashScreen({super.key});

  @override
  State<HashScreen> createState() => _HashScreenState();
}

class _HashScreenState extends State<HashScreen> {
  String? _path;
  String? _hash;
  int _algo = 0; // 0 = SHA-256, 1 = SHA-512, 2 = SHA-3-256
  bool _busy = false;
  double _progress = 0;

  HashAlgorithm? _algorithm() =>
      _algo == 2 ? null : (_algo == 1 ? Sha512() : Sha256());

  static String _toHex(int b) => b.toRadixString(16).padLeft(2, '0');

  String _algoLabel(AppStrings s) {
    switch (_algo) {
      case 1:
        return 'SHA-512';
      case 2:
        return 'SHA-3-256';
      default:
        return 'SHA-256';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _path = path;
      _hash = null;
      _progress = 0;
    });
  }

  Future<void> _compute() async {
    final path = _path;
    if (path == null || _busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _hash = null;
    });
    try {
      final file = File(path);
      final total = await file.length();
      var processed = 0;
      final String hex;
      final algorithm = _algorithm();
      if (algorithm == null) {
        // SHA-3-256: streamed through the bundled FIPS 202 Keccak sponge.
        final sink = Sha3256Sink();
        await for (final chunk in file.openRead()) {
          sink.add(chunk);
          processed += chunk.length;
          if (total > 0) {
            setState(() => _progress = processed / total);
          }
        }
        hex = sink.digest().map(_toHex).join();
      } else {
        final sink = algorithm.newHashSink();
        await for (final chunk in file.openRead()) {
          sink.add(chunk);
          processed += chunk.length;
          if (total > 0) {
            setState(() => _progress = processed / total);
          }
        }
        sink.close();
        final digest = await sink.hash();
        hex = digest.bytes.map(_toHex).join();
      }
      if (mounted) {
        setState(() {
          _hash = hex;
          _busy = false;
          _progress = 1;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(VCTCryptApp.of(context).strings.errRead)),
        );
      }
    }
  }

  Future<void> _copy() async {
    final hash = _hash;
    if (hash == null) return;
    await Clipboard.setData(ClipboardData(text: hash));
    VCTCryptApp.of(context).armClipboardClear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(VCTCryptApp.of(context).strings.genCopied),
        ),
      );
    }
  }

  void _compare(String expected) {
    final hash = _hash;
    final strings = VCTCryptApp.of(context).strings;
    if (hash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.hashEmptyResult)),
      );
      return;
    }
    final clean = expected.trim().toLowerCase();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.hashNoExpected)),
      );
      return;
    }
    final ok = clean == hash.toLowerCase();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          ok ? Icons.verified_outlined : Icons.error_outline,
          color: ok ? Colors.green : Theme.of(ctx).colorScheme.error,
          size: 40,
        ),
        title: Text(ok ? strings.hashMatch : strings.hashMismatch),
        content: Text(
          ok ? strings.hashMatchBody : strings.hashMismatchBody,
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

  @override
  Widget build(BuildContext context) {
    final strings = VCTCryptApp.of(context).strings;
    final theme = Theme.of(context);
    final fileName = _path == null ? null : _path!.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(title: Text(strings.hashTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.hashSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // ---- file picker ----
                Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: _busy ? null : _pickFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName ?? strings.selectFile,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (fileName != null)
                                  Text(
                                    '${strings.fileSize}: '
                                    '${_formatBytes(_path!)}, '
                                    '${_algoLabel(strings)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- algorithm ----
                Text(
                  strings.hashAlgo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (i, label) in const [
                      (0, 'SHA-256'),
                      (1, 'SHA-512'),
                      (2, 'SHA-3-256'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _algo == i,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                  _algo = i;
                                  _hash = null;
                                  _progress = 0;
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---- compute ----
                FilledButton.icon(
                  onPressed: _busy || _path == null ? null : _compute,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_busy ? strings.hashComputing : strings.hashCompute),
                ),
                if (_busy || _hash != null) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress),
                ],

                // ---- result ----
                if (_hash != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.fingerprint,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_algoLabel(strings)} ${strings.hashResult}',
                                style: theme.textTheme.titleSmall,
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: strings.hashCopy,
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: _copy,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _hash!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.hashExpectedLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _expectedController,
                    decoration: InputDecoration(
                      hintText: strings.hashExpectedHint,
                    ),
                    onSubmitted: _compare,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final controller = _expectedController;
                      _compare(controller.text);
                    },
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(strings.hashCompare),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  final _expectedController = TextEditingController();

  @override
  void dispose() {
    _expectedController.dispose();
    super.dispose();
  }

  String _formatBytes(String path) {
    try {
      final len = File(path).lengthSync();
      if (len < 1024) return '$len B';
      if (len < 1024 * 1024) return '${(len / 1024).toStringAsFixed(1)} KB';
      if (len < 1024 * 1024 * 1024) {
        return '${(len / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(len / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (_) {
      return '?';
    }
  }
}
