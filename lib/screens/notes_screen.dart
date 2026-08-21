/// VCTCrypt - Secure Notes screen (v1.5.0)
///
/// Encrypt text straight into a .VCT file and decrypt notes back to
/// text IN MEMORY - the plaintext never persists on disk (the transient
/// temp file is shredded). 100% offline.

import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../crypto/vct_crypto.dart' as crypto;
import '../i18n/strings.dart';
import '../main.dart';
import '../utils/password_generator.dart';
import '../utils/usage_stats.dart';
import '../widgets/password_strength.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _encryptMode = true;

  // ---- encrypt ----
  final _textController = TextEditingController();
  final _pwController = TextEditingController();
  final _pw2Controller = TextEditingController();
  bool _obscurePw = true;

  // ---- decrypt ----
  String? _filePath;
  final _dPwController = TextEditingController();
  bool _obscureDPw = true;

  // ---- shared state ----
  bool _processing = false;
  String _statusText = '';
  String? _resultText;
  bool _isError = false;
  String? _outputPath; // encrypt: the .VCT produced
  String? _noteText; // decrypt: decrypted note content
  String? _noteName; // decrypt: embedded original name
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
    _textController.dispose();
    _pwController.dispose();
    _pw2Controller.dispose();
    _dPwController.dispose();
    super.dispose();
  }

  void _onAutoLock() {
    if (!mounted) return;
    _pwController.clear();
    _pw2Controller.clear();
    _dPwController.clear();
    setState(() {});
  }

  AppStrings get _strings => VCTCryptApp.of(context).strings;

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : null),
    );
  }

  void _resetResult() {
    _resultText = null;
    _isError = false;
    _outputPath = null;
    _noteText = null;
    _noteName = null;
  }

  Future<void> _encryptNote() async {
    final text = _textController.text;
    final pw = _pwController.text;
    if (text.isEmpty) {
      _showSnackBar(_strings.noteEmpty, isError: true);
      return;
    }
    if (pw.length < 4) {
      _showSnackBar(_strings.errPwShort, isError: true);
      return;
    }
    if (pw != _pw2Controller.text) {
      _showSnackBar(_strings.errPwMismatch, isError: true);
      return;
    }

    // Desktop: ask where to save the .VCT. Mobile: Documents (same as
    // regular encryption) + share button afterwards.
    String? outputPath;
    if (!Platform.isIOS && !Platform.isAndroid) {
      final ts = DateTime.now();
      final suggested =
          'VCTCrypt-Note-${ts.year}${_two(ts.month)}${_two(ts.day)}-'
          '${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}.VCT';
      outputPath = await FilePicker.platform.saveFile(
        fileName: suggested,
        type: FileType.custom,
        allowedExtensions: ['VCT', 'vct'],
      );
      if (outputPath == null) return; // cancelled
    }

    setState(() {
      _processing = true;
      _statusText = _strings.statusProcessing;
      _resetResult();
    });

    final result = await crypto.encryptText(
      text,
      pw,
      (msg) {
        if (mounted) setState(() => _statusText = _strings.progressMessage(msg));
      },
      outputPath: outputPath,
    );

    if (!mounted) return;

    setState(() {
      _processing = false;
      if (result.success) {
        _resultText = _strings.noteEncrypted;
        _isError = false;
        _outputPath = result.outputPath;
        _textController.clear();
        _pwController.clear();
        _pw2Controller.clear();
        UsageStats.recordEncrypt(bytes: text.length);
      } else {
        _resultText = _strings.errorMessage(result.error ?? '');
        _isError = true;
      }
      _statusText = _strings.statusReady;
    });
  }

  Future<void> _pickFile() async {
    // Same rationale as the decrypt screen: iOS/Android pickers cannot
    // filter by the unregistered .vct extension.
    final isMobile = Platform.isIOS || Platform.isAndroid;
    final result = await FilePicker.platform.pickFiles(
      type: isMobile ? FileType.any : FileType.custom,
      allowedExtensions: isMobile ? null : ['VCT', 'vct'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.first.path;
        _resetResult();
      });
    }
  }

  Future<void> _decryptNote() async {
    if (_filePath == null) {
      _showSnackBar(_strings.errNotFound, isError: true);
      return;
    }
    if (_dPwController.text.isEmpty) {
      _showSnackBar(_strings.errPwShort, isError: true);
      return;
    }

    setState(() {
      _processing = true;
      _statusText = _strings.statusProcessing;
      _resetResult();
    });

    final result = await crypto.decryptFileToText(
      _filePath!,
      _dPwController.text,
      (msg) {
        if (mounted) setState(() => _statusText = _strings.progressMessage(msg));
      },
    );

    if (!mounted) return;

    // Deniability contract: decoy and duress behave exactly like the
    // decrypt screen - decoy is a normal success, duress reports
    // WRONG_PASSWORD.
    setState(() {
      _processing = false;
      if (result.success) {
        _resultText = _strings.noteDecrypted;
        _isError = false;
        _noteText = result.text;
        _noteName = result.originalName;
        _dPwController.clear();
        UsageStats.recordDecrypt(bytes: result.text?.length ?? 0);
      } else {
        _resultText = _strings.errorMessage(result.error ?? '');
        _isError = true;
      }
      _statusText = _strings.statusReady;
    });
  }

  Future<void> _shareEncrypted() async {
    if (_outputPath == null) return;
    await Share.shareXFiles([XFile(_outputPath!)], text: _strings.appName);
  }

  Future<void> _copyNote() async {
    if (_noteText == null) return;
    await Clipboard.setData(ClipboardData(text: _noteText!));
    if (mounted) _showSnackBar(_strings.genCopied);
  }

  Future<void> _shareNote() async {
    if (_noteText == null) return;
    // Share sheet accepts plain text directly - nothing is written to
    // disk at all.
    await Share.share(_noteText!, subject: _noteName);
  }

  Future<void> _saveNoteAsFile() async {
    if (_noteText == null) return;
    final target = await FilePicker.platform.saveFile(
      fileName: _noteName?.replaceAll('.txt', '') ?? 'note.txt',
    );
    if (target == null) return;
    try {
      final f = File(target);
      f.writeAsStringSync(_noteText!, flush: true);
      if (mounted) _showSnackBar(_strings.noteSavedAs);
    } catch (_) {
      if (mounted) _showSnackBar(_strings.errWrite, isError: true);
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.notesTitle),
        actions: [
          IconButton(
            tooltip: strings.panicLock,
            onPressed: () {
              VCTCryptApp.of(context).panicLock();
              _showSnackBar(strings.panicLocked);
            },
            icon: const Icon(Icons.shield_moon_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _processing
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusText),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.note_add_outlined),
                        label: Text(strings.noteEncrypt),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.lock_open_outlined),
                        label: Text(strings.noteDecrypt),
                      ),
                    ],
                    selected: {_encryptMode},
                    onSelectionChanged: (sel) =>
                        setState(() => _encryptMode = sel.first),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _encryptMode
                          ? _buildEncryptForm(theme, strings)
                          : _buildDecryptForm(theme, strings),
                    ),
                  ),
                  if (_resultText != null) ...[
                    const SizedBox(height: 16),
                    _buildResultCard(theme, strings),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEncryptForm(ThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(strings.noteEncrypt, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(strings.noteHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          maxLines: 7,
          minLines: 4,
          decoration: InputDecoration(
            labelText: strings.noteContentLabel,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwController,
          obscureText: _obscurePw,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: strings.passwordLabel,
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: strings.generatorTitle,
                  icon: const Icon(Icons.casino_outlined),
                  onPressed: () async {
                    final pw = await showPasswordGeneratorSheet(context);
                    if (pw != null && pw.isNotEmpty && mounted) {
                      setState(() {
                        _pwController.text = pw;
                        _pw2Controller.text = pw;
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePw = !_obscurePw),
                ),
              ],
            ),
          ),
        ),
        PasswordStrength(password: _pwController.text),
        const SizedBox(height: 12),
        TextField(
          controller: _pw2Controller,
          obscureText: _obscurePw,
          decoration: InputDecoration(
            labelText: strings.confirmPasswordLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _encryptNote,
            icon: const Icon(Icons.lock_outline),
            label: Text(strings.encryptBtn),
          ),
        ),
      ],
    );
  }

  Widget _buildDecryptForm(ThemeData theme, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_open_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(strings.noteDecrypt, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.folder_open),
          label: Text(
            _filePath == null ? strings.selectVctFile : strings.fileSelected,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dPwController,
          obscureText: _obscureDPw,
          decoration: InputDecoration(
            labelText: strings.passwordLabel,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureDPw ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureDPw = !_obscureDPw),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _decryptNote,
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(strings.navDecrypt),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ThemeData theme, AppStrings strings) {
    final color = _isError ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer;
    final fg = _isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isError ? Icons.error_outline : Icons.check_circle_outline, color: fg),
                const SizedBox(width: 8),
                Expanded(child: Text(_resultText!, style: theme.textTheme.titleMedium?.copyWith(color: fg))),
              ],
            ),
            // ---- encrypt result: where the .VCT went ----
            if (_outputPath != null) ...[
              const SizedBox(height: 8),
              Text(
                Platform.isIOS || Platform.isAndroid
                    ? strings.noteEncryptedMobile
                    : _outputPath!,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
              ),
              if (Platform.isIOS || Platform.isAndroid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _shareEncrypted,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(strings.shareBtn),
                  ),
                ),
              ],
            ],
            // ---- decrypt result: the note text, in memory only ----
            if (_noteText != null) ...[
              if (_noteName != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${strings.infoFileName}: $_noteName',
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _noteText!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _copyNote,
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(strings.genCopy),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _shareNote,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(strings.shareBtn),
                  ),
                  if (!Platform.isIOS && !Platform.isAndroid)
                    OutlinedButton.icon(
                      onPressed: _saveNoteAsFile,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(strings.noteSaveAsFile),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
