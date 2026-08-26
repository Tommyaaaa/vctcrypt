/// VCTCrypt - Keys Screen (v1.6.0)
/// Manage ML-KEM-768 recipient key pairs:
///   .vctpub  public key  - others encrypt TO you with it
///   .vctkey  private key - password-wrapped, unlocks those files
///
/// Key files are plain files in the user-visible Documents folder so
/// they can be backed up and shared with any file manager. This screen
/// only lists/generates/moves them - no hidden key store, no network.

import 'dart:io' show Directory, File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../crypto/vct_keys.dart' as keys;
import '../i18n/strings.dart';
import '../main.dart';
import 'help_screen.dart';

class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  List<_KeyEntry> _entries = [];
  bool _loading = true;
  String? _dir;

  AppStrings get _strings => VCTCryptApp.of(context).strings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Rescan the Documents folder for .vctpub / .vctkey files.
  Future<void> _reload() async {
    setState(() => _loading = true);
    String dir;
    try {
      dir = await keys.keysDirectory();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final entries = <_KeyEntry>[];
    try {
      final files = Directory(dir).listSync(followLinks: false);
      for (final f in files.whereType<File>()) {
        final ext = p.extension(f.path).toLowerCase();
        if (ext != '.vctpub' && ext != '.vctkey') continue;
        entries.add(_entryFor(f.path, ext == '.vctpub'));
      }
    } catch (_) {/* unreadable dir - show empty */}
    entries.sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _dir = dir;
      _loading = false;
    });
  }

  _KeyEntry _entryFor(String path, bool isPublic) {
    try {
      final bytes = File(path).readAsBytesSync();
      keys.sniffKeyType(bytes); // throws on bad magic/type
      if (isPublic) {
        final pub = keys.VctPublicKey.parse(bytes);
        return _KeyEntry(
          path: path,
          isPublic: true,
          displayName: pub.name,
          fingerprint: pub.fingerprint,
          valid: true,
        );
      }
      // Private: the name is inside the encrypted body; showing the
      // file name is enough (and honest - we cannot read it without
      // the password).
      return _KeyEntry(
        path: path,
        isPublic: false,
        displayName: p.basenameWithoutExtension(path),
        fingerprint: null,
        valid: true,
      );
    } catch (_) {
      return _KeyEntry(
        path: path,
        isPublic: isPublic,
        displayName: p.basename(path),
        fingerprint: null,
        valid: false,
      );
    }
  }

  // ---- Generate ----

  Future<void> _openGenerateDialog() async {
    final strings = _strings;
    final nameCtl = TextEditingController();
    final pwCtl = TextEditingController();
    final pw2Ctl = TextEditingController();
    var obscure = true;
    var working = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !working,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(strings.genKeyBtn),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: strings.keyNameLabel,
                    hintText: strings.keyNameHint,
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(60),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwCtl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: strings.keyPwLabel,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setDialog(() => obscure = !obscure),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(256),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pw2Ctl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: strings.confirmPasswordLabel,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(256),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  strings.keyPwHint,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: working ? null : () => Navigator.of(ctx).pop(),
              child: Text(strings.cancel),
            ),
            FilledButton.icon(
              onPressed: working
                  ? null
                  : () async {
                      final name = nameCtl.text.trim();
                      final pw = pwCtl.text;
                      if (name.isEmpty) {
                        _snackIn(ctx, strings.keyNameLabel, error: true);
                        return;
                      }
                      if (pw.length < 4) {
                        _snackIn(ctx, strings.errPwShort, error: true);
                        return;
                      }
                      if (pw != pw2Ctl.text) {
                        _snackIn(ctx, strings.errPwMismatch, error: true);
                        return;
                      }
                      setDialog(() => working = true);
                      try {
                        await _generate(name, pw);
                      } finally {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }
                    },
              icon: working
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.key),
              label: Text(strings.genKeyBtn),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    pwCtl.dispose();
    pw2Ctl.dispose();
  }

  Future<void> _generate(String name, String password) async {
    final strings = _strings;
    try {
      final dir = await keys.keysDirectory();
      final (pub, priv) = keys.generateKeyPair(name);

      final pubPath = await keys.uniqueKeyPath(dir, name, '.vctpub');
      keys.writeKeyFile(pubPath, pub.serialize());

      final privPath = await keys.uniqueKeyPath(dir, name, '.vctkey');
      final wrapped = await priv.serializeWrapped(password);
      keys.writeKeyFile(privPath, wrapped);

      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.keyGenOkBody(dir))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ---- Import ----

  Future<void> _import() async {
    final strings = _strings;
    // Same picker constraint as .VCT/.vctkey: unknown extensions have
    // no UTI on iOS / MIME on Android, so allow any file there and
    // validate the container magic ourselves.
    final isMobile = Platform.isIOS || Platform.isAndroid;
    final result = await FilePicker.platform.pickFiles(
      type: isMobile ? FileType.any : FileType.custom,
      allowedExtensions: isMobile ? null : ['vctpub', 'vctkey', 'VCTPUB', 'VCTKEY'],
    );
    if (result == null || result.files.isEmpty) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    try {
      final bytes = File(srcPath).readAsBytesSync();
      keys.sniffKeyType(bytes);
      final dir = await keys.keysDirectory();
      final ext = p.extension(srcPath).toLowerCase();
      final extOk = ext == '.vctpub' || ext == '.vctkey';
      final useExt = extOk ? ext : '.vctkey';
      final dest = await keys.uniqueKeyPath(
        dir, p.basenameWithoutExtension(srcPath), useExt);
      keys.writeKeyFile(dest, bytes);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.keyImported}: ${p.basename(dest)}')),
      );
    } on keys.KeyFileException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.errBadKeyFile),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ---- Share / delete ----

  Future<void> _share(_KeyEntry e) async {
    await Share.shareXFiles([XFile(e.path)], text: _strings.appName);
  }

  Future<void> _delete(_KeyEntry e) async {
    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteKeyConfirmTitle),
        content: Text(strings.deleteKeyConfirmBody(p.basename(e.path))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.deleteKeyBtn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      File(e.path).deleteSync();
    } catch (_) {/* already gone */}
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.keyDeleted)),
    );
  }

  void _snackIn(BuildContext ctx, String msg, {bool error = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(ctx).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.keysTitle),
        actions: [
          IconButton(
            tooltip: strings.helpTitle,
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            tooltip: strings.navKeys,
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
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
                  strings.keysSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Intro / how it works
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.key,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.keysIntro,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _openGenerateDialog,
                      icon: const Icon(Icons.key),
                      label: Text(strings.genKeyBtn),
                    ),
                    OutlinedButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.download),
                      label: Text(strings.importKeyBtn),
                    ),
                  ],
                ),
                if (_dir != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dir!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Key list
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      strings.noKeysYet,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _entries.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _keyTile(theme, strings, _entries[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyTile(ThemeData theme, AppStrings strings, _KeyEntry e) {
    return ListTile(
      leading: Icon(
        e.valid
            ? (e.isPublic ? Icons.vpn_key_outlined : Icons.key)
            : Icons.error_outline,
        color: e.valid
            ? (e.isPublic
                ? theme.colorScheme.primary
                : theme.colorScheme.tertiary)
            : theme.colorScheme.error,
      ),
      title: Text(
        e.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        e.valid
            ? (e.isPublic
                ? '${strings.keyTypePublicLabel}\n${strings.keyFingerprint}: ${e.fingerprint} · ${strings.mlkemLabel}'
                : '${strings.keyTypePrivateLabel} · ${strings.mlkemLabel}')
            : '${strings.keyInvalidFile} · ${p.basename(e.path)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: e.valid
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.error,
        ),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: strings.shareBtn,
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () => _share(e),
          ),
          IconButton(
            tooltip: strings.deleteKeyBtn,
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _delete(e),
          ),
        ],
      ),
    );
  }
}

class _KeyEntry {
  final String path;
  final bool isPublic;
  final String displayName;
  final String? fingerprint;
  final bool valid;
  const _KeyEntry({
    required this.path,
    required this.isPublic,
    required this.displayName,
    this.fingerprint,
    required this.valid,
  });
}
