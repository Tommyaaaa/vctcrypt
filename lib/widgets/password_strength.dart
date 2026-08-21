/// VCTCrypt - Password strength indicator (v1.5.0)
///
/// Live entropy estimate for a manually typed password. Offline, pure
/// arithmetic: pool size from the character classes actually used,
/// bits = length * log2(pool). Mirrors the estimate in the generator.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

enum _Quality { weak, fair, good, strong }

class PasswordStrength extends StatelessWidget {
  final String password;
  const PasswordStrength({super.key, required this.password});

  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _digits = '0123456789';
  static const _symbols = r'`~!@#$%^&*()-_=+[]{};:,.<>/?\|"';

  static double estimateBits(String pw) {
    if (pw.isEmpty) return 0;
    var pool = 0;
    if (pw.split('').any(_upper.contains)) pool += 26;
    if (pw.split('').any(_lower.contains)) pool += 26;
    if (pw.split('').any(_digits.contains)) pool += 10;
    if (pw.split('').any(_symbols.contains)) pool += 30;
    if (pw.runes.any((r) => r > 127)) pool += 100; // CJK / unicode
    if (pool == 0) pool = 26;
    return pw.length * (math.log(pool) / math.log(2));
  }

  static _Quality quality(double bits) {
    if (bits < 40) return _Quality.weak;
    if (bits < 60) return _Quality.fair;
    if (bits < 80) return _Quality.good;
    return _Quality.strong;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final bits = estimateBits(password);
    final q = quality(bits);

    final (label, color, ratio) = switch (q) {
      _Quality.weak => (strings.passwordStrengthWeak, theme.colorScheme.error, 0.2),
      _Quality.fair => (strings.passwordStrengthMedium, Colors.orange.shade700, 0.45),
      _Quality.good => (strings.strengthGood, theme.colorScheme.tertiary, 0.7),
      _Quality.strong => (strings.passwordStrengthStrong, theme.colorScheme.primary, 1.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${strings.strengthLabel}: $label ($bits${strings.strengthBits})',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
