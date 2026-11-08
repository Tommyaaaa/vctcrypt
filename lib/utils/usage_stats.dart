/// VCTCrypt - Usage Statistics (v1.2.0)
/// Local-only counters stored in SharedPreferences. Nothing is ever
/// uploaded anywhere - the numbers only live on this device.
///
/// Note: counters never record file names, passwords or paths - only
/// aggregate numbers, so statistics themselves leak no secrets.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class UsageStats {
  /// Counters that reveal whether a decoy partition or duress password
  /// exists. On native builds SharedPreferences lives in the app sandbox,
  /// but on the web it is plaintext `localStorage` that any same-origin
  /// script (or anyone with the browser profile) can read. Persisting
  /// these there would hand an observer exactly the fact deniability is
  /// supposed to hide, so web builds never write them.
  static const _deniabilityKeys = [
    'stat.decoy',
    'stat.duressArmed',
    'stat.duressFired',
  ];

  final int filesEncrypted;
  final int filesDecrypted;
  final int bytesEncrypted;
  final int bytesDecrypted;
  final int decoyPartitions;
  final int duressArmed;
  final int duressTriggered;
  final int filesShredded;

  const UsageStats({
    this.filesEncrypted = 0,
    this.filesDecrypted = 0,
    this.bytesEncrypted = 0,
    this.bytesDecrypted = 0,
    this.decoyPartitions = 0,
    this.duressArmed = 0,
    this.duressTriggered = 0,
    this.filesShredded = 0,
  });

  bool get isEmpty =>
      filesEncrypted == 0 &&
      filesDecrypted == 0 &&
      decoyPartitions == 0 &&
      duressArmed == 0 &&
      duressTriggered == 0 &&
      filesShredded == 0;

  static UsageStats _read(SharedPreferences prefs) => UsageStats(
        filesEncrypted: prefs.getInt('stat.enc') ?? 0,
        filesDecrypted: prefs.getInt('stat.dec') ?? 0,
        bytesEncrypted: prefs.getInt('stat.encBytes') ?? 0,
        bytesDecrypted: prefs.getInt('stat.decBytes') ?? 0,
        decoyPartitions: prefs.getInt('stat.decoy') ?? 0,
        duressArmed: prefs.getInt('stat.duressArmed') ?? 0,
        duressTriggered: prefs.getInt('stat.duressFired') ?? 0,
        filesShredded: prefs.getInt('stat.shredded') ?? 0,
      );

  /// Remove deniability counters from the web build's plaintext storage.
  /// Native builds keep them (private app sandbox); the web scrubs values
  /// written by older builds, right after startup and on every read.
  static Future<void> scrubWebDeniability([SharedPreferences? prefs]) async {
    if (!kIsWeb) return;
    final p = prefs ?? await SharedPreferences.getInstance();
    for (final k in _deniabilityKeys) {
      if (p.containsKey(k)) await p.remove(k);
    }
  }

  /// Load current statistics.
  static Future<UsageStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    await scrubWebDeniability(prefs);
    return _read(prefs);
  }

  /// Record one successful encryption.
  static Future<void> recordEncrypt({
    required int bytes,
    bool decoy = false,
    bool duress = false,
    bool shredded = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('stat.enc', (prefs.getInt('stat.enc') ?? 0) + 1),
      prefs.setInt(
          'stat.encBytes', (prefs.getInt('stat.encBytes') ?? 0) + bytes),
      if (decoy && !kIsWeb)
        prefs.setInt('stat.decoy', (prefs.getInt('stat.decoy') ?? 0) + 1),
      if (duress && !kIsWeb)
        prefs.setInt(
            'stat.duressArmed', (prefs.getInt('stat.duressArmed') ?? 0) + 1),
      if (shredded)
        prefs.setInt(
            'stat.shredded', (prefs.getInt('stat.shredded') ?? 0) + 1),
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

  /// Record a duress wipe being triggered (the file was destroyed).
  /// Never persisted on the web - see [_deniabilityKeys].
  static Future<void> recordDuressTrigger() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'stat.duressFired', (prefs.getInt('stat.duressFired') ?? 0) + 1);
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
        'stat.decoy',
        'stat.duressArmed',
        'stat.duressFired',
        'stat.shredded',
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
