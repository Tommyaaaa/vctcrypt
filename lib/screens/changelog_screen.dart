/// VCTCrypt - Changelog Screen (v2.0.0)
/// Version-by-version history, bundled with the app (offline).

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = VCTCryptApp.of(context).strings;
    final entries = _entries(strings);

    return Scaffold(
      appBar: AppBar(title: Text(strings.changelogTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ChangelogCard(entry: entries[i]),
      ),
    );
  }
}

class _Entry {
  final String version;
  final bool major;
  final List<String> items;
  const _Entry(this.version, this.items, {this.major = false});
}

class _ChangelogCard extends StatelessWidget {
  final _Entry entry;
  const _ChangelogCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: entry.major
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.version,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: entry.major
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < entry.items.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.items[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < entry.items.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

List<_Entry> _entries(AppStrings s) {
  final en = s.lang == AppLanguage.english;
  if (!en) {
    return [
      const _Entry('2.1.0 Beta', [
        '安全加固（P0）：口令校验密钥与加密密钥同用 60 万次 PBKDF2 迭代，封堵离线爆破「便宜 60 倍」的捷径',
        '旧版本文件（1.x / 2.0.0）完整兼容，自动回退到旧校验方式',
        '解密流程不再重复派生校验密钥，速度损失降到最低',
      ]),
      const _Entry('2.0.0', [
        '全新「其它」板块：关于（图标、官网、作者、协议）、捐赠（支付宝收款码）、政策与条款（隐私政策与使用条款）、更新日志',
        '仓库新增 MIT 开源协议（LICENSE）',
        '大版本里程碑：功能体系趋于完整，主版本号升至 2.0',
      ], major: true),
      const _Entry('1.6.0', [
        '可选后量子加密：ML-KEM-768（NIST FIPS 203）收件人密钥',
        '新增「密钥」页：生成 / 导入 / 分享 / 删除 .vctpub 公钥与 .vctkey 私钥',
        '加密页可选择收件人公钥，密码变为可选——双通道（密码或私钥）或仅私钥文件（V3 格式）',
        '解密页支持用 .vctkey + 保护密码解锁',
        '纯 Dart ML-KEM 实现与 Go 标准库交叉验证，内置 KAT 测试向量',
      ]),
      const _Entry('1.5.0', [
        '安全笔记：加密文本生成标准 .VCT 文件，明文不落盘',
        '密码强度指示器（熵估算）',
        '桌面快捷键 Ctrl+1..5 切换页面、Ctrl+L 紧急锁定',
        '移动端结果卡片全宽分享按钮',
      ]),
      const _Entry('1.4.0', [
        'iOS 文件 App 可见性修复：原子写入（临时文件 + 重命名）',
        '移动端分享 / 存储面板',
        '全新应用图标（黑白盾牌）与统一名称 VCTCrypt',
      ]),
      const _Entry('1.3.0', [
        '首次启动引导与帮助中心（FAQ）',
        '批量加密：一次加密多个文件，逐个结果显示',
        '剪贴板自动清除（KeePass 式）',
        '个性化：8 种强调色、起始页偏好',
      ]),
      const _Entry('1.2.0', [
        '密码生成器（CSPRNG + 熵估算）',
        '.VCT 文件检查器：无需密码查看头信息',
        '本地使用统计（仅计数，无文件名 / 路径）',
        '紧急锁定：一键清空所有密码输入框',
      ]),
      const _Entry('1.1.0', [
        '伪装分区：第二密码显示无害的伪装文件',
        '胁迫密码：解密时输入即永久粉碎文件',
        '可否认设计：V2 文件始终含全部三个槽位',
        '安全粉碎与自动锁定',
      ]),
      const _Entry('1.0.x', [
        'Flutter 重写（Win32 GUI → Material 3）',
        '五平台 CI 自动构建（Windows / macOS / Linux / Android / iOS）',
        'V1 / CLI 格式字节级兼容',
      ]),
    ];
  }
  return [
    const _Entry('2.1.0 Beta', [
      'Security hardening (P0): the password verification key now uses the same 600K PBKDF2 iterations as the encryption keys, closing the 60x cheaper offline brute-force shortcut',
      'Files created by older versions (1.x / 2.0.0) remain fully compatible via automatic legacy fallback',
      'Decryption no longer re-derives the verification key, keeping the speed cost minimal',
    ]),
    const _Entry('2.0.0', [
      'New "Other" section: About (icon, website, author, license), Donate (Alipay QR), Policies & Terms (privacy policy and terms of use), Changelog',
      'MIT license (LICENSE) added to the repository',
      'Major milestone: the feature set is complete; version bumped to 2.0',
    ], major: true),
    const _Entry('1.6.0', [
      'Optional post-quantum encryption: ML-KEM-768 (NIST FIPS 203) recipient keys',
      'New Keys tab: generate / import / share / delete .vctpub public and .vctkey private keys',
      'Encrypt tab can pick a recipient public key, making the password optional - dual-channel (password OR key) or key-only files (V3 format)',
      'Decrypt tab unlocks recipient-encrypted files with .vctkey + its protection password',
      'Pure-Dart ML-KEM cross-validated against Go\'s standard library with checked-in KAT vectors',
    ]),
    const _Entry('1.5.0', [
      'Secure Notes: text encrypted into a standard .VCT file, plaintext never touches disk',
      'Password strength meter with entropy estimation',
      'Desktop shortcuts Ctrl+1..5 (tabs) and Ctrl+L (panic lock)',
      'Full-width share button on mobile result cards',
    ]),
    const _Entry('1.4.0', [
      'iOS Files app visibility fix: atomic writes (temp file + rename)',
      'Share / save sheet on mobile',
      'New app icon (black shield on white) and unified name VCTCrypt',
    ]),
    const _Entry('1.3.0', [
      'Onboarding guide and help center (FAQ)',
      'Batch encryption with per-file results',
      'KeePass-style clipboard auto-clear',
      'Personalization: 8 accent colors, start page preference',
    ]),
    const _Entry('1.2.0', [
      'Password generator (CSPRNG + entropy estimation)',
      'Passwordless .VCT file inspector',
      'Local usage statistics (counts only, no names / paths)',
      'Panic lock: wipe every password field at once',
    ]),
    const _Entry('1.1.0', [
      'Decoy partition: a second password reveals an innocent decoy file',
      'Duress password: entering it during decryption permanently shreds the file',
      'Deniable by design: every V2 file always contains all three slots',
      'Secure shred and auto-lock',
    ]),
    const _Entry('1.0.x', [
      'Flutter rewrite (Win32 GUI → Material 3)',
      'Five-platform CI builds (Windows / macOS / Linux / Android / iOS)',
      'Byte-compatible with V1 / CLI format',
    ]),
  ];
}
