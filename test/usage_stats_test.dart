import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vctcrypt/utils/usage_stats.dart';

/// v2.7.1 (audit N-01 / N-03): guards the regression that put deniability
/// counters into readable storage. A duress hit must leave no trace, and
/// counters left behind by 2.5.0 - 2.7.0 must be scrubbed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy decoy/duress counters are scrubbed on load', () async {
    SharedPreferences.setMockInitialValues({
      'stat.decoy': 3,
      'stat.duressArmed': 1,
      'stat.duressFired': 9,
      'stat.shredded': 2,
      'stat.dec': 4,
    });

    final stats = await UsageStats.load();

    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'stat.decoy',
      'stat.duressArmed',
      'stat.duressFired',
      'stat.shredded',
    ]) {
      expect(prefs.containsKey(k), isFalse, reason: '$k must be removed');
    }
    // Harmless aggregate counters survive.
    expect(stats.filesDecrypted, 4);
  });

  test('recording encrypt/decrypt never creates deniability keys', () async {
    SharedPreferences.setMockInitialValues({});

    await UsageStats.recordEncrypt(bytes: 1024);
    await UsageStats.recordDecrypt(bytes: 2048);

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    expect(keys, contains('stat.enc'));
    expect(keys, contains('stat.dec'));
    for (final k in keys) {
      expect(
        k.startsWith('stat.decoy') ||
            k.startsWith('stat.duress') ||
            k.startsWith('stat.shredded'),
        isFalse,
        reason: 'deniability counter leaked: $k',
      );
    }
  });

  test('reset clears every counter, including legacy ones', () async {
    SharedPreferences.setMockInitialValues({
      'stat.enc': 2,
      'stat.dec': 3,
      'stat.encBytes': 10,
      'stat.decBytes': 20,
      'stat.duressFired': 5,
    });

    await UsageStats.reset();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
