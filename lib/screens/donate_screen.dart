/// VCTCrypt - Donate Screen (v2.0.0)
/// Alipay QR code: "VCTCrypt is free, open-source and ad-free -
/// donate to support development."
///
/// The QR image ships inside the app bundle (assets/donate_alipay.png).
/// Nothing is fetched from the network; the share button just exports
/// the bundled image via the system sheet so it can be printed /
/// forwarded. Money never touches VCTCrypt - the payment itself
/// happens entirely inside Alipay.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/strings.dart';
import '../main.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const _asset = 'assets/donate_alipay.png';

  /// Copy the bundled QR image to a temp file and open the system
  /// share/save sheet (the guaranteed way to get it out on mobile).
  Future<void> _shareQr(AppStrings strings) async {
    try {
      final data = await rootBundle.load(_asset);
      final bytes = Uint8List.view(data.buffer);
      final dir = await getTemporaryDirectory();
      final tmp = File(p.join(
        dir.path,
        'vctcrypt_donate_${DateTime.now().millisecondsSinceEpoch}.png',
      ));
      await tmp.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(tmp.path)], text: strings.appName);
    } catch (_) {
      // Share sheet unavailable (desktop edge cases) - silently ignore;
      // the QR is still visible on screen for direct scanning.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final isMobile =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: Text(strings.donateTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ---- Intro: why donate ----
                Text(
                  strings.donateIntro,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Alipay QR code ----
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // White plate keeps the QR scannable in
                        // dark themes (surrounding color can bleed
                        // into scanners' quiet-zone detection).
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              _asset,
                              width: 280,
                              height: 280,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              semanticLabel: strings.donateQrLabel,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              strings.donateScanHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Optional thank-you note ----
                Text(
                  strings.donateThanks,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Share / save the QR image ----
                if (isMobile)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _shareQr(strings),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(strings.donateShareQr),
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
}
