/// VCTCrypt - Decrypt Screen
/// VCT file selection + password + triple AES-256-GCM decryption

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../crypto/vct_crypto.dart' as crypto;
import '../i18n/strings.dart';
import '../main.dart';
import '../utils/usage_stats.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/file_info_dialog.dart';
import 'help_screen.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  String? _filePath;
  final _pwController = TextEditingController();
  bool _obscurePw = true;
  bool _processing = false;
  String _statusText = '';
  String? _resultText;
  bool _isError = false;
  String? _outputPath;
  String? _originalName;
  int? _outputSize;
  bool _lockBound = false;
  ValueNotifier<int>? _lockPulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_lockBound) {
      _lockPulse = VCTCryptApp.of(context).lockPulse;
      _lockPulse!.addListener(_onAutoLock);
      _lockBound = true;
    }
  }

  @override
  void dispose() {
    _lockPulse?.removeListener(_onAutoLock);
    _pwController.dispose();
    super.dispose();
  }

  /// Auto-lock fired: clear the password field.
  void _onAutoLock() {
    if (!mounted) return;
    _pwController.clear();
    setState(() {});
  }

  AppStrings get _strings => VCTCryptApp.of(context).strings;

  Future<void> _pickFile() async {
    // Desktop dialogs support extension masks (.VCT / .vct) natively.
    // On iOS the picker filters by system UTI types - ".vct" has no
    // registered UTI, so every file would be greyed out and unselectable
    // (Android's MIME mapping has the same gap for unknown extensions).
    // There we allow any file; the decrypt engine validates the VCT
    // magic bytes and reports a clear error for non-VCT picks.
    final isMobile = Platform.isIOS || Platform.isAndroid;
    final result = await FilePicker.platform.pickFiles(
      type: isMobile ? FileType.any : FileType.custom,
      allowedExtensions: isMobile ? null : ['VCT', 'vct'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
        _resultText = null;
      });
    }
  }

  Future<void> _decrypt() async {
    if (_filePath == null) {
      _showSnackBar(_strings.errNotFound, isError: true);
      return;
    }
    if (_pwController.text.isEmpty) {
      _showSnackBar(_strings.errPwShort, isError: true);
      return;
    }

    setState(() {
      _processing = true;
      _statusText = _strings.statusProcessing;
      _resultText = null;
      _isError = false;
    });

    final result = await crypto.decryptFile(
      _filePath!,
      _pwController.text,
      (msg) {
        if (mounted) setState(() => _statusText = _strings.progressMessage(msg));
      },
    );

    if (!mounted) return;

    // v1.2.0: local usage statistics (aggregate numbers only).
    if (result.success) {
      unawaited(UsageStats.recordDecrypt(bytes: result.outputSize ?? 0));
    } else if (result.duressTriggered) {
      // Silent by design (deniability) - only the local counter knows.
      unawaited(UsageStats.recordDuressTrigger());
    }

    setState(() {
      _processing = false;
      if (result.success) {
        _resultText = _strings.decSuccess;
        _isError = false;
        _outputPath = result.outputPath;
        _originalName = result.originalName;
        _outputSize = result.outputSize;
        _pwController.clear();
      } else {
        _resultText = _strings.errorMessage(result.error ?? '');
        _isError = true;
      }
      _statusText = _strings.statusReady;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.decryptTitle),
        actions: [
          // v1.3.0: help & usage
          IconButton(
            tooltip: strings.helpTitle,
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          // v1.2.0: panic lock - wipe the entered password immediately
          IconButton(
            tooltip: strings.panicLock,
            icon: const Icon(Icons.gpp_maybe_outlined),
            onPressed: () {
              VCTCryptApp.of(context).panicLock();
              _showSnackBar(strings.panicLocked);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.decryptSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // File selection
                FileSelectionCard(
                  filePath: _filePath,
                  hint: strings.selectVctFile,
                  icon: Icons.file_open,
                  onTap: _pickFile,
                  onFileDropped: (path) {
                    if (path.toLowerCase().endsWith('.vct')) {
                      setState(() {
                        _filePath = path;
                        _resultText = null;
                      });
                    } else {
                      _showSnackBar(_strings.errNotVct, isError: true);
                    }
                  },
                ),
                // v1.2.0: file inspector - header metadata, no password
                if (_filePath != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => showFileInfoDialog(context, _filePath!),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(strings.inspectTitle),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _pwController,
                  obscureText: _obscurePw,
                  decoration: InputDecoration(
                    labelText: strings.passwordLabel,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePw
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePw = !_obscurePw),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(256),
                  ],
                ),
                const SizedBox(height: 28),

                // Decrypt button
                FilledButton.icon(
                  onPressed: _processing ? null : _decrypt,
                  icon: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open),
                  label: Text(strings.navDecrypt),
                ),
                const SizedBox(height: 20),

                // Status / Progress
                if (_processing) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _statusText,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Result
                if (_resultText != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: _isError
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isError ? Icons.error : Icons.check_circle,
                                color: _isError
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _resultText!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: _isError
                                        ? theme.colorScheme.onErrorContainer
                                        : theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isError && _outputPath != null) ...[
                            const SizedBox(height: 12),
                            if (_originalName != null)
                              Text(
                                '${strings.originalFile}: $_originalName',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            Text(
                              '${strings.outputFile}: $_outputPath',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            if (_outputSize != null)
                              Text(
                                '${strings.fileSize}: ${_formatSize(_outputSize!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            if (Platform.isIOS || Platform.isAndroid) ...[
                              const SizedBox(height: 8),
                              Text(
                                strings.mobileOutputHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              // v1.4.0: share / save the decrypted file
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => Share.shareXFiles(
                                  [XFile(_outputPath!)],
                                  text: _originalName,
                                ),
                                icon: const Icon(Icons.share_outlined),
                                label: Text(strings.shareBtn),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes ${_strings.bytes}';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
