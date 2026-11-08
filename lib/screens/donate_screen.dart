/// VCTCrypt - Donate Screen (v2.0.0)
/// Alipay QR code: "VCTCrypt is free, open-source and ad-free -
/// donate to support development."
///
/// The QR image ships inside the app bundle (assets/donate_alipay.png).
/// Nothing is fetched from the network; the share button just exports
/// the bundled image via the system sheet so it can be printed /
/// forwarded. Money never touches VCTCrypt - the payment itself
/// happens entirely inside Alipay.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../i18n/strings.dart';
import '../main.dart';
import '../platform/vfs.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const _asset = 'assets/donate_alipay.png';

  /// Export the bundled QR image. Browser builds download it directly;
  /// mobile builds open the system share/save sheet.
  Future<void> _shareQr(AppStrings strings) async {
    try {
      final data = await rootBundle.load(_asset);
      final bytes = Uint8List.view(data.buffer);
      if (isWebPlatform) {
        await saveBytes('VCTCrypt-Donate-QR.png', bytes);
        return;
      }
      final tmp = tempPath(
        'vctcrypt_donate_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      writeBytes(tmp, bytes);
      await Share.shareXFiles([XFile(tmp)], text: strings.appName);
    } catch (_) {
      // Share sheet unavailable (desktop edge cases) - silently ignore;
      // the QR is still visible on screen for direct scanning.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final isMobile = isMobileApp;

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

                // ---- Share / download the QR image ----
                if (isMobile || isWebPlatform)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _shareQr(strings),
                      icon: Icon(isWebPlatform
                          ? Icons.download_outlined
                          : Icons.share_outlined),
                      label: Text(isWebPlatform
                          ? strings.downloadBtn
                          : strings.donateShareQr),
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
