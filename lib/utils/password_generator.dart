/// VCTCrypt - Password Generator (v1.2.0)
/// Cryptographically secure password generation with entropy estimation.
///
/// Uses Random.secure() (OS CSPRNG), guarantees at least one character
/// from every selected class, and estimates entropy as
/// length * log2(pool size).

import 'dart:math' show Random, log;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';
import '../main.dart';

const _kUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _kLower = 'abcdefghijklmnopqrstuvwxyz';
const _kDigits = '0123456789';
const _kSymbols = '!@#\$%^&*()-_=+[]{};:,.<>?/~';

/// Characters that are easy to confuse when read/typed by humans.
const _kAmbiguous = '0O1lI|`\'';

class PasswordGenerator {
  final Random _rng = Random.secure();

  /// Generate a password. Returns '' if no character class is selected.
  String generate({
    required int length,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
    bool excludeAmbiguous = false,
  }) {
    var pools = <String>[
      if (upper) _kUpper,
      if (lower) _kLower,
      if (digits) _kDigits,
      if (symbols) _kSymbols,
    ];
    if (pools.isEmpty) return '';

    if (excludeAmbiguous) {
      pools = pools
          .map((s) => s
              .split('')
              .where((c) => !_kAmbiguous.contains(c))
              .join())
          .where((s) => s.isNotEmpty)
          .toList();
      if (pools.isEmpty) return '';
    }

    final combined = pools.join();

    // Guarantee at least one character from each selected class.
    final chars = <String>[
      for (final pool in pools) pool[_rng.nextInt(pool.length)],
    ];
    while (chars.length < length) {
      chars.add(combined[_rng.nextInt(combined.length)]);
    }

    // Fisher-Yates shuffle (unbiased).
    for (var i = chars.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = chars[i];
      chars[i] = chars[j];
      chars[j] = tmp;
    }
    return chars.join();
  }

  /// Entropy in bits for [password] generated from a pool of [poolSize]
  /// characters.
  static double entropyBits(int length, int poolSize) {
    if (length <= 0 || poolSize <= 1) return 0;
    return length * (log(poolSize) / log(2));
  }

  /// Combined pool size for the given options (0 if no class selected).
  static int poolSize({
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
    bool excludeAmbiguous = false,
  }) {
    var pools = <String>[
      if (upper) _kUpper,
      if (lower) _kLower,
      if (digits) _kDigits,
      if (symbols) _kSymbols,
    ];
    if (excludeAmbiguous) {
      pools = pools
          .map((s) => s
              .split('')
              .where((c) => !_kAmbiguous.contains(c))
              .join())
          .toList();
    }
    return pools.fold<int>(0, (acc, s) => acc + s.length);
  }
}

/// Entropy quality buckets for the strength meter.
enum PwQuality { empty, weak, fair, strong, excellent }

PwQuality qualityFor(double bits) {
  if (bits <= 0) return PwQuality.empty;
  if (bits < 36) return PwQuality.weak;
  if (bits < 60) return PwQuality.fair;
  if (bits < 90) return PwQuality.strong;
  return PwQuality.excellent;
}

/// Show the password generator as a modal bottom sheet.
///
/// Returns the generated password when the user taps "Use", or null when
/// dismissed.
Future<String?> showPasswordGeneratorSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _GeneratorSheet(),
  );
}

class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet();

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  final _generator = PasswordGenerator();
  final _controller = TextEditingController();

  double _length = 20;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  bool _excludeAmbiguous = false;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _regenerate() {
    final pw = _generator.generate(
      length: _length.round(),
      upper: _upper,
      lower: _lower,
      digits: _digits,
      symbols: _symbols,
      excludeAmbiguous: _excludeAmbiguous,
    );
    _controller.text = pw;
    _controller.selection = TextSelection.collapsed(offset: pw.length);
  }

  bool get _anyClass => _upper || _lower || _digits || _symbols;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;

    final pool = PasswordGenerator.poolSize(
      upper: _upper,
      lower: _lower,
      digits: _digits,
      symbols: _symbols,
      excludeAmbiguous: _excludeAmbiguous,
    );
    final bits = PasswordGenerator.entropyBits(_length.round(), pool);
    final quality = qualityFor(bits);

    final qualityLabel = switch (quality) {
      PwQuality.empty => strings.genNoClassError,
      PwQuality.weak => strings.passwordStrengthWeak,
      PwQuality.fair => strings.passwordStrengthMedium,
      PwQuality.strong => strings.passwordStrengthStrong,
      PwQuality.excellent => strings.genQualityExcellent,
    };
    final qualityColor = switch (quality) {
      PwQuality.empty => theme.colorScheme.error,
      PwQuality.weak => Colors.red,
      PwQuality.fair => Colors.orange,
      PwQuality.strong => Colors.green,
      PwQuality.excellent => const Color(0xFF00BFA5),
    };

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        // Keep the sheet above the on-screen keyboard.
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.casino, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                strings.generatorTitle,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Preview + copy ----
          TextField(
            controller: _controller,
            readOnly: true,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: strings.genCopy,
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.genCopied),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Entropy meter ----
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (bits / 128).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: qualityColor,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strings.genEntropy(bits.round()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                qualityLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: qualityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- Length slider ----
          Row(
            children: [
              Text(strings.genLength, style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${_length.round()}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _length,
            min: 8,
            max: 64,
            divisions: 56,
            label: '${_length.round()}',
            onChanged: (v) {
              setState(() => _length = v);
              _regenerate();
            },
          ),
          const SizedBox(height: 8),

          // ---- Character class chips ----
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('A-Z'),
                selected: _upper,
                onSelected: (v) {
                  setState(() => _upper = v);
                  if (_anyClass) _regenerate();
                },
              ),
              FilterChip(
                label: const Text('a-z'),
                selected: _lower,
                onSelected: (v) {
                  setState(() => _lower = v);
                  if (_anyClass) _regenerate();
                },
              ),
              FilterChip(
                label: const Text('0-9'),
                selected: _digits,
                onSelected: (v) {
                  setState(() => _digits = v);
                  if (_anyClass) _regenerate();
                },
              ),
              FilterChip(
                label: const Text('!@#'),
                selected: _symbols,
                onSelected: (v) {
                  setState(() => _symbols = v);
                  if (_anyClass) _regenerate();
                },
              ),
              FilterChip(
                label: Text(strings.genExcludeAmbiguous),
                selected: _excludeAmbiguous,
                onSelected: (v) {
                  setState(() => _excludeAmbiguous = v);
                  if (_anyClass) _regenerate();
                },
              ),
            ],
          ),
          if (!_anyClass) ...[
            const SizedBox(height: 8),
            Text(
              strings.genNoClassError,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),

          // ---- Actions ----
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _anyClass ? _regenerate : null,
                icon: const Icon(Icons.refresh),
                label: Text(strings.genRegenerate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _anyClass && _controller.text.isNotEmpty
                      ? () => Navigator.of(context).pop(_controller.text)
                      : null,
                  icon: const Icon(Icons.check),
                  label: Text(strings.genUse),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
