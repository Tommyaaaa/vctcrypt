/// VCTCrypt - Settings Screen
/// Language, Theme, About

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  final AppStrings strings;

  const SettingsScreen({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    final appState = VCTCryptApp.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Language ----
                _SectionHeader(
                  icon: Icons.language,
                  title: strings.languageSection,
                ),
                const SizedBox(height: 12),
                SegmentedButton<AppLanguage>(
                  segments: [
                    ButtonSegment(
                      value: AppLanguage.english,
                      icon: const Text('EN'),
                      label: Text('English'),
                    ),
                    ButtonSegment(
                      value: AppLanguage.chinese,
                      icon: const Text('中'),
                      label: Text('中文'),
                    ),
                  ],
                  selected: {appState.lang},
                  onSelectionChanged: (selected) {
                    appState.changeLanguage(selected.first);
                  },
                ),
                const SizedBox(height: 32),

                // ---- Theme ----
                _SectionHeader(
                  icon: Icons.palette_outlined,
                  title: strings.themeSection,
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(strings.themeLight),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(strings.themeDark),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: const Icon(Icons.auto_mode),
                      label: Text(strings.themeSystem),
                    ),
                  ],
                  selected: {appState.themeIndex},
                  onSelectionChanged: (selected) {
                    appState.changeTheme(selected.first);
                  },
                ),
                const SizedBox(height: 32),

                // ---- Security / Auto-lock (v1.1.0) ----
                _SectionHeader(
                  icon: Icons.security,
                  title: strings.securitySection,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.autoLockLabel,
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.autoLockHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final minutes in const [-1, 1, 5, 10, 30])
                              ChoiceChip(
                                label: minutes < 0
                                    ? Text(strings.autoLockOff)
                                    : Text(strings.autoLockMinutes(minutes)),
                                selected: appState.autoLockMinutes == minutes,
                                onSelected: (_) =>
                                    appState.setAutoLockMinutes(minutes),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ---- About ----
                _SectionHeader(
                  icon: Icons.info_outline,
                  title: strings.aboutSection,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // App icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.shield,
                            size: 40,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.appName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.appVersion,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.guiVersion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // What's new in this version
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            strings.whatsNew,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Divider(height: 32),
                        _InfoRow(
                          label: strings.aboutAuthor,
                          value: strings.author,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: strings.aboutAlgo,
                          value: strings.aboutAlgoValue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security note
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.lang == AppLanguage.english
                                ? 'All encryption runs locally. No data is transmitted.'
                                : '所有加密均在本地执行，不传输任何数据。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
