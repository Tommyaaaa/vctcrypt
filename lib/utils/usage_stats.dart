/// VCTCrypt - Usage Statistics (v1.2.0)
/// Local-only counters stored in SharedPreferences. Nothing is ever
/// uploaded anywhere - the numbers only live on this device.
///
/// Note: counters never record file names, passwords or paths - only
/// aggregate numbers, so statistics themselves leak no secrets.
///
/// v2.7.1 (audit N-01): the decoy / duress / shred counters are gone
/// entirely. They were write-only since v2.5.0 (never displayed), and on
/// the web SharedPreferences is plaintext localStorage that any
/// same-origin script can read - a "duressFired" key there hands an
/// observer exactly the fact deniability is supposed to hide.

import 'package:shared_preferences/shared_preferences.dart';

class UsageStats {
  /// Legacy keys written by 2.5.0 - 2.7.0. Scrubbed on every platform at
  /// startup so an upgrade erases the trace instead of keeping it forever.
  static const _legacyDeniabilityKeys = [
    'stat.decoy',
    'stat.duressArmed',
    'stat.duressFired',
    'stat.shredded',
  ];

  final int filesEncrypted;
  final int filesDecrypted;
  final int bytesEncrypted;
  final int bytesDecrypted;

  const UsageStats({
    this.filesEncrypted = 0,
    this.filesDecrypted = 0,
    this.bytesEncrypted = 0,
    this.bytesDecrypted = 0,
  });

  bool get isEmpty =>
      filesEncrypted == 0 && filesDecrypted == 0 && bytesEncrypted == 0;

  static UsageStats _read(SharedPreferences prefs) => UsageStats(
        filesEncrypted: prefs.getInt('stat.enc') ?? 0,
        filesDecrypted: prefs.getInt('stat.dec') ?? 0,
        bytesEncrypted: prefs.getInt('stat.encBytes') ?? 0,
        bytesDecrypted: prefs.getInt('stat.decBytes') ?? 0,
      );

  /// Delete deniability counters left behind by older releases. Called
  /// once at startup and again on every read.
  static Future<void> scrubLegacyDeniability([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    for (final k in _legacyDeniabilityKeys) {
      if (p.containsKey(k)) await p.remove(k);
    }
  }

  /// Load current statistics.
  static Future<UsageStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    await scrubLegacyDeniability(prefs);
    return _read(prefs);
  }

  /// Record one successful encryption.
  static Future<void> recordEncrypt({required int bytes}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('stat.enc', (prefs.getInt('stat.enc') ?? 0) + 1),
      prefs.setInt(
          'stat.encBytes', (prefs.getInt('stat.encBytes') ?? 0) + bytes),
    ]);
  }

  /// Record one successful decryption.
  static Future<void> recordDecrypt({required int bytes}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('stat.dec', (prefs.getInt('stat.dec') ?? 0) + 1),
      prefs.setInt(
          'stat.decBytes', (prefs.getInt('stat.decBytes') ?? 0) + bytes),
    ]);
  }

  /// Reset all counters to zero.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      for (final k in [
        'stat.enc',
        'stat.dec',
        'stat.encBytes',
        'stat.decBytes',
        ..._legacyDeniabilityKeys,
      ])
        prefs.remove(k),
    ]);
  }

  /// Human-readable byte size (matches the screens' formatter).
  static String formatBytes(int bytes, String bytesUnit) {
    if (bytes < 1024) return '$bytes $bytesUnit';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}
