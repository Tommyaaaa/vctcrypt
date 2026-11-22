/// VCTCrypt - Password strength indicator (v1.5.0, rebuilt in v2.7.2)
///
/// This is the ONE strength implementation for the whole app: the encrypt
/// screen, the notes screen and the key-generation dialog all call it, so
/// the three screens can no longer disagree about what "medium" means.
///
/// v2.7.2 (audit A-S-5, A-M-16, A-M-27, A-L-21, A-L-22, fix-03) added the
/// three penalties the old pool-only estimate was missing:
///   1. common / leaked passwords (leet-normalised, trailing digits
///      stripped) score 0 bits;
///   2. passwords made of a repeated short unit only get the entropy of
///      that unit ("abcabcabcabc" is not 12 characters of entropy);
///   3. long keyboard / alphabet / digit runs are capped into the weak
///      band ("abcd1234", "qwerty12").
/// Length is now counted in Unicode code points, not UTF-16 code units.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

enum PwQuality { weak, fair, good, strong }

class PasswordStrength extends StatelessWidget {
  final String password;
  const PasswordStrength({super.key, required this.password});

  static const _symbols = r'`~!@#$%^&*()-_=+[]{};:,.<>/?\|"';

  /// Keyboard rows, alphabet and digits, used for sequence detection.
  static const _sequences = [
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    'abcdefghijklmnopqrstuvwxyz',
    '01234567890',
  ];

  /// Passwords that dominate every leaked-password corpus. Matching is
  /// done after lowercasing, leet substitution and dropping trailing
  /// digits, so "P@ssw0rd1" and "password123" are both caught.
  static const _common = {
    'password', 'passwort', 'motdepasse', 'contrasena', 'senha',
    '123456', '123456789', '12345678', '1234567', '1234567890',
    'qwerty', 'qwertyuiop', 'qwerty123', 'azerty', 'azertyuiop',
    'abc123', 'abcd1234', 'abcdef', 'abcdefg', 'abcdefgh',
    'iloveyou', 'admin', 'administrator', 'root', 'welcome',
    'monkey', 'dragon', 'sunshine', 'princess', 'football',
    'baseball', 'superman', 'batman', 'master', 'shadow',
    'letmein', 'trustno1', 'whatever', 'starwars', 'computer',
    '111111', '000000', '666666', '888888', '654321', '123123',
    'asdfgh', 'asdfghjkl', 'zxcvbn', 'zxcvbnm', 'qazwsx',
  };

  /// Leet-normalise and drop everything that is not a letter, so the
  /// blacklist sees the word the user actually meant.
  static String _normalize(String pw) {
    const map = {
      '0': 'o', '1': 'i', '2': 'z', '3': 'e', '4': 'a',
      '5': 's', '6': 'g', '7': 't', '8': 'b', '9': 'g',
      '@': 'a', r'$': 's', '!': 'i', '|': 'l', '+': 't',
    };
    final sb = StringBuffer();
    for (final r in pw.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final mapped = map[ch] ?? ch;
      if (mapped.codeUnitAt(0) >= 0x61 && mapped.codeUnitAt(0) <= 0x7A) {
        sb.write(mapped);
      }
    }
    return sb.toString();
  }

  static bool isCommon(String pw) {
    final raw = pw.toLowerCase();
    if (_common.contains(raw)) return true;
    final n = _normalize(pw);
    if (n.isEmpty) return false;
    if (_common.contains(n)) return true;
    // v2.7.5 (audit N-06): "P@ssw0rd1" normalises to "passwordi" (1 -> i),
    // so an exact match missed it. A known word plus a 1-2 letter tail is
    // still the same leaked password ("password1", "p@ssw0rd$").
    for (final word in _common) {
      if (word.length >= 5 &&
          n.startsWith(word) &&
          n.length - word.length <= 2) {
        return true;
      }
    }
    // A pure digit string has no letters left - check the original too.
    final stripped = raw.replaceAll(RegExp(r'[^a-z]'), '');
    return stripped.isNotEmpty && _common.contains(stripped);
  }

  /// Length of the repeating unit when [pw] is (mostly) a repetition.
  /// "abcabcabcabc" -> 3, "aaaaaaaa1" -> 1, "abcd" -> null.
  ///
  /// v2.7.5 (audit N-08): the old version required an exact full-string
  /// repetition, so one different trailing character ("aaaaaaaa1") escaped
  /// and scored 46.5 bits. Coverage of at least 80% now counts.
  static int? repeatedUnitLength(List<int> runes) {
    final n = runes.length;
    if (n < 3) return null;
    for (var p = 1; p <= n ~/ 3 && p <= 8; p++) {
      var reps = 0;
      for (var i = 0; i + p <= n; i += p) {
        var ok = true;
        for (var j = 0; j < p; j++) {
          if (runes[i + j] != runes[j]) {
            ok = false;
            break;
          }
        }
        if (!ok) break;
        reps++;
      }
      if (reps >= 3 && reps * p * 5 >= n * 4) return p;
    }
    return null;
  }

  /// True when a keyboard / alphabet / digit run covers at least half of
  /// the password and is at least four characters long.
  static bool hasLongSequence(List<int> runes) {
    final s = String.fromCharCodes(runes).toLowerCase();
    if (s.length < 4) return false;
    var best = 0;
    for (final row in _sequences) {
      for (var i = 0; i < s.length; i++) {
        var len = 0;
        var j = i;
        var k = row.indexOf(s[j]);
        while (j < s.length && k >= 0) {
          len++;
          j++;
          if (j >= s.length) break;
          final nk = row.indexOf(s[j]);
          if (nk != k + 1 && nk != k - 1) break;
          k = nk;
        }
        if (len > best) best = len;
      }
    }
    return best >= 4 && best * 2 >= runes.length;
  }

  static double estimateBits(String pw) {
    final runes = pw.runes.toList();
    if (runes.isEmpty) return 0;
    if (isCommon(pw)) return 0;

    var pool = 0;
    final hasUpper = runes.any((r) => r >= 0x41 && r <= 0x5A);
    final hasLower = runes.any((r) => r >= 0x61 && r <= 0x7A);
    final hasDigit = runes.any((r) => r >= 0x30 && r <= 0x39);
    final hasSymbol = runes.any((r) =>
        _symbols.codeUnits.contains(r) &&
        !(r >= 0x30 && r <= 0x39) &&
        !(r >= 0x41 && r <= 0x5A) &&
        !(r >= 0x61 && r <= 0x7A));
    final hasUnicode = runes.any((r) => r > 0x7E);
    if (hasUpper) pool += 26;
    if (hasLower) pool += 26;
    if (hasDigit) pool += 10;
    if (hasSymbol) pool += 30;
    if (hasUnicode) pool += 100;
    if (pool == 0) pool = 26;

    final unit = repeatedUnitLength(runes);
    final length = unit ?? runes.length;
    var bits = length * (math.log(pool) / math.log(2));

    if (hasLongSequence(runes)) bits = math.min(bits, 35);
    return bits;
  }

  static PwQuality qualityOf(double bits) {
    if (bits < 40) return PwQuality.weak;
    if (bits < 60) return PwQuality.fair;
    if (bits < 80) return PwQuality.good;
    return PwQuality.strong;
  }

  static PwQuality quality(String pw) => qualityOf(estimateBits(pw));

  static String label(AppStrings strings, PwQuality q) => switch (q) {
        PwQuality.weak => strings.passwordStrengthWeak,
        PwQuality.fair => strings.passwordStrengthMedium,
        PwQuality.good => strings.strengthGood,
        PwQuality.strong => strings.passwordStrengthStrong,
      };

  static Color color(ThemeData theme, PwQuality q) => switch (q) {
        PwQuality.weak => theme.colorScheme.error,
        PwQuality.fair => Colors.orange.shade700,
        PwQuality.good => theme.colorScheme.tertiary,
        PwQuality.strong => theme.colorScheme.primary,
      };

  static double ratioFor(PwQuality q) => switch (q) {
        PwQuality.weak => 0.2,
        PwQuality.fair => 0.45,
        PwQuality.good => 0.7,
        PwQuality.strong => 1.0,
      };

  /// One decimal is enough for a live display; the old code printed raw
  /// doubles like "57.123456789".
  static String formatBits(double bits) => bits.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final bits = estimateBits(password);
    final q = qualityOf(bits);
    final c = color(theme, q);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratioFor(q),
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: c,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${strings.strengthLabel}: ${label(strings, q)} '
          '(${formatBits(bits)}${strings.strengthBits})',
          style: theme.textTheme.bodySmall?.copyWith(color: c),
        ),
      ],
    );
  }
}
