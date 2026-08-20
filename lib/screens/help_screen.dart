/// VCTCrypt - Help & Usage screen (v1.3.0)
/// Expandable FAQ-style documentation for every feature.

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = VCTCryptApp.of(context).strings;
    final en = strings.lang == AppLanguage.english;
    final entries = _entries(en);

    return Scaffold(
      appBar: AppBar(title: Text(strings.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Local-only banner
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      en
                          ? 'All encryption and decryption runs locally on this device. VCTCrypt never touches the network.'
                          : '所有加解密均在本地完成，VCTCrypt 从不联网。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final e in entries)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(e.icon, color: theme.colorScheme.primary),
                  title: Text(
                    e.title,
                    style: theme.textTheme.titleSmall,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        e.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<_HelpEntry> _entries(bool en) {
    return [
      _HelpEntry(
        Icons.rocket_launch_outlined,
        en ? 'Quick start' : '快速上手',
        en
            ? '1. On the Encrypt tab, pick one or more files.\n'
                '2. Enter a password (tip: the dice button generates a strong one).\n'
                '3. Tap Encrypt - a .VCT file appears next to the original.\n\n'
                'Decrypting works the same way on the Decrypt tab. On desktop you can also drag and drop files onto the card.'
            : '1. 在“加密”页选择一个或多个文件。\n'
                '2. 输入密码（提示：点骰子按钮可生成强密码）。\n'
                '3. 点击加密，原文件旁会生成 .VCT 文件。\n\n'
                '解密在“解密”页操作，方式相同。桌面端还支持把文件拖放到卡片上。',
      ),
      _HelpEntry(
        Icons.theater_comedy,
        en ? 'Decoy partition' : '伪装分区',
        en
            ? 'When encrypting, open Advanced Security Options and set a decoy password plus a decoy file.\n\n'
                'Anyone who enters the decoy password during decryption gets the decoy file - with exactly the same success message and timing as the real one. The real content stays hidden.\n\n'
                'Pick a decoy file that looks plausible for your situation.'
            : '加密时展开“高级安全选项”，设置伪装密码并选择一个伪装文件。\n\n'
                '解密时输入伪装密码，只会解出伪装文件——成功提示与耗时和真文件完全一致，真实内容仍然隐藏。\n\n'
                '建议选择一个“看起来合理”的文件作为伪装。',
      ),
      _HelpEntry(
        Icons.local_fire_department,
        en ? 'Duress password' : '胁迫密码',
        en
            ? 'If you may be forced to hand over a password, arm a duress password in advance.\n\n'
                'Entering it during decryption PERMANENTLY DESTROYS the .VCT file. The app then behaves exactly as if the password had been wrong - an attacker cannot tell the trap was triggered.\n\n'
                'This is irreversible: the file cannot be recovered afterwards, even with the correct password.'
            : '如果你可能被强迫交出密码，可预先设置胁迫密码。\n\n'
                '解密时输入胁迫密码，.VCT 文件将被永久销毁。此后应用的表现与“密码错误”完全一致，攻击者无法察觉陷阱已被触发。\n\n'
                '此操作不可逆：即使之后拿到正确密码，文件也无法恢复。',
      ),
      _HelpEntry(
        Icons.delete_forever_outlined,
        en ? 'Secure shred' : '安全擦除',
        en
            ? 'Enable "Shred original after encryption" to overwrite the original file with random data before deleting it, so it cannot be recovered with undelete tools.\n\n'
                'Shredding only runs after the encrypted output has been verified - if encryption fails, your original stays intact.'
            : '开启“加密后安全擦除原文件”，会用随机数据覆写原文件后再删除，防止被恢复工具找回。\n\n'
                '只有加密产物校验通过后才会执行擦除；若加密失败，原文件保持原样。',
      ),
      _HelpEntry(
        Icons.timer_outlined,
        en ? 'Auto-lock & panic lock' : '自动锁定与紧急锁定',
        en
            ? 'Auto-lock (Settings → Security) clears every entered password after a period of inactivity: 1, 5, 10 or 30 minutes, or off.\n\n'
                'Need to clear everything RIGHT NOW? Tap the shield button in the toolbar of the Encrypt or Decrypt screen - the panic lock wipes all password fields app-wide instantly.'
            : '自动锁定（设置 → 安全）在空闲一段时间后自动清空所有已输入的密码：1 / 5 / 10 / 30 分钟可选，也可关闭。\n\n'
                '需要立即清空？点加密或解密页顶栏的盾牌按钮——紧急锁定会瞬间清空全应用的密码输入框。',
      ),
      _HelpEntry(
        Icons.casino_outlined,
        en ? 'Password generator' : '密码生成器',
        en
            ? 'The dice button next to each password field opens the generator: 8-64 characters, four character classes, optional exclusion of look-alike characters (0O1lI).\n\n'
                'The entropy meter estimates strength - aim for "Strong" (90+ bits) for anything important.\n\n'
                'Copied passwords can be wiped from the clipboard automatically (Settings → Personalization → Clipboard auto-clear).'
            : '密码框旁的骰子按钮打开生成器：8-64 位长度、四类字符、可选排除易混淆字符（0O1lI）。\n\n'
                '熵值估算条会显示强度——重要文件建议达到“强”（90 位以上）。\n\n'
                '复制的密码可自动从剪贴板清除（设置 → 个性化 → 剪贴板自动清除）。',
      ),
      _HelpEntry(
        Icons.info_outline,
        en ? 'File inspector' : '文件检查器',
        en
            ? 'After selecting a .VCT file on the Decrypt tab, tap "File Info" to read its header metadata without any password: format version, sizes, header length, cipher and modification time.\n\n'
                'The inspector only exposes format-level facts. V2 files always contain all three slots, so it can never reveal whether a decoy or duress password is set.'
            : '在解密页选中 .VCT 文件后，点“文件信息”即可无需密码读取头部元数据：格式版本、大小、头部长度、算法与修改时间。\n\n'
                '检查器只展示格式级信息。V2 文件始终包含全部三个分区，因此永远无法判断是否设置了伪装或胁迫密码。',
      ),
      _HelpEntry(
        Icons.library_add_outlined,
        en ? 'Batch encryption' : '批量加密',
        en
            ? 'Select multiple files at once on the Encrypt tab. All of them are encrypted sequentially with the same password; the result card shows per-file outcomes and the total size.\n\n'
                'The decoy partition is unavailable in batch mode - encrypt files one by one if you need one. Duress passwords and shredding work normally.\n\n'
                'If some files fail, your password is kept so you can retry.'
            : '在加密页可一次选择多个文件，全部按同一密码依次加密；结果卡片会显示每个文件的结果与总大小。\n\n'
                '批量模式不支持伪装分区——如需伪装请逐个加密。胁迫密码与安全擦除可正常使用。\n\n'
                '如有失败文件，密码会保留以便重试。',
      ),
      _HelpEntry(
        Icons.description_outlined,
        en ? 'File formats & compatibility' : '文件格式与兼容性',
        en
            ? 'V1 (classic): the original triple-GCM format, byte-compatible with the VCTCrypt CLI releases.\n\n'
                'V2 (advanced): adds always-present decoy and duress slots in a 332-byte header. Used when you enable advanced options.\n\n'
                'Both formats decrypt everywhere; files encrypted without advanced options keep using V1 for maximum compatibility.'
            : 'V1（经典）：原始三重 GCM 格式，与 VCTCrypt 命令行版完全兼容。\n\n'
                'V2（高级）：332 字节头部，始终包含伪装与胁迫分区。启用高级选项时使用。\n\n'
                '两种格式均可正常解密；未启用高级选项时仍使用 V1，以获得最大兼容性。',
      ),
      _HelpEntry(
        Icons.help_outline,
        en ? 'I forgot my password' : '忘记密码怎么办',
        en
            ? 'There is no recovery option - and that is by design. The keys never leave your head, so nobody (including the author) can decrypt the file without the password.\n\n'
                'Keep important passwords in a password manager or written down somewhere safe.'
            : '没有任何找回途径——这是有意为之的设计。密钥只存在于你的头脑中，任何人（包括作者）都无法在没有密码的情况下解密文件。\n\n'
                '请用密码管理器或安全的纸质记录保管重要密码。',
      ),
      _HelpEntry(
        Icons.error_outline,
        en ? '"Wrong password" causes' : '“密码错误”的常见原因',
        en
            ? '1. A typo - passwords are case-sensitive.\n'
                '2. A duress password was entered and the file has been destroyed (indistinguishable from a wrong password by design).\n'
                '3. The file is corrupted or was truncated during transfer.\n\n'
                'Check the file size against the original, and try the password in a plain text editor first to rule out typos.'
            : '1. 输入有误——密码区分大小写。\n'
                '2. 输入了胁迫密码，文件已被销毁（设计上与密码错误的表现完全一致）。\n'
                '3. 文件损坏或传输时被截断。\n\n'
                '可先对比文件大小是否与原始一致，并在纯文本编辑器里核对密码排除输入错误。',
      ),
      _HelpEntry(
        Icons.phone_iphone,
        en ? 'Where are my files on mobile?' : '手机上文件在哪里？',
        en
            ? 'On iOS and Android, encrypted and decrypted files are written to the VCTCrypt folder.\n\n'
                'Open the system Files app (iOS: "On My iPhone → VCTCrypt"; Android: Documents/VCTCrypt) to find them.'
            : '在 iOS 与 Android 上，加密与解密的产物都保存在 VCTCrypt 文件夹中。\n\n'
                '打开系统“文件”App（iOS：“我的 iPhone → VCTCrypt”；Android：Documents/VCTCrypt）即可找到。',
      ),
      _HelpEntry(
        Icons.privacy_tip_outlined,
        en ? 'Privacy' : '隐私说明',
        en
            ? 'VCTCrypt contains no analytics, no ads and no network code. Keys are derived on-device and never stored.\n\n'
                'Usage statistics (Settings) are aggregate counters kept only in local storage - no file names, no paths, no passwords.'
            : 'VCTCrypt 不含任何统计、广告或联网代码。密钥在本机派生，从不存储。\n\n'
                '使用统计（设置页）只是保存在本地的聚合计数——不含文件名、路径或密码。',
      ),
    ];
  }
}

class _HelpEntry {
  final IconData icon;
  final String title;
  final String body;

  const _HelpEntry(this.icon, this.title, this.body);
}
