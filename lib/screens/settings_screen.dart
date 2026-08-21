/// VCTCrypt - Settings Screen
/// Language, Theme, Security, Usage Statistics, About

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';
import '../utils/usage_stats.dart';
import '../widgets/onboarding.dart';
import 'help_screen.dart';

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
                const SizedBox(height: 16),
                // v1.3.0: accent (seed) color picker
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.colorize,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.accentColorLabel,
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.accentColorHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final c in _kSeedColors)
                              _SeedSwatch(
                                color: c,
                                selected:
                                    (appState.seedColor ?? _defaultSeed)
                                        .value ==
                                        c.value,
                                onTap: (_) => appState.setSeedColor(c),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

                // ---- Usage statistics (v1.2.0) ----
                _SectionHeader(
                  icon: Icons.bar_chart,
                  title: strings.statsSection,
                ),
                const SizedBox(height: 12),
                _StatsCard(strings: strings),
                const SizedBox(height: 32),

                // ---- Personalization (v1.3.0) ----
                _SectionHeader(
                  icon: Icons.tune,
                  title: strings.behaviorSection,
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
                              Icons.start,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.startPageLabel,
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.startPageHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < 4; i++)
                              ChoiceChip(
                                label: Text(i == 0
                                    ? strings.navEncrypt
                                    : i == 1
                                        ? strings.navDecrypt
                                        : i == 2
                                            ? strings.navNotes
                                            : strings.navSettings),
                                selected: appState.startTab == i,
                                onSelected: (_) => appState.setStartTab(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                              Icons.content_paste,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              strings.clipboardClearLabel,
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.clipboardClearHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final seconds in const [-1, 15, 30, 60])
                              ChoiceChip(
                                label: seconds < 0
                                    ? Text(strings.autoLockOff)
                                    : Text(strings.clipSeconds(seconds)),
                                selected:
                                    appState.clipboardClearSeconds == seconds,
                                onSelected: (_) =>
                                    appState.setClipboardClearSeconds(seconds),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ---- Guide & help (v1.3.0) ----
                _SectionHeader(
                  icon: Icons.school,
                  title: strings.guideSection,
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.replay,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(strings.showOnboardingBtn),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showOnboarding(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.menu_book_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(strings.helpTitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const HelpScreen()),
                        ),
                      ),
                    ],
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

/// v1.3.0: selectable accent (seed) colors.
const Color _defaultSeed = Color(0xFF4A148C);
const List<Color> _kSeedColors = [
  Color(0xFF4A148C), // deep purple (default)
  Color(0xFF1A237E), // indigo
  Color(0xFF01579B), // blue
  Color(0xFF00695C), // teal
  Color(0xFF1B5E20), // green
  Color(0xFFE65100), // orange
  Color(0xFF8D6E63), // brown
  Color(0xFFAD1457), // pink
];

/// v1.3.0: one circular color swatch in the accent color picker.
class _SeedSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final ValueChanged<Color> onTap;

  const _SeedSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(color),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

/// v1.2.0: local usage statistics card. Loads counters from
/// SharedPreferences and renders them with a reset action.
class _StatsCard extends StatefulWidget {
  final AppStrings strings;

  const _StatsCard({required this.strings});

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  UsageStats? _stats;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final stats = await UsageStats.load();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _confirmReset() async {
    final theme = Theme.of(context);
    final strings = widget.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.statsResetConfirmTitle),
        content: Text(strings.statsResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.statsReset),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await UsageStats.reset();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    final stats = _stats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stats == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (stats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  strings.statsEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              _StatRow(
                icon: Icons.lock,
                label: strings.statsEncrypted,
                value: '${stats.filesEncrypted}',
              ),
              _StatRow(
                icon: Icons.lock_open,
                label: strings.statsDecrypted,
                value: '${stats.filesDecrypted}',
              ),
              _StatRow(
                icon: Icons.cloud_upload_outlined,
                label: strings.statsDataEnc,
                value: UsageStats.formatBytes(
                    stats.bytesEncrypted, strings.bytes),
              ),
              _StatRow(
                icon: Icons.cloud_download_outlined,
                label: strings.statsDataDec,
                value: UsageStats.formatBytes(
                    stats.bytesDecrypted, strings.bytes),
              ),
              if (stats.decoyPartitions > 0)
                _StatRow(
                  icon: Icons.theater_comedy,
                  label: strings.statsDecoy,
                  value: '${stats.decoyPartitions}',
                ),
              if (stats.duressArmed > 0)
                _StatRow(
                  icon: Icons.local_fire_department_outlined,
                  label: strings.statsDuressArmed,
                  value: '${stats.duressArmed}',
                ),
              if (stats.duressTriggered > 0)
                _StatRow(
                  icon: Icons.local_fire_department,
                  label: strings.statsDuressTriggered,
                  value: '${stats.duressTriggered}',
                  highlight: true,
                ),
              if (stats.filesShredded > 0)
                _StatRow(
                  icon: Icons.delete_forever_outlined,
                  label: strings.statsShredded,
                  value: '${stats.filesShredded}',
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _confirmReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(strings.statsReset),
                ),
              ),
            ],
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.statsPrivacyNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One label/value row inside the statistics card.
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
