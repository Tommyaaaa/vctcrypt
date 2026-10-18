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
      const _Entry('2.3.0', [
        '新增哈希校验工具：计算任意文件的 SHA-256 / SHA-512 / SHA-3-256 校验和（流式计算，大文件不占内存），并与预期值比对验证完整性',
        '政策与条款新增法语、德语、汉喃文版本，五种界面语言各自完整显示',
        '汉喃文界面补全：校验和等新文本由免费翻译 API 生成，遵循越南语语法',
      ], major: true),
      const _Entry('2.2.5', [
        '汉喃文界面重写为真正的 𡨸喃（Chữ Nôm）：遵循越南语语法与词序（đã / không / của …），不再是繁体中文',
        '语言选择改为纵向列表，语言名称（𡨸喃等）完整横排显示，不再挤在一排',
        '旧版本文件（1.x / 2.0.x / 2.1.0 / 2.2.1）完整兼容',
      ], major: true),
      const _Entry('2.2.1', [
        '新增法语、德语、汉喃文（Chữ Nôm）三语界面，共五种界面语言',
        '内置天珩全字库（TH-Feon），完整显示汉喃字与扩展 CJK 汉字（Ext B-F）',
        '中文界面字重加粗两级，显示更粗更清晰',
        '旧版本文件（1.x / 2.0.x / 2.1.0）完整兼容',
      ], major: true),
      const _Entry('2.1.0', [
        '安全加固：口令校验密钥与加密密钥同用 60 万次 PBKDF2 迭代，离线猜测密码不再有捷径',
        '加密提速：移动端启用平台原生加密，密钥派生与加解密不再占用界面线程',
        '界面字体更粗、更易读（Inter + 思源黑体中英文混排）',
        '开源协议由 MIT 更正为 AGPL-3.0',
        '旧版本文件（1.x / 2.0.0）完整兼容，自动回退到旧校验方式',
      ], major: true),
      const _Entry('2.0.0', [
        '全新「其它」板块：关于（图标、官网、作者、协议）、捐赠（支付宝收款码）、政策与条款（隐私政策与使用条款）、更新日志',
        '仓库新增开源协议（LICENSE）',
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
        '密码强度指示器',
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
        '密码生成器（CSPRNG + 密码强度估算）',
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
    const _Entry('2.3.0', [
      'New checksum tool: compute SHA-256 / SHA-512 / SHA-3-256 of any file (streamed, so huge files never fill memory) and compare against an expected value to verify integrity',
      'Policies & Terms now available in Français, Deutsch and Han-Nom - full text in all five UI languages',
      'Han-Nom UI completed: new strings such as the checksum tool were produced through the free translation API, keeping Vietnamese grammar',
    ], major: true),
    const _Entry('2.2.5', [
      'Han-Nom UI rewritten as genuine 𡨸喃 (Chữ Nôm): Vietnamese grammar and word order (đã / không / của …), not Traditional Chinese',
      'Language picker is now a vertical list - every language name, 𡨸喃 included, reads in full horizontally',
      'Files from all older versions (1.x / 2.0.x / 2.1.0 / 2.2.1) remain fully supported',
    ], major: true),
    const _Entry('2.2.1', [
      'New UI languages: Français, Deutsch and Han-Nom (Chữ Nôm) - five UI languages in total',
      'Bundled Tianheng font (TH-Feon) renders Han-Nom and extended CJK glyphs (Ext B-F) completely',
      'Chinese UI text is now two weight steps bolder for a clearer display',
      'Files from all older versions (1.x / 2.0.x / 2.1.0) remain fully supported',
    ], major: true),
    const _Entry('2.1.0', [
      'Security hardening: the password verification key now uses the same 600K PBKDF2 iterations as the encryption keys, so offline password guessing is no easier than attacking the files themselves',
      'Faster encryption: platform-native crypto on mobile moves key derivation and bulk encryption off the UI thread',
      'Bolder, clearer typography (Inter + Noto Sans SC mixed Latin/CJK text)',
      'License corrected from MIT to AGPL-3.0',
      'Files created by older versions (1.x / 2.0.0) remain fully compatible via automatic legacy fallback',
    ], major: true),
    const _Entry('2.0.0', [
      'New "Other" section: About (icon, website, author, license), Donate (Alipay QR), Policies & Terms (privacy policy and terms of use), Changelog',
      'License (LICENSE) added to the repository',
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
      'Password strength meter',
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
      'Password generator (CSPRNG + strength estimation)',
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
