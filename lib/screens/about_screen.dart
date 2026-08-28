/// VCTCrypt - About Screen (v2.0.0)
/// Icon, name, version, website, author, license. Opened from the
/// Settings tab's "Other" section.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../i18n/strings.dart';
import '../main.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _copyWebsite(BuildContext context, AppStrings strings) async {
    await Clipboard.setData(const ClipboardData(text: _website));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.websiteCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.aboutTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ---- App icon ----
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.shield,
                    size: 56,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),

                // ---- Name + version ----
                Text(
                  strings.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.appVersion} · ${strings.guiVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                // ---- Facts card ----
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Website (tap to copy)
                      ListTile(
                        leading: Icon(
                          Icons.language,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(strings.aboutWebsite),
                        subtitle: Text(
                          _website,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: strings.copyBtn,
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyWebsite(context, strings),
                        ),
                        onTap: () => _copyWebsite(context, strings),
                      ),
                      const Divider(height: 1),
                      // Author
                      ListTile(
                        leading: Icon(
                          Icons.person_outline,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(strings.aboutAuthor),
                        subtitle: Text(
                          strings.author,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // License
                      ListTile(
                        leading: Icon(
                          Icons.gavel_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(strings.aboutLicense),
                        subtitle: Text(
                          strings.aboutLicenseValue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Algorithm summary ----
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.memory,
                              size: 20,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.aboutAlgo,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color:
                                    theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.aboutAlgoValue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Local-only note ----
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.aboutLocalNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
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

const _website = 'https://vctcrypt.pages.dev/';
