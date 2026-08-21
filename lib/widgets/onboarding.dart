/// VCTCrypt - First-launch onboarding (v1.3.0)
/// A short 4-page guide covering the security model, everyday tools
/// and personalization. Shown once on first launch; replayable from
/// Settings.

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

/// Show the onboarding dialog. [firstLaunch] disables tap-outside
/// dismissal so the guide cannot be lost accidentally on first run.
Future<void> showOnboarding(
  BuildContext context, {
  bool firstLaunch = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !firstLaunch,
    builder: (context) => const _OnboardingDialog(),
  );
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final en = strings.lang == AppLanguage.english;
    final pages = _pages(theme, en);
    final isLast = _page == pages.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(strings.obSkip),
                  ),
                  const Spacer(),
                  for (var i = 0; i < pages.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed:
                        isLast ? () => Navigator.of(context).pop() : _next,
                    child: Text(isLast ? strings.obDone : strings.obNext),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pages(ThemeData theme, bool en) {
    return [
      _buildPage(
        theme,
        icon: Icons.shield_outlined,
        title: en ? 'Welcome to VCTCrypt' : '欢迎使用 VCTCrypt',
        bullets: en
            ? [
                'Every file is protected by three independent AES-256-GCM layers.',
                'Keys are derived with PBKDF2 (600,000 iterations) - brute force is impractical.',
                'Everything runs 100% offline on this device. Nothing is ever uploaded.',
              ]
            : [
                '每个文件由三层独立的 AES-256-GCM 加密保护。',
                '密钥经 PBKDF2 60 万次迭代派生，暴力破解不现实。',
                '全部运算在本机离线完成，不上传任何数据。',
              ],
      ),
      _buildPage(
        theme,
        icon: Icons.enhanced_encryption,
        title: en ? 'Advanced security' : '高级安全',
        bullets: en
            ? [
                'Decoy partition: a second password reveals an innocent decoy file instead.',
                'Duress password: entering it silently destroys the file - irreversible.',
                'Secure shred, auto-lock and panic lock protect you further.',
                'Every V2 file looks identical - nobody can prove a decoy or duress exists.',
              ]
            : [
                '伪装分区：输入另一个密码只解出无害的伪装文件。',
                '胁迫密码：输入即静默销毁文件，不可恢复。',
                '安全擦除、自动锁定与紧急锁定提供进一步保护。',
                '所有 V2 文件结构完全一致，无人能证明伪装或胁迫密码的存在。',
              ],
      ),
      _buildPage(
        theme,
        icon: Icons.bolt,
        title: en ? 'Everyday tools' : '日常工具',
        bullets: en
            ? [
                'Password generator with live entropy estimation.',
                'Batch-encrypt many files in one run.',
                'Inspect .VCT metadata without any password.',
                'Local usage statistics - numbers only, never names.',
              ]
            : [
                '密码生成器，实时估算熵值。',
                '批量加密：一次处理多个文件。',
                '无需密码即可查看 .VCT 文件元数据。',
                '本地使用统计，只记数字，不记文件名。',
              ],
      ),
      _buildPage(
        theme,
        icon: Icons.palette_outlined,
        title: en ? 'Make it yours' : '个性化',
        bullets: en
            ? [
                'Light / dark / system themes with 8 accent colors.',
                'English and 简体中文, switchable anytime.',
                'Choose your start page and clipboard auto-clear delay.',
                'Find all of this under Settings.',
              ]
            : [
                '浅色 / 深色 / 跟随系统主题，8 种主题色可选。',
                '中英双语，随时切换。',
                '可设置默认启动页与剪贴板自动清除时间。',
                '以上选项都在“设置”里。',
              ],
      ),
    ];
  }

  Widget _buildPage(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 42,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          for (final b in bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
