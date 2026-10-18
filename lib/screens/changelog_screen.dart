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
  if (s.lang == AppLanguage.hannom) {
    return [
      const _Entry('2.3.1', [
        '界面吧政策𡨸喃㐌改寫為真正之𡨸喃：語法吧詞序㗂越，得造來憑 API 譯免費，非以𡨸中文逐字譯',
        '政策吧條款（隱私政策、使用條款）於𡨸喃㐌得重譯完全',
        '包兼工具總檢吧政策五言語自 v2.3.0',
      ], major: true),
      const _Entry('2.3.0', [
        '工具總檢新：算 SHA-256 / SHA-512 / SHA-3-256 之不分集信那（處理隨流，能集信大空包時盈記憶）吧比較與價值豫見抵核明原完',
        '政策吧條款今固於法語、德語吧𡨸喃——全文於畢五種界面言語',
      ], major: true),
      const _Entry('2.2.5', [
        '界面𡨸喃㐌改寫為真正之𡨸喃：語法吧詞序㗂越（㐌／空／之…），非繁體中文',
        '列表撰言語今羅縱——每名言語，含𡨸喃，得讀橫完全',
        '集信自畢版本舊（1.x / 2.0.x / 2.1.0 / 2.2.1）常得扶助完全',
      ], major: true),
      const _Entry('2.2.1', [
        '言語界面新：法語、德語吧𡨸喃——共五言語界面',
        '字庫天珩內置（TH-Feon）顯𡨸喃吧字形中日韓擴展（Ext B-F）完全',
        '文本界面中文今加兩級粗，顯更清楚',
        '集信自畢版本舊（1.x / 2.0.x / 2.1.0）常得扶助完全',
      ], major: true),
      const _Entry('2.1.0', [
        '加固保密：鎖核口令吧鎖碼化共得 60 萬次 PBKDF2，猜密口離線空固捷徑',
        '提速碼化：於移動得開碼化原生之平台，引出鎖吧碼化空占線界面',
        '字形更粗、更清楚（Inter + 思源黑體排拉丁／中日韓）',
        '許可得改正自 MIT 朱 AGPL-3.0',
        '集信造自版本舊（1.x / 2.0.0）常合完全憑自退舊式',
      ], major: true),
      const _Entry('2.0.0', [
        '版塊「別」新：介紹（圖標、網頁、作者、許可）、擁護（支付寶 QR）、政策與條款（隱私政策吧使用條款）、更新誌',
        '倉裡加許可（LICENSE）',
        '里程碑大：功能系趨完全，號版本升朱 2.0',
      ], major: true),
      const _Entry('1.6.0', [
        '碼化後量子隨選：鎖𠊛認 ML-KEM-768（NIST FIPS 203）',
        '頁「鎖」新：造／入／分／刪鎖公開 .vctpub 吧鎖私 .vctkey',
        '頁碼化得撰鎖公開𠊛認，密口變隨選——雙通道（密口或鎖）或只鎖集信（V3 格式）',
        '頁解碼得開集信碼化𠊛認憑 .vctkey + 密口保護之',
        'ML-KEM 純 Dart 得對證與庫標準之 Go 憑向量 KAT 內置',
      ]),
      const _Entry('1.5.0', [
        '記註保密：文本碼化為集信 .VCT 標準，明文空包時觸碟',
        '計強度密口',
        '捷徑電腦 Ctrl+1..5（頁）吧 Ctrl+L（急鎖）',
        '鈕分全寬於牌結果移動',
      ]),
      const _Entry('1.4.0', [
        '正顯於 App 集信 iOS：寫原子（集信暫 + 改名）',
        '板分／留於移動',
        '圖標應用新（盾黑上白）吧名統一 VCTCrypt',
      ]),
      const _Entry('1.3.0', [
        '引導始用吧中心幫助（FAQ）',
        '碼化批量憑結果每集信',
        '自清板暫如式 KeePass',
        '個性化：8 色按、偏頁啟',
      ]),
      const _Entry('1.2.0', [
        '生器密口（CSPRNG + 估強度）',
        '器查集信 .VCT 空密口',
        '統計使用局步（只數，空名／塘引）',
        '急鎖：清每框密口一并',
      ]),
      const _Entry('1.1.0', [
        '分區偽：密口二出集信偽無害',
        '密口脅迫：入它時解碼永久碎集信',
        '可辭憑設計：每集信 V2 常含畢三槽',
        '碎安吧自鎖',
      ]),
      const _Entry('1.0.x', [
        '重寫 Flutter（Win32 GUI → Material 3）',
        '構建 CI 五平台（Windows / macOS / Linux / Android / iOS）',
        '合字節與格式 V1 / CLI',
      ]),
    ];
  }
  final en = s.lang == AppLanguage.english;
  if (!en) {
    return [
      const _Entry('2.3.1', [
        '汉喃文界面与汉喃文政策条款改写为真正的 𡨸喃（Chữ Nôm）：遵循越南语语法与词序，由免费翻译 API 生成，不再是逐字的越南语直译中文',
        '隐私政策、使用条款的汉喃文版本全部重译',
        '包含 v2.3.0 的哈希校验工具与五种语言政策条款',
      ], major: true),
      const _Entry('2.3.0', [
        '新增哈希校验工具：计算任意文件的 SHA-256 / SHA-512 / SHA-3-256 校验和（流式计算，大文件不占内存），并与预期值比对验证完整性',
        '政策与条款新增法语、德语、汉喃文版本，五种界面语言各自完整显示',
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
    const _Entry('2.3.1', [
      'The Han-Nom (𡨸喃) UI and the Han-Nom Policies & Terms were rewritten as genuine Chữ Nôm - Vietnamese grammar and word order, produced through a free translation API rather than a word-for-word Chinese rendering',
      'Privacy Policy and Terms of Use fully re-translated into Han-Nom',
      'Includes the v2.3.0 checksum tool and the five-language policies',
    ], major: true),
    const _Entry('2.3.0', [
      'New checksum tool: compute SHA-256 / SHA-512 / SHA-3-256 of any file (streamed, so huge files never fill memory) and compare against an expected value to verify integrity',
      'Policies & Terms now available in Français, Deutsch and Han-Nom - full text in all five UI languages',
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
