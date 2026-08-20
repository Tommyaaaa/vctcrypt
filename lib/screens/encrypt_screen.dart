/// VCTCrypt - Encrypt Screen
/// File selection + password + triple AES-256-GCM encryption
/// v1.1.0: advanced security options (decoy partition, duress password,
/// secure shred of the original file).

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../crypto/vct_crypto.dart' as crypto;
import '../i18n/strings.dart';
import '../main.dart';
import '../utils/password_generator.dart';
import '../utils/usage_stats.dart';
import '../widgets/file_drop_zone.dart';
import 'help_screen.dart';

class EncryptScreen extends StatefulWidget {
  const EncryptScreen({super.key});

  @override
  State<EncryptScreen> createState() => _EncryptScreenState();
}

class _EncryptScreenState extends State<EncryptScreen> {
  // v1.3.0: batch support - all selected files share one password.
  final List<String> _files = [];
  final _pwController = TextEditingController();
  final _pw2Controller = TextEditingController();
  bool _obscurePw = true;
  bool _obscurePw2 = true;
  bool _processing = false;
  String _statusText = '';
  String? _resultText;
  bool _isError = false;
  String? _outputPath;
  int? _outputSize;
  int _okCount = 0;
  int _failCount = 0;
  int _totalBytes = 0;
  List<String> _failures = [];
  bool _resultDecoy = false;
  bool _resultDuress = false;
  bool _resultShredded = false;

  // ---- Advanced options state ----
  final _decoyPwController = TextEditingController();
  final _decoyPw2Controller = TextEditingController();
  final _duressPwController = TextEditingController();
  final _duressPw2Controller = TextEditingController();
  bool _obscureDecoyPw = true;
  bool _obscureDecoyPw2 = true;
  bool _obscureDuressPw = true;
  bool _obscureDuressPw2 = true;
  String? _decoyFilePath;
  bool _shredOriginal = false;
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
    _pw2Controller.dispose();
    _decoyPwController.dispose();
    _decoyPw2Controller.dispose();
    _duressPwController.dispose();
    _duressPw2Controller.dispose();
    super.dispose();
  }

  /// Auto-lock fired: clear every password field on this screen.
  void _onAutoLock() {
    if (!mounted) return;
    _pwController.clear();
    _pw2Controller.clear();
    _decoyPwController.clear();
    _decoyPw2Controller.clear();
    _duressPwController.clear();
    _duressPw2Controller.clear();
    setState(() {});
  }

  AppStrings get _strings => VCTCryptApp.of(context).strings;

  /// v1.2.0: open the password generator and fill main + confirm fields.
  Future<void> _openGeneratorForMain() async {
    final pw = await showPasswordGeneratorSheet(context);
    if (pw == null || pw.isEmpty || !mounted) return;
    setState(() {
      _pwController.text = pw;
      _pw2Controller.text = pw;
    });
    _showSnackBar(_strings.genApplied);
  }

  /// v1.2.0: open the generator and fill the decoy password fields.
  Future<void> _openGeneratorForDecoy() async {
    final pw = await showPasswordGeneratorSheet(context);
    if (pw == null || pw.isEmpty || !mounted) return;
    setState(() {
      _decoyPwController.text = pw;
      _decoyPw2Controller.text = pw;
    });
    _showSnackBar(_strings.genApplied);
  }

  /// v1.2.0: open the generator and fill the duress password fields.
  Future<void> _openGeneratorForDuress() async {
    final pw = await showPasswordGeneratorSheet(context);
    if (pw == null || pw.isEmpty || !mounted) return;
    setState(() {
      _duressPwController.text = pw;
      _duressPw2Controller.text = pw;
    });
    _showSnackBar(_strings.genApplied);
  }

  /// v1.2.0: panic lock - clear every password field immediately.
  void _panicLock() {
    VCTCryptApp.of(context).panicLock();
    _showSnackBar(_strings.panicLocked);
  }

  Future<void> _pickFile() async {
    // v1.3.0: multi-select for batch encryption.
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      final paths = result.paths.whereType<String>().toList();
      if (paths.isNotEmpty) {
        setState(() {
          _files
            ..clear()
            ..addAll(paths);
          // The decoy partition only supports single-file mode.
          if (paths.length > 1) {
            _decoyPwController.clear();
            _decoyPw2Controller.clear();
            _decoyFilePath = null;
          }
          _resultText = null;
          _failures = [];
        });
      }
    }
  }

  Future<void> _pickDecoyFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _decoyFilePath = result.files.first.path;
        _resultText = null;
      });
    }
  }

  String _passwordStrength(String pw) {
    if (pw.isEmpty) return '';
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    if (pw.contains(RegExp(r'[a-z]'))) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]]'))) score++;
    if (score <= 2) return _strings.passwordStrengthWeak;
    if (score <= 4) return _strings.passwordStrengthMedium;
    return _strings.passwordStrengthStrong;
  }

  Color _strengthColor(String strength) {
    if (strength.isEmpty) return Colors.transparent;
    if (strength == _strings.passwordStrengthWeak) return Colors.red;
    if (strength == _strings.passwordStrengthMedium) return Colors.orange;
    return Colors.green;
  }

  Future<void> _encrypt() async {
    final strings = _strings;
    final mainPw = _pwController.text;
    final decoyPw = _decoyPwController.text;
    final duressPw = _duressPwController.text;

    if (_files.isEmpty) {
      _showSnackBar(strings.errNotFound, isError: true);
      return;
    }
    if (mainPw.length < 4) {
      _showSnackBar(strings.errPwShort, isError: true);
      return;
    }
    if (mainPw != _pw2Controller.text) {
      _showSnackBar(strings.errPwMismatch, isError: true);
      return;
    }

    // ---- Advanced option validation ----
    if (decoyPw.isNotEmpty) {
      // v1.3.0: the decoy partition is single-file only.
      if (_files.length > 1) {
        _showSnackBar(strings.errDecoyBatch, isError: true);
        return;
      }
      if (decoyPw.length < 4) {
        _showSnackBar(strings.errPwShort, isError: true);
        return;
      }
      if (decoyPw != _decoyPw2Controller.text) {
        _showSnackBar(strings.errPwMismatch, isError: true);
        return;
      }
      if (decoyPw == mainPw) {
        _showSnackBar(strings.errDecoyPwIdentical, isError: true);
        return;
      }
      if (_decoyFilePath == null) {
        _showSnackBar(strings.errDecoyFileMissing, isError: true);
        return;
      }
    } else if (_decoyFilePath != null) {
      _showSnackBar(strings.errDecoyPwRequired, isError: true);
      return;
    }

    if (duressPw.isNotEmpty) {
      if (duressPw.length < 4) {
        _showSnackBar(strings.errPwShort, isError: true);
        return;
      }
      if (duressPw != _duressPw2Controller.text) {
        _showSnackBar(strings.errPwMismatch, isError: true);
        return;
      }
      if (duressPw == mainPw || duressPw == decoyPw) {
        _showSnackBar(strings.errDuressPwIdentical, isError: true);
        return;
      }
    }

    setState(() {
      _processing = true;
      _statusText = strings.statusProcessing;
      _resultText = null;
      _isError = false;
    });

    final options = crypto.EncryptOptions(
      decoyPassword: decoyPw.isNotEmpty ? decoyPw : null,
      decoyFilePath: decoyPw.isNotEmpty ? _decoyFilePath : null,
      duressPassword: duressPw.isNotEmpty ? duressPw : null,
      shredOriginal: _shredOriginal,
    );

    // v1.3.0: batch loop - encrypt every selected file in sequence.
    var okCount = 0, failCount = 0, totalBytes = 0;
    final failures = <String>[];
    String? firstError;
    String? singleOutputPath;
    int? singleOutputSize;
    var anyDecoy = false, anyDuress = false, anyShredded = false;

    for (var i = 0; i < _files.length; i++) {
      if (mounted) {
        setState(() =>
            _statusText = strings.batchEncrypting(i + 1, _files.length));
      }
      final result = await crypto.encryptFile(
        _files[i],
        mainPw,
        (msg) {
          if (mounted) {
            setState(() => _statusText = _strings.progressMessage(msg));
          }
        },
        options: options,
      );
      if (result.success) {
        okCount++;
        totalBytes += result.outputSize ?? 0;
        singleOutputPath = result.outputPath;
        singleOutputSize = result.outputSize;
        anyDecoy = anyDecoy || result.usedDecoy;
        anyDuress = anyDuress || result.usedDuress;
        anyShredded = anyShredded || result.shreddedOriginal;
        // v1.2.0: local usage statistics (no names/paths recorded).
        unawaited(UsageStats.recordEncrypt(
          bytes: result.outputSize ?? 0,
          decoy: result.usedDecoy,
          duress: result.usedDuress,
          shredded: result.shreddedOriginal,
        ));
      } else {
        failCount++;
        firstError ??= result.error;
        failures.add(
            '${p.basename(_files[i])} — ${strings.errorMessage(result.error ?? '')}');
      }
    }

    if (!mounted) return;

    setState(() {
      _processing = false;
      _okCount = okCount;
      _failCount = failCount;
      _totalBytes = totalBytes;
      _failures = failures;
      _resultDecoy = anyDecoy;
      _resultDuress = anyDuress;
      _resultShredded = anyShredded;
      _isError = okCount == 0;

      if (okCount == 0) {
        _resultText = strings.errorMessage(firstError ?? '');
      } else if (failCount > 0) {
        _resultText = strings.batchPartial(okCount, failCount);
      } else {
        _resultText = strings.encSuccess;
      }

      if (okCount == _files.length) {
        // Everything succeeded: safe to drop the passwords.
        _pwController.clear();
        _pw2Controller.clear();
        _decoyPwController.clear();
        _decoyPw2Controller.clear();
        _duressPwController.clear();
        _duressPw2Controller.clear();
        _outputPath = okCount == 1 ? singleOutputPath : null;
        _outputSize = okCount == 1 ? singleOutputSize : totalBytes;
      } else {
        // Keep the password so the user can retry the failed files.
        _outputPath = null;
        _outputSize = null;
      }
      _statusText = strings.statusReady;
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
    final pwStrength = _passwordStrength(_pwController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.encryptTitle),
        actions: [
          // v1.3.0: help & usage
          IconButton(
            tooltip: strings.helpTitle,
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          // v1.2.0: panic lock - wipe all entered passwords at once
          IconButton(
            tooltip: strings.panicLock,
            icon: const Icon(Icons.gpp_maybe_outlined),
            onPressed: _panicLock,
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
                // Subtitle
                Text(
                  strings.encryptSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // File selection (multi-select for batch mode)
                FileSelectionCard(
                  filePath: _files.length == 1 ? _files.first : null,
                  multiLabel: _files.length > 1
                      ? strings.batchSelectedCount(_files.length)
                      : null,
                  hint: strings.selectFile,
                  icon: Icons.upload_file,
                  onTap: _pickFile,
                  onFileDropped: (path) => setState(() {
                    _files
                      ..clear()
                      ..add(path);
                    _resultText = null;
                    _failures = [];
                  }),
                ),
                // v1.3.0: batch file list with per-file removal
                if (_files.length > 1) ...[
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _files.length; i++)
                          ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 22,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              p.basename(_files[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              _files[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                _files.removeAt(i);
                                _resultText = null;
                                _failures = [];
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Password field
                TextField(
                  controller: _pwController,
                  obscureText: _obscurePw,
                  decoration: InputDecoration(
                    labelText: strings.passwordLabel,
                    hintText: strings.passwordHint,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // v1.2.0: password generator
                        IconButton(
                          tooltip: strings.generatorTitle,
                          icon: const Icon(Icons.casino_outlined),
                          onPressed: _openGeneratorForMain,
                        ),
                        IconButton(
                          icon: Icon(_obscurePw
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscurePw = !_obscurePw),
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(256),
                  ],
                ),
                if (pwStrength.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pwStrength == strings.passwordStrengthWeak
                                ? 0.33
                                : pwStrength == strings.passwordStrengthMedium
                                    ? 0.66
                                    : 1.0,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            color: _strengthColor(pwStrength),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        pwStrength,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _strengthColor(pwStrength),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Confirm password
                TextField(
                  controller: _pw2Controller,
                  obscureText: _obscurePw2,
                  decoration: InputDecoration(
                    labelText: strings.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePw2
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePw2 = !_obscurePw2),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(256),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Advanced security options (v1.1.0) ----
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    // Remove the expansion tile's internal vertical padding
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      dense: false,
                      leading: Icon(
                        Icons.enhanced_encryption,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        strings.advancedOptions,
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        strings.advancedOptionsHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        // ---- Decoy partition (single-file mode only) ----
                        if (_files.length > 1)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    strings.batchDecoyDisabled,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          _DecoySection(
                            strings: strings,
                            decoyPwController: _decoyPwController,
                            decoyPw2Controller: _decoyPw2Controller,
                            obscureDecoyPw: _obscureDecoyPw,
                            obscureDecoyPw2: _obscureDecoyPw2,
                            onToggleDecoyPw: () => setState(
                                () => _obscureDecoyPw = !_obscureDecoyPw),
                            onToggleDecoyPw2: () => setState(
                                () => _obscureDecoyPw2 = !_obscureDecoyPw2),
                            decoyFilePath: _decoyFilePath,
                            onPickDecoyFile: _pickDecoyFile,
                            onGenerate: _openGeneratorForDecoy,
                            onChanged: () => setState(() {}),
                          ),
                        const SizedBox(height: 16),

                        // ---- Duress password ----
                        _DuressSection(
                          strings: strings,
                          duressPwController: _duressPwController,
                          duressPw2Controller: _duressPw2Controller,
                          obscureDuressPw: _obscureDuressPw,
                          obscureDuressPw2: _obscureDuressPw2,
                          onToggleDuressPw: () => setState(
                              () => _obscureDuressPw = !_obscureDuressPw),
                          onToggleDuressPw2: () => setState(
                              () => _obscureDuressPw2 = !_obscureDuressPw2),
                          onGenerate: _openGeneratorForDuress,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        // ---- Secure shred ----
                        Card(
                          margin: EdgeInsets.zero,
                          color: theme.colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    strings.shredOption,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  value: _shredOriginal,
                                  onChanged: (v) =>
                                      setState(() => _shredOriginal = v),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, right: 4, bottom: 12),
                                  child: Text(
                                    strings.shredHint,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Encrypt button
                FilledButton.icon(
                  onPressed: _processing ? null : _encrypt,
                  icon: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock),
                  label: Text(strings.encryptBtn),
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
                          if (!_isError) ...[
                            const SizedBox(height: 12),
                            // v1.3.0: batch summary or single-file details
                            if (_failCount > 0) ...[
                              Text(
                                strings.batchPartial(_okCount, _failCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${strings.fileSize}: ${_formatSize(_totalBytes)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ] else if (_okCount > 1) ...[
                              Text(
                                strings.batchAllOk(_okCount),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${strings.fileSize}: ${_formatSize(_totalBytes)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ] else if (_outputPath != null) ...[
                              Text(
                                '${strings.outputFile}: $_outputPath',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              if (_outputSize != null)
                                Text(
                                  '${strings.fileSize}: ${_formatSize(_outputSize!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                            ],
                            if (Platform.isIOS || Platform.isAndroid) ...[
                              const SizedBox(height: 8),
                              Text(
                                strings.mobileEncHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (_resultDecoy || _resultDuress || _resultShredded)
                              const SizedBox(height: 8),
                            if (_resultDecoy || _resultDuress || _resultShredded)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (_resultDecoy)
                                    _ResultChip(
                                      icon: Icons.theater_comedy,
                                      label: strings.resultDecoyUsed,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  if (_resultDuress)
                                    _ResultChip(
                                      icon: Icons.local_fire_department,
                                      label: strings.resultDuressUsed,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  if (_resultShredded)
                                    _ResultChip(
                                      icon: Icons.delete_forever,
                                      label: strings.resultShredded,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                ],
                              ),
                            // v1.3.0: per-file failure list (partial success)
                            if (_failures.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final f in _failures.take(4))
                                Text(
                                  '• $f',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              if (_failures.length > 4)
                                Text(
                                  '+${_failures.length - 4} …',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                            ],
                          ],
                          // v1.3.0: per-file failure list (total failure)
                          if (_isError && _failures.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final f in _failures.take(4))
                              Text(
                                '• $f',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            if (_failures.length > 4)
                              Text(
                                '+${_failures.length - 4} …',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
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

/// Small labeled chip shown in the success card.
class _ResultChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResultChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decoy partition section: decoy password x2 + decoy file picker.
class _DecoySection extends StatelessWidget {
  final AppStrings strings;
  final TextEditingController decoyPwController;
  final TextEditingController decoyPw2Controller;
  final bool obscureDecoyPw;
  final bool obscureDecoyPw2;
  final VoidCallback onToggleDecoyPw;
  final VoidCallback onToggleDecoyPw2;
  final String? decoyFilePath;
  final VoidCallback onPickDecoyFile;
  final VoidCallback onGenerate;
  final VoidCallback onChanged;

  const _DecoySection({
    required this.strings,
    required this.decoyPwController,
    required this.decoyPw2Controller,
    required this.obscureDecoyPw,
    required this.obscureDecoyPw2,
    required this.onToggleDecoyPw,
    required this.onToggleDecoyPw2,
    required this.decoyFilePath,
    required this.onPickDecoyFile,
    required this.onGenerate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.theater_comedy,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.decoySection,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.decoyPwHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: decoyPwController,
              obscureText: obscureDecoyPw,
              decoration: InputDecoration(
                labelText: strings.decoyPwLabel,
                hintText: strings.optionalHint,
                prefixIcon: const Icon(Icons.theater_comedy),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: strings.generatorTitle,
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: onGenerate,
                    ),
                    IconButton(
                      icon: Icon(obscureDecoyPw
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: onToggleDecoyPw,
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(256),
              ],
            ),
            if (decoyPwController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: decoyPw2Controller,
                obscureText: obscureDecoyPw2,
                decoration: InputDecoration(
                  labelText: strings.confirmPasswordLabel,
                  prefixIcon: const Icon(Icons.theater_comedy),
                  suffixIcon: IconButton(
                    icon: Icon(obscureDecoyPw2
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: onToggleDecoyPw2,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(256),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Decoy file picker row
            Row(
              children: [
                Expanded(
                  child: Text(
                    decoyFilePath != null
                        ? '${strings.decoyFileLabel}: ${p.basename(decoyFilePath!)}'
                        : strings.decoyFileHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: decoyFilePath != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onPickDecoyFile,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    decoyFilePath != null
                        ? strings.browse
                        : strings.decoyFileLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Duress password section: red-tinted warning card.
class _DuressSection extends StatelessWidget {
  final AppStrings strings;
  final TextEditingController duressPwController;
  final TextEditingController duressPw2Controller;
  final bool obscureDuressPw;
  final bool obscureDuressPw2;
  final VoidCallback onToggleDuressPw;
  final VoidCallback onToggleDuressPw2;
  final VoidCallback onGenerate;
  final VoidCallback onChanged;

  const _DuressSection({
    required this.strings,
    required this.duressPwController,
    required this.duressPw2Controller,
    required this.obscureDuressPw,
    required this.obscureDuressPw2,
    required this.onToggleDuressPw,
    required this.onToggleDuressPw2,
    required this.onGenerate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.errorContainer.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.duressSection,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.duressPwHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: duressPwController,
              obscureText: obscureDuressPw,
              decoration: InputDecoration(
                labelText: strings.duressSection,
                hintText: strings.optionalHint,
                prefixIcon: const Icon(Icons.local_fire_department),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: strings.generatorTitle,
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: onGenerate,
                    ),
                    IconButton(
                      icon: Icon(obscureDuressPw
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: onToggleDuressPw,
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(256),
              ],
            ),
            if (duressPwController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextField(
                controller: duressPw2Controller,
                obscureText: obscureDuressPw2,
                decoration: InputDecoration(
                  labelText: strings.confirmPasswordLabel,
                  prefixIcon: const Icon(Icons.local_fire_department),
                  suffixIcon: IconButton(
                    icon: Icon(obscureDuressPw2
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: onToggleDuressPw2,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(256),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
