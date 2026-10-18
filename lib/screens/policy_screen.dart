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
  switch (s.lang) {
    case AppLanguage.english:
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
    case AppLanguage.french:
      return [
        _Section('Collecte de données : aucune', [
          'VCTCrypt ne collecte, ne transmet ou ne stocke aucune donnée utilisateur. Il n\'y a pas de code réseau dans l\'application : pas de télémétrie, pas d\'analyse, pas de publicité, pas de rapport de panne, pas de système de compte.',
          'Le développeur ne peut pas savoir quels fichiers vous cryptez, quels mots de passe vous utilisez ou quelles clés vous générez. Tout le chiffrement et le déchiffrement s\'exécutent à 100 % sur votre appareil.',
        ]),
        _Section('Données stockées sur votre appareil', [
          'Les paramètres de l\'application (langue, thème, intervalle de verrouillage automatique, etc.) sont conservés dans le magasin de préférences système uniquement pour restaurer vos préférences d\'interface utilisateur.',
          'Les statistiques d\'utilisation (nombre de fichiers chiffrés/déchiffrés et totaux d\'octets) sont uniquement des compteurs locaux : aucun nom de fichier, aucun chemin, aucun horodatage, ne quitte jamais l\'appareil et peut être réinitialisé à tout moment à partir des paramètres.',
        ]),
        _Section('Fichiers et autorisations', [
          'VCTCrypt lit un fichier uniquement lorsque vous le sélectionnez explicitement ; les sorties sont écrites à l\'emplacement que vous choisissez ou dans le dossier Documents de l\'application.',
          'Les fichiers clés .vctpub/.vctkey sont des fichiers ordinaires sous votre contrôle total - les partager, les sauvegarder et les supprimer fonctionne comme n\'importe quel fichier système. Les clés privées sont stockées sous forme de mot de passe, et ce mot de passe n\'est jamais enregistré nulle part.',
        ]),
        _Section('Les tiers et le cloud', [
          'Aucun service d\'analyse, de publicité ou de cloud tiers n\'est utilisé et aucune vue Web n\'est intégrée.',
          'L\'image QR sur la page Faire un don est expédiée à l\'intérieur de l\'ensemble d\'applications ; elle n\'est pas récupérée du réseau.',
        ]),
        _Section('Modifications de la présente politique', [
          'Si une version future modifie cette politique, le changelog l\'indiquera explicitement et cette page sera mise à jour avec la version.',
        ]),
        ];
    case AppLanguage.german:
      return [
        _Section('Datenerhebung: keine', [
          'VCTCrypt erhebt, überträgt oder speichert keine Benutzerdaten. Es gibt keinen Netzwerkcode in der App: keine Telemetrie, keine Analysen, keine Werbung, keine Absturzberichte, kein Kontosystem.',
          'Der Entwickler kann nicht erfahren, welche Dateien Sie verschlüsseln, welche Passwörter Sie verwenden oder welche Schlüssel Sie generieren. Alle Ver- und Entschlüsselungen laufen zu 100 % auf Ihrem Gerät.',
        ]),
        _Section('Auf Ihrem Gerät gespeicherte Daten', [
          'App-Einstellungen (Sprache, Thema, automatisches Sperrintervall usw.) werden im Systempräferenzspeicher ausschließlich zur Wiederherstellung Ihrer UI-Einstellungen gespeichert.',
          'Nutzungsstatistiken (Anzahl der verschlüsselten/entschlüsselten Dateien und Bytesummen) sind nur lokale Zähler: keine Dateinamen, keine Pfade, keine Zeitstempel, kein Verlassen des Geräts und jederzeit über die Einstellungen zurücksetzbar.',
        ]),
        _Section('Dateien und Berechtigungen', [
          'VCTCrypt liest eine Datei nur, wenn Sie sie explizit auswählen; Ausgaben werden an den von Ihnen gewählten Speicherort oder in den Ordner App Documents geschrieben.',
          '.vctpub / .vctkey Schlüsseldateien sind gewöhnliche Dateien unter Ihrer vollen Kontrolle - das Teilen, Sichern und Löschen funktioniert wie jede Systemdatei. Private Schlüssel werden passwortgeschützt gespeichert, und dieses Passwort wird nirgendwo gespeichert.',
        ]),
        _Section('Dritte und die Cloud', [
          'Es werden keine Analysen, Werbung oder Cloud-Dienste von Drittanbietern verwendet und keine Webansichten eingebettet.',
          'Das QR-Bild auf der Spendenseite wird innerhalb des App-Pakets geliefert; es wird nicht aus dem Netzwerk abgerufen.',
        ]),
        _Section('Änderungen dieser Richtlinie', [
          'Wenn eine zukünftige Version diese Richtlinie ändert, wird dies im Änderungsprotokoll explizit angegeben und diese Seite wird mit der Version aktualisiert.',
        ]),
        ];
    case AppLanguage.hannom:
      return [
        _Section('收集資料：空', [
          'VCTCrypt 空收集、傳或留貯不分資料𠊛用那。空固碼網於應用：空遙測、空分析、空廣告、空報告事故、空固系統賬戶。',
          '家發展空體別伴碼化仍集信那、用密口那、或造鎖那。每碼化吧解碼行 100% 上設備之伴。',
        ]),
        _Section('資料留貯上設備之伴', [
          '該設應用（言語、主題、曠自鎖、云云）得留於倉隨撰系統只抵復回隨撰界面之伴。',
          '統計使用（數量集信碼化／解碼吧總數字節）只羅部點局步：空名集信、空塘引、空跡時間、空包時離設備，吧固體置來不分時那自該設。',
        ]),
        _Section('集信吧權', [
          'VCTCrypt 只讀𠬠集信期伴撰它昭昭；頭出得記入位置伴撰或入書目材料之應用。',
          '.vctpub / .vctkey 羅仍集信鎖平常下完全控制之伴——分、留抄吧刪奴行如不分集信系統那。鎖私得留貯包密口，吧密口妸空包時得留於不分兜。',
        ]),
        _Section('邊第三吧雲', [
          '空分析、廣告咳服務雲之邊第三那得使用，吧空固視圖網絡那得嵌入。',
          '形影 QR 上張捐納得包入內包應用；奴空得拉自網。',
        ]),
        _Section('改換政策尼', [
          '若𠬠版本將來改換政策尼，日記改換㑹昭吧張尼㑹得更新與版本。',
        ]),
        ];
    default:
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
}


// ---- Terms of Use ----
List<_Section> _termsSections(AppStrings s) {
  switch (s.lang) {
    case AppLanguage.english:
      return [
        _Section('Acceptance', [
          'By using VCTCrypt you agree to these terms. If you do not agree, stop using and delete the app.',
        ]),
        _Section('Free and open source', [
          'VCTCrypt is released under the AGPL-3.0 license - free and ad-free. You are free to use, study, modify and redistribute it; modified versions must be released under the same license, and if you offer it as a network service you must make the source code available to those users. See the LICENSE file in the repository root.',
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
    case AppLanguage.french:
      return [
        _Section('Acceptation', [
          'En utilisant VCTCrypt, vous acceptez ces conditions. Si vous n\'êtes pas d\'accord, arrêtez d\'utiliser et supprimez l\'application.',
        ]),
        _Section('Gratuit et open source', [
          'VCTCrypt est publié sous la licence AGPL-3.0 - gratuitement et sans publicité. Vous êtes libre de l\'utiliser, de l\'étudier, de le modifier et de le redistribuer ; les versions modifiées doivent être publiées sous la même licence, et si vous l\'offrez en tant que service réseau, vous devez mettre le code source à la disposition de ces utilisateurs. Voir le fichier LICENSE dans la racine du référentiel.',
        ]),
        _Section('Exclusions de garanties', [
          'LE PROGRAMME EST FOURNI EN L\'ÉTAT, SANS GARANTIE D\'AUCUNE SORTE, EXPLICITE OU IMPLICITE, Y COMPRIS LES GARANTIES DE COMMERCIALISATION OU D\'ADAPTATION DANS UN BUT PARTICULIER ET L\'ABSENCE DE CONTREFAÇON.',
          'L\'irrécupérabilité fait partie de la conception de la sécurité : si vous oubliez un mot de passe ou perdez une clé privée .vctkey, personne - y compris l\'auteur - ne peut récupérer le contenu du fichier. Sauvegardez soigneusement les mots de passe et les clés.',
          'Vous assumez toutes les conséquences de l\'utilisation de l\'effacement sous contrainte, de la partition leurre et des fonctions de destruction sécurisée. L\'auteur n\'est pas responsable de toute perte directe ou indirecte de données.',
        ]),
        _Section('AVIS DE CONFORMITÉ', [
          'Certaines juridictions limitent la possession, l\'utilisation ou l\'exportation de logiciels de cryptage. Il est de votre responsabilité de vérifier et de vous conformer aux lois applicables là où vous vivez.',
        ]),
        _Section('Dons', [
          'Les dons sont entièrement volontaires, ne débloquent aucune fonctionnalité et ne créent aucun contrat de service ou obligation de soutien.',
        ]),
        ];
    case AppLanguage.german:
      return [
        _Section('Akzeptanz', [
          'Durch die Verwendung von VCTCrypt stimmen Sie diesen Bedingungen zu. Wenn Sie nicht einverstanden sind, beenden Sie die Nutzung und löschen Sie die App.',
        ]),
        _Section('Gratis und Open-Source', [
          'VCTCrypt wird unter der AGPL-3.0-Lizenz veröffentlicht - kostenlos und werbefrei. Es steht Ihnen frei, es zu verwenden, zu studieren, zu modifizieren und weiterzugeben; modifizierte Versionen müssen unter derselben Lizenz veröffentlicht werden, und wenn Sie es als Netzwerkdienst anbieten, müssen Sie den Quellcode diesen Benutzern zur Verfügung stellen. Siehe LICENSE-Datei im Repository-Stammverzeichnis.',
        ]),
        _Section('Haftungsausschlüsse', [
          'Die Software wird "wie besehen" bereitgestellt, ohne jegliche Garantie, weder ausdrücklich noch stillschweigend, einschließlich der Garantien der Marktgängigkeit, der Eignung für einen bestimmten Zweck und der Nichtverletzung von Rechten Dritter.',
          'Unwiederherstellbarkeit ist Teil des Sicherheitsdesigns: Wenn Sie ein Passwort vergessen oder einen privaten .vctkey-Schlüssel verlieren, kann niemand - einschließlich des Autors - den Dateiinhalt wiederherstellen. Sichern Sie Passwörter und Schlüssel sorgfältig.',
          'Sie übernehmen alle Konsequenzen der Verwendung des Zwangslöschens, der Decoy-Partition und der sicheren Shredder-Funktion. Der Autor haftet nicht für direkte oder indirekte Datenverluste.',
        ]),
        _Section('Compliance-Hinweis', [
          'Einige Gerichtsbarkeiten beschränken den Besitz, die Verwendung oder den Export von Verschlüsselungssoftware. Es liegt in Ihrer Verantwortung, die in Ihrem Wohnort geltenden Gesetze zu überprüfen und einzuhalten.',
        ]),
        _Section('Spenden', [
          'Spenden sind völlig freiwillig, schalten keine Funktionen frei und begründen keinen Servicevertrag oder eine Supportverpflichtung.',
        ]),
        ];
    case AppLanguage.hannom:
      return [
        _Section('執認', [
          '憑分使用 VCTCrypt，伴同意與各條款尼。若伴空同意，丐停使用吧刪應用。',
        ]),
        _Section('免費吧源開', [
          'VCTCrypt 得發行隨許可 AGPL-3.0——免費吧空廣告。伴得自由使用、研究、修改吧分派來奴；各版本修改沛得發行隨共一許可，吧若伴供給奴如𠬠服務網，伴沛供給碼源朱仍𠊛用妸。看集信 LICENSE 於書目根之倉貯。',
        ]),
        _Section('空保修；宣辭責任', [
          '分軟得供給「原狀」，空保擔下不分形式那、昭昭咳寓意，包兼仍空界限於各保擔回可能商賣、事符合朱𠬠目的具體吧空違犯。',
          '可能空體復回羅一分之設計保密：若伴唅密口或失鎖私 .vctkey，空埃——計奇作者——固體復回內容集信。留抄密口吧鎖昭謹慎。',
          '伴自定畢後果之役使用刪強逼、分區偽吧功能安碎。作者空受責任朱不分損失資料直接咳間接那。',
        ]),
        _Section('通報遵守', [
          '𠬠數區域法律限制役所有、使用或出口分軟碼化。伴固責任核明吧遵守律法現行在坭伴生𤯩。',
        ]),
        _Section('捐納', [
          '各款捐納羅完全自願，空開鎖功能那，吧空造出合同服務咳義務輔助。',
        ]),
        ];
    default:
      return [
        _Section('接受条款', [
          '使用 VCTCrypt 即表示你同意本条款。若不同意，请停止使用并删除本应用。',
        ]),
        _Section('免费开源', [
          'VCTCrypt 以 AGPL-3.0 开源协议发布，免费、无广告。你可以自由使用、研究、修改和分发，但衍生作品须以相同协议开源；若将其作为网络服务提供，也须向使用者提供源代码。详见仓库根目录的 LICENSE 文件。',
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
}

