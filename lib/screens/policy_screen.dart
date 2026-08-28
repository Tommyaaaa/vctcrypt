/// VCTCrypt - Policies & Terms Screen (v2.0.0)
/// Two tabs: Privacy Policy and Terms of Use. Full offline text -
/// it ships inside the app so it is readable without any network.

import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../main.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = VCTCryptApp.of(context).strings;
    final privacy = _privacySections(strings);
    final terms = _termsSections(strings);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.policyTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.policyPrivacyTab),
              Tab(text: strings.policyTermsTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PolicyBody(sections: privacy),
            _PolicyBody(sections: terms),
          ],
        ),
      ),
    );
  }
}

/// One policy section: a bold heading plus paragraphs.
class _Section {
  final String heading;
  final List<String> paragraphs;
  const _Section(this.heading, this.paragraphs);
}

class _PolicyBody extends StatelessWidget {
  final List<_Section> sections;
  const _PolicyBody({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.heading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final para in s.paragraphs) ...[
              Text(
                para,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ---- Privacy Policy ----
List<_Section> _privacySections(AppStrings s) {
  final en = s.lang == AppLanguage.english;
  if (!en) {
    return [
      _Section('数据收集：无', [
        'VCTCrypt 不收集、不传输、不存储任何用户数据。应用内不存在网络代码：没有遥测、没有分析、没有广告、没有崩溃报告、没有账号系统。',
        '开发者无法得知你加密了什么文件、用了什么密码、生成了什么密钥。所有加解密运算 100% 在你的设备上完成。',
      ]),
      _Section('存储在本机的数据', [
        '应用设置（语言、主题、自动锁定时长等）保存在系统应用偏好存储中，仅用于恢复你的界面偏好。',
        '使用统计（加密/解密次数与字节数）仅是本机计数器：不含文件名、不含路径、不含时间戳，也绝不离开设备，可随时在设置页清零。',
      ]),
      _Section('文件与权限', [
        'VCTCrypt 只在你主动选择文件时读取它；输出文件写入你选择的位置或应用文档目录。',
        '.vctpub / .vctkey 密钥文件是普通文件，由你全权管理：分享、备份、删除均与系统文件一致。私钥以密码保护形式存储，该密码不保存在任何地方。',
      ]),
      _Section('第三方与云端', [
        '不使用任何第三方分析、广告或云服务，也未嵌入任何网页组件。',
        '捐赠页面展示的收款码图片打包在应用内部，不联网获取。',
      ]),
      _Section('隐私政策变更', [
        '若未来版本变更本政策，更新日志会明确列出，本页面内容也随版本更新。',
      ]),
    ];
  }
  return [
    _Section('Data collection: none', [
      'VCTCrypt does not collect, transmit or store any user data. There is no networking code in the app: no telemetry, no analytics, no ads, no crash reporting, no account system.',
      'The developer cannot learn what files you encrypt, which passwords you use, or which keys you generate. All encryption and decryption runs 100% on your device.',
    ]),
    _Section('Data stored on your device', [
      'App settings (language, theme, auto-lock interval, etc.) are kept in the system preferences store solely to restore your UI preferences.',
      'Usage statistics (counts of files encrypted/decrypted and byte totals) are local counters only: no file names, no paths, no timestamps, never leaving the device, and resettable at any time from Settings.',
    ]),
    _Section('Files and permissions', [
      'VCTCrypt reads a file only when you explicitly pick it; outputs are written to the location you choose or to the app Documents folder.',
      '.vctpub / .vctkey key files are ordinary files under your full control - sharing, backing up and deleting them works like any system file. Private keys are stored password-wrapped, and that password is never saved anywhere.',
    ]),
    _Section('Third parties and the cloud', [
      'No third-party analytics, advertising or cloud service is used, and no web views are embedded.',
      'The QR image on the Donate page ships inside the app bundle; it is not fetched from the network.',
    ]),
    _Section('Changes to this policy', [
      'If a future version changes this policy, the changelog will state it explicitly and this page is updated with the version.',
    ]),
  ];
}

// ---- Terms of Use ----
List<_Section> _termsSections(AppStrings s) {
  final en = s.lang == AppLanguage.english;
  if (!en) {
    return [
      _Section('接受条款', [
        '使用 VCTCrypt 即表示你同意本条款。若不同意，请停止使用并删除本应用。',
      ]),
      _Section('免费开源', [
        'VCTCrypt 以 MIT 开源协议发布，免费、无广告。你可以自由使用、修改和分发，但需保留版权与许可声明。详见仓库根目录的 LICENSE 文件。',
      ]),
      _Section('无担保与免责', [
        '本软件按“现状”提供，不提供任何明示或默示的担保，包括对适商性、特定用途适用性和非侵权的担保。',
        '加密的不可恢复性是安全设计的一部分：忘记密码或丢失 .vctkey 私钥，任何人都无法（包括作者）恢复文件内容。请务必妥善备份密码与密钥。',
        '使用胁迫销毁、伪装分区、安全粉碎等功能造成的任何数据损失，由使用者自行承担。作者不对任何直接或间接损失负责。',
      ]),
      _Section('合规提示', [
        '部分国家和地区对加密软件的持有、使用或出口有法律限制。你有责任确认并遵守所在司法管辖区的相关法律法规。',
      ]),
      _Section('捐赠', [
        '捐赠完全出于自愿，不会解锁任何功能，也不构成任何服务合同或支持承诺。',
      ]),
    ];
  }
  return [
    _Section('Acceptance', [
      'By using VCTCrypt you agree to these terms. If you do not agree, stop using and delete the app.',
    ]),
    _Section('Free and open source', [
      'VCTCrypt is released under the MIT license - free and ad-free. You may use, modify and redistribute it, provided the copyright and license notice are retained. See the LICENSE file in the repository root.',
    ]),
    _Section('No warranty; disclaimers', [
      'The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement.',
      'Irrecoverability is part of the security design: if you forget a password or lose a .vctkey private key, nobody - including the author - can recover the file contents. Back up passwords and keys carefully.',
      'You assume all consequences of using the duress wipe, decoy partition and secure shred features. The author is not liable for any direct or indirect loss of data.',
    ]),
    _Section('Compliance notice', [
      'Some jurisdictions restrict the possession, use or export of encryption software. It is your responsibility to verify and comply with the laws applicable where you live.',
    ]),
    _Section('Donations', [
      'Donations are entirely voluntary, unlock no features, and create no service contract or support obligation.',
    ]),
  ];
}
