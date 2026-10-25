/// VCTCrypt - Internationalization
/// Supports English, Chinese (Simplified), Français, Deutsch and
/// 𡨸喃 (Chữ Nôm / Han-Nom). Every Han-Nom string is written in genuine
/// Chữ Nôm: Vietnamese grammar and word order, with native Vietnamese
/// words carried by Nôm characters and Sino-Vietnamese words by their
/// Hán characters, rendered by the bundled TH-Feon font. It is NOT
/// Traditional Chinese, and no romanized Vietnamese (quốc ngữ) remains.

enum AppLanguage { english, chinese, french, german, hannom }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.chinese:
        return 'zh';
      case AppLanguage.french:
        return 'fr';
      case AppLanguage.german:
        return 'de';
      case AppLanguage.hannom:
        return 'vi-Hani';
      case AppLanguage.english:
        return 'en';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.chinese:
        return '中文';
      case AppLanguage.french:
        return 'Français';
      case AppLanguage.german:
        return 'Deutsch';
      case AppLanguage.hannom:
        // v2.2.5: the script's own name in Chữ Nôm, not "漢喃文".
        return '𡨸喃';
      case AppLanguage.english:
        return 'English';
    }
  }
}

class AppStrings {
  final AppLanguage lang;

  const AppStrings(this.lang);

  static AppStrings of(AppLanguage lang) => AppStrings(lang);

  /// v2.2.1: 5-way localized string helper
  /// [en] English, [zh] 中文, [fr] Français, [de] Deutsch,
  /// [hn] 𡨸喃 (Chữ Nôm / Han-Nom).
  String tr(String en, String zh, String fr, String de, String hn) {
    switch (lang) {
      case AppLanguage.chinese:
        return zh;
      case AppLanguage.french:
        return fr;
      case AppLanguage.german:
        return de;
      case AppLanguage.hannom:
        return hn;
      case AppLanguage.english:
        return en;
    }
  }

  // ---- App ----
  String get appName => 'VCTCrypt';
  String get appVersion => 'v2.5.0';
  String get guiVersion =>
      tr('[GUI Version]', '[图形界面版]', '[Version GUI]', '[GUI-Version]', '[界面版]');
  String get author => 'Tommy';
  String get algorithm => tr(
      'Algorithm: VCT-Crypt (AES-256 x3 + ML-KEM-768)',
      '算法: VCT-Crypt (AES-256 x3 + ML-KEM-768)',
      'Algorithme : VCT-Crypt (AES-256 x3 + ML-KEM-768)',
      'Algorithmus: VCT-Crypt (AES-256 x3 + ML-KEM-768)',
      '算法: VCT-Crypt (AES-256 x3 + ML-KEM-768)');
  String get whatsNew => tr(
      'New in v2.5.0: the file format moves to V4. Header fields are now authenticated as AES-GCM AAD, so any tampering with length, flags or salt is detected; keys are split with HKDF from a single PBKDF2, making encryption and decryption about 3x faster. (H3) decoy/duress/shred counters are no longer displayed; (H4) the inspector no longer reveals which unlock channels exist; (M6) key fingerprints are 64-bit. Older files still open unchanged; new V4 files cannot be opened by older releases.',
      'v2.5.0 正式版新特性：文件格式升级为 V4。头部字段现在纳入 AES-GCM 认证（AAD），对长度、标志位或盐的任何篡改都会被检出；密钥改为「一次 PBKDF2 + HKDF 拆分」，加解密速度约提升 3 倍。(H3) 不再显示诱饵/胁迫/擦除计数；(H4) 检查器不再透露有哪些解锁通道；(M6) 指纹扩至 64 位。旧文件照常打开；新的 V4 文件无法被旧版本打开。',
      'Nouveautés de la v2.5.0 : le format passe en V4. Les champs d\'en-tête sont désormais authentifiés comme AAD AES-GCM : toute modification de la longueur, des drapeaux ou du sel est détectée ; les clés sont dérivées par HKDF à partir d\'un seul PBKDF2, ce qui rend le chiffrement et le déchiffrement environ 3 fois plus rapides. (H3) les compteurs leurre/contrainte/effacement ne sont plus affichés ; (H4) l\'inspecteur ne révèle plus les canaux de déverrouillage ; (M6) les empreintes de clé font 64 bits. Les anciens fichiers s\'ouvrent toujours ; les nouveaux fichiers V4 ne s\'ouvrent pas avec les anciennes versions.',
      'Neues in v2.5.0: Das Dateiformat wechselt auf V4. Header-Felder werden jetzt als AES-GCM-AAD authentifiziert – jede Manipulation an Länge, Flags oder Salt wird erkannt; Schlüssel werden per HKDF aus einem einzigen PBKDF2 abgeleitet, was Ver- und Entschlüsselung etwa 3-mal schneller macht. (H3) Täuschungs-/Zwangs-/Shred-Zähler werden nicht mehr angezeigt; (H4) der Inspektor verrät keine Entsperrkanäle mehr; (M6) Schlüsselfingerabdrücke sind 64 Bit. Ältere Dateien öffnen sich unverändert; neue V4-Dateien lassen sich mit älteren Versionen nicht öffnen.',
      'v2.5.0 版本新：格式集信陞爲 V4。場頭今得認證如 AAD AES-GCM，每改長度、標誌或鹽皆得檢出；鎖用 HKDF 分拆自沛次 PBKDF2，朱碼化吧解碼快約三倍。(H3) 空仍顯計數偽/脅/碎；(H4) 機檢查空仍露通道解鎖固；(M6) 指紋鎖延至 64 位。集信舊開如常；集信 V4 新空得開於版本舊。');

  /// v1.4.0: share / save button label (mobile result cards).
  String get shareBtn => tr('Share / Save', '分享 / 存储', 'Partager / Enregistrer',
      'Teilen / Speichern', '分 / 留');

  // ---- Secure Notes (v1.5.0) ----
  String get notesTitle =>
      tr('Secure Notes', '安全笔记', 'Notes sécurisées', 'Sichere Notizen', '記註保密');
  String get noteEncrypt => tr('Encrypt Note', '加密笔记', 'Chiffrer une note',
      'Notiz verschlüsseln', '碼化記註');
  String get noteDecrypt => tr('Decrypt Note', '解密笔记', 'Déchiffrer une note',
      'Notiz entschlüsseln', '解碼記註');
  String get noteHint => tr(
      'The text becomes a normal .VCT file. Decrypted text stays in memory only - it is never written to disk.',
      '文本将加密为标准 .VCT 文件。解密后的文本只保留在内存中，绝不写入磁盘。',
      'Le texte devient un fichier .VCT normal. Le texte déchiffré reste en mémoire uniquement — il n\'est jamais écrit sur le disque.',
      'Der Text wird zu einer normalen .VCT-Datei. Entschlüsselter Text bleibt nur im Speicher – er wird nie auf die Festplatte geschrieben.',
      '文本㑹得碼化為平常 .VCT 集信。㐌解碼之文本只於記憶中，空寫出碟。');
  String get noteContentLabel =>
      tr('Note content', '笔记内容', 'Contenu de la note', 'Notizinhalt', '內容記註');
  String get noteEmpty => tr('The note is empty', '笔记内容为空', 'La note est vide',
      'Die Notiz ist leer', '記註空');
  String get noteEncrypted => tr('Note encrypted', '笔记已加密', 'Note chiffrée',
      'Notiz verschlüsselt', '㐌碼化記註');
  String get noteEncryptedMobile => tr(
      'Saved to the app Documents folder. Use Share / Save below to store it anywhere (iCloud Drive included).',
      '已保存到应用文稿目录。用下方“分享 / 存储”可存到任意位置（含 iCloud 云盘）。',
      'Enregistré dans le dossier Documents de l\'application. Utilisez « Partager / Enregistrer » ci-dessous pour le stocker où vous voulez (iCloud Drive inclus).',
      'Im Dokumente-Ordner der App gespeichert. Verwenden Sie unten „Teilen / Speichern", um sie überall zu speichern (inkl. iCloud Drive).',
      '㐌留入應用之材料書目。用下方「分 / 留」朱留於任意處（含 iCloud Drive）。');
  String get noteDecrypted => tr('Note decrypted', '笔记已解密', 'Note déchiffrée',
      'Notiz entschlüsselt', '㐌解碼記註');
  String get noteSavedAs =>
      tr('Saved', '已保存', 'Enregistré', 'Gespeichert', '㐌留');
  String get noteSaveAsFile => tr('Save as file', '另存为文件',
      'Enregistrer en tant que fichier', 'Als Datei speichern', '留成集信');
  String get noteNotText => tr(
      'This file does not contain readable text. If it was encrypted on the Encrypt tab, decrypt it there instead.',
      '该文件不含可读文本。如果它是在“加密”页加密的普通文件，请回到“解密”页进行解密。',
      'Ce fichier ne contient pas de texte lisible. S\'il a été chiffré dans l\'onglet Chiffrer, déchiffrez-le plutôt là-bas.',
      'Diese Datei enthält keinen lesbaren Text. Wenn sie auf der Registerkarte „Verschlüsseln" verschlüsselt wurde, entschlüsseln Sie sie stattdessen dort.',
      '集信尼空含得讀之文本。若它㐌於「碼化」頁得碼化，請回「解碼」頁解碼。');
  String get strengthLabel =>
      tr('Strength', '强度', 'Robustesse', 'Stärke', '強度');
  String get strengthGood => tr('Good', '良好', 'Bon', 'Gut', '好');
  String get strengthBits => tr(' bits', ' 位', ' bits', ' Bit', ' 位');

  // ---- Navigation ----
  String get navEncrypt =>
      tr('Encrypt', '加密', 'Chiffrer', 'Verschlüsseln', '碼化');
  String get navDecrypt =>
      tr('Decrypt', '解密', 'Déchiffrer', 'Entschlüsseln', '解碼');
  String get navSettings =>
      tr('Settings', '设置', 'Réglages', 'Einstellungen', '設置');
  String get navNotes => tr('Notes', '笔记', 'Notes', 'Notizen', '記註');
  String get navKeys => tr('Keys', '密钥', 'Clés', 'Schlüssel', '鎖');

  // ---- Keys screen (v1.6.0, ML-KEM-768) ----
  String get keysTitle => tr(
      'Recipient Keys (ML-KEM-768)',
      '收件人密钥（ML-KEM-768）',
      'Clés du destinataire (ML-KEM-768)',
      'Empfängerschlüssel (ML-KEM-768)',
      '𠊛認鎖（ML-KEM-768）');
  String get keysSubtitle => tr(
      'Generate, import and share post-quantum key pairs',
      '生成、导入并分享后量子密钥对',
      'Générer, importer et partager des paires de clés post-quantiques',
      'Post-Quanten-Schlüsselpaare erzeugen, importieren und teilen',
      '造、入吧分對鎖後量子');
  String get keysIntro => tr(
      'A .vctpub PUBLIC key is what others use to encrypt files TO you - share it freely. A .vctkey PRIVATE key unlocks those files - keep it secret; it is stored password-protected.',
      '.vctpub 公钥供他人向你加密文件时使用，可放心分享；.vctkey 私钥用于解开这些文件，务必保密，它以密码保护形式存储。',
      'Une clé PUBLIQUE .vctpub sert aux autres à chiffrer des fichiers POUR vous — partagez-la librement. Une clé PRIVÉE .vctkey déverrouille ces fichiers — gardez-la secrète ; elle est stockée protégée par mot de passe.',
      'Ein .vctpub-ÖFFENTLICHER Schlüssel wird von anderen verwendet, um Dateien AN SIE zu verschlüsseln – teilen Sie ihn frei. Ein .vctkey-PRIVATER Schlüssel entsperrt diese Dateien – halten Sie ihn geheim; er wird passwortgeschützt gespeichert.',
      '.vctpub 鎖公開羅物𠊛他用以碼化集信朱伴——放心分。.vctkey 鎖私開鎖仍集信底——守密；它得留固密口保護。');
  String get genKeyBtn => tr('Generate Key Pair', '生成密钥对',
      'Générer une paire de clés', 'Schlüsselpaar erzeugen', '造對鎖');
  String get importKeyBtn => tr('Import Key File', '导入密钥文件',
      'Importer un fichier de clé', 'Schlüsseldatei importieren', '入鎖集信');
  String get keyNameLabel =>
      tr('Key name', '密钥名称', 'Nom de la clé', 'Schlüsselname', '名鎖');
  String get keyNameHint => tr(
      'e.g. "Laptop" or "Tommy" (shown to senders)',
      '例如“笔记本电脑”或“Tommy”（发送方会看到）',
      'ex. « Portable » ou « Tommy » (visible par les expéditeurs)',
      'z. B. „Laptop" oder „Tommy" (für Absender sichtbar)',
      '例「電腦」或「Tommy」（𠊛送㑹見）');
  String get keyPwLabel => tr(
      'Private-key password',
      '私钥保护密码',
      'Mot de passe de la clé privée',
      'Passwort des privaten Schlüssels',
      '密口鎖私');
  String get keyPwHint => tr(
      'Protects the .vctkey file only. Losing it loses every file encrypted to this key.',
      '仅用于保护 .vctkey 文件本身。忘记它将无法解开用此密钥加密的所有文件。',
      'Protège uniquement le fichier .vctkey. Le perdre, c\'est perdre tous les fichiers chiffrés avec cette clé.',
      'Schützt nur die .vctkey-Datei. Wer es verliert, verliert alle mit diesem Schlüssel verschlüsselten Dateien.',
      '只護 .vctkey 集信本身。失它羅失每㐌用鎖尼碼化之集信。');
  String get keyGenOk => tr('Key pair generated', '密钥对已生成',
      'Paire de clés générée', 'Schlüsselpaar erzeugt', '㐌造對鎖');
  String keyGenOkBody(String dir) => tr(
      'Saved to $dir. Share the .vctpub file with anyone who should encrypt files to you.',
      '已保存到 $dir。把 .vctpub 文件发给需要向你加密文件的人。',
      'Enregistrée dans $dir. Partagez le fichier .vctpub avec quiconque doit vous chiffrer des fichiers.',
      'Gespeichert unter $dir. Teilen Sie die .vctpub-Datei mit allen, die Ihnen Dateien verschlüsseln sollen.',
      '㐌留入 $dir。分集信 .vctpub 朱任意埃需碼化集信朱伴。');
  String get keyFingerprint =>
      tr('Fingerprint', '指纹', 'Empreinte', 'Fingerabdruck', '指紋');
  String get keyTypePublicLabel => tr(
      'Public key (.vctpub) - share freely',
      '公钥（.vctpub）——可自由分享',
      'Clé publique (.vctpub) — partagez librement',
      'Öffentlicher Schlüssel (.vctpub) – frei teilen',
      '鎖公開（.vctpub）——自得分');
  String get keyTypePrivateLabel => tr(
      'Private key (.vctkey) - keep secret',
      '私钥（.vctkey）——务必保密',
      'Clé privée (.vctkey) — gardez secrète',
      'Privater Schlüssel (.vctkey) – geheim halten',
      '鎖私（.vctkey）——守密');
  String get keyInvalidFile => tr(
      'Not a valid VCTCrypt key file',
      '不是有效的 VCTCrypt 密钥文件',
      'Fichier de clé VCTCrypt non valide',
      'Keine gültige VCTCrypt-Schlüsseldatei',
      '空沛合例 VCTCrypt 鎖集信');
  String get noKeysYet => tr(
      'No key files yet. Generate a pair or import existing .vctpub / .vctkey files.',
      '还没有密钥文件。可生成一对，或导入已有的 .vctpub / .vctkey 文件。',
      'Aucun fichier de clé pour l\'instant. Générez une paire ou importez des fichiers .vctpub / .vctkey existants.',
      'Noch keine Schlüsseldateien. Erzeugen Sie ein Paar oder importieren Sie vorhandene .vctpub-/ .vctkey-Dateien.',
      '未有鎖集信。造一對，或入固有之 .vctpub / .vctkey 集信。');
  String get deleteKeyBtn => tr('Delete', '删除', 'Supprimer', 'Löschen', '除');
  String get deleteKeyConfirmTitle => tr('Delete key file?', '删除密钥文件？',
      'Supprimer le fichier de clé ?', 'Schlüsseldatei löschen?', '除鎖集信？');
  String deleteKeyConfirmBody(String name) => tr(
      '"$name" will be deleted from this device. Files already encrypted with it are NOT affected, but a deleted private key can never decrypt them again. This cannot be undone.',
      '“$name”将从本设备删除。已用它加密的文件不受影响，但私钥一旦删除，那些文件将永远无法解开。此操作不可撤销。',
      '« $name » sera supprimé de cet appareil. Les fichiers déjà chiffrés avec cette clé ne sont PAS affectés, mais une clé privée supprimée ne pourra plus jamais les déchiffrer. Cette action est irréversible.',
      '„$name" wird von diesem Gerät gelöscht. Bereits damit verschlüsselte Dateien sind NICHT betroffen, aber ein gelöschter privater Schlüssel kann sie nie wieder entschlüsseln. Dies kann nicht rückgängig gemacht werden.',
      '「$name」㑹得除離設備尼。㐌用它碼化之仍集信空受影響，但鎖私㐌除空包得解碼來。空得返。');
  String get keyImported => tr(
      'Key imported', '密钥已导入', 'Clé importée', 'Schlüssel importiert', '㐌入鎖');
  String get keyDeleted =>
      tr('Key deleted', '密钥已删除', 'Clé supprimée', 'Schlüssel gelöscht', '㐌除鎖');
  String get mlkemLabel => 'ML-KEM-768';

  // ---- Encrypt screen ----
  String get encryptTitle => tr('Encrypt File', '加密文件', 'Chiffrer un fichier',
      'Datei verschlüsseln', '碼化集信');
  String get encryptSubtitle => tr(
      'Secure any file with triple AES-256-GCM',
      '使用三层 AES-256-GCM 加密任意文件',
      'Sécurisez n\'importe quel fichier avec le triple AES-256-GCM',
      'Sichern Sie jede Datei mit dreifachem AES-256-GCM',
      '用三層 AES-256-GCM 保密每集信');
  String get selectFile => tr(
      'Tap to select a file',
      '点击选择文件',
      'Touchez pour sélectionner un fichier',
      'Zum Auswählen einer Datei tippen',
      '按以選集信');
  String get selectFileHint => tr(
      'Or drag and drop a file here (desktop)',
      '或将文件拖放到此处（桌面端）',
      'Ou glissez-déposez un fichier ici (bureau)',
      'Oder Datei hierher ziehen und ablegen (Desktop)',
      '或拖放集信於此（電腦）');
  String get passwordLabel =>
      tr('Password', '密码', 'Mot de passe', 'Passwort', '密口');
  String get confirmPasswordLabel => tr('Confirm Password', '确认密码',
      'Confirmer le mot de passe', 'Passwort bestätigen', '確認密口');
  String get passwordHint => tr(
      'Enter password (min 4 chars)',
      '输入密码（至少4个字符）',
      'Saisissez le mot de passe (4 caractères min.)',
      'Passwort eingeben (mind. 4 Zeichen)',
      '入密口（最少4字符）');
  String get browse => tr('Browse', '浏览', 'Parcourir', 'Durchsuchen', '閱');
  String get encryptBtn =>
      tr('Encrypt', '加密', 'Chiffrer', 'Verschlüsseln', '碼化');
  String get cancel => tr('Cancel', '取消', 'Annuler', 'Abbrechen', '毁');

  // ---- Advanced security options (v1.1.0) ----
  String get advancedOptions => tr(
      'Advanced Security Options',
      '高级安全选项',
      'Options de sécurité avancées',
      'Erweiterte Sicherheitsoptionen',
      '高級保密選項');
  String get advancedOptionsHint => tr(
      'Optional. Decoy partition and duress wipe.',
      '可选。伪装分区与胁迫销毁。',
      'Optionnel. Partition leurre et destruction sous contrainte.',
      'Optional. Täuschungspartition und Zwangs-Löschung.',
      '隨選。偽裝分區與脅迫除。');

  String get decoySection => tr('Decoy Partition', '伪装分区', 'Partition leurre',
      'Täuschungspartition', '偽裝分區');
  String get decoyPwLabel => tr('Decoy Password', '伪装密码', 'Mot de passe leurre',
      'Täuschungspasswort', '偽密口');
  String get decoyPwHint => tr(
      'Entering this password during decryption reveals the decoy file instead of the real one.',
      '解密时输入此密码将解出伪装文件，而非真实文件。',
      'Saisir ce mot de passe lors du déchiffrement révèle le fichier leurre au lieu du vrai.',
      'Die Eingabe dieses Passworts beim Entschlüsseln zeigt die Täuschungsdatei statt der echten Datei.',
      '解碼時入密口尼㑹出偽集信，非真集信。');
  String get decoyFileLabel =>
      tr('Decoy File', '伪装文件', 'Fichier leurre', 'Täuschungsdatei', '偽集信');
  String get decoyFileHint => tr(
      'Pick a plausible file to show (e.g. an innocent document)',
      '选择一个无所谓的文件作为伪装内容（例如普通文档）',
      'Choisissez un fichier plausible à afficher (ex. un document anodin)',
      'Wählen Sie eine plausible Datei zum Anzeigen (z. B. ein harmloses Dokument)',
      '選一望似真之集信朱現（例：無害材料）');

  String get duressSection => tr('Duress Password', '胁迫密码',
      'Mot de passe de contrainte', 'Zwangs-Passwort', '脅迫密口');
  String get duressPwHint => tr(
      'WARNING: entering this password during decryption PERMANENTLY DESTROYS the encrypted file. Irreversible!',
      '警告：解密时输入此密码将永久销毁整个加密文件，不可恢复！',
      'ATTENTION : saisir ce mot de passe lors du déchiffrement DÉTRUIT DÉFINITIVEMENT le fichier chiffré. Irréversible !',
      'WARNUNG: Die Eingabe dieses Passworts beim Entschlüsseln ZERSTÖRT die verschlüsselte Datei DAUERHAFT. Unumkehrbar!',
      '警報：解碼時入密口尼㑹永久毁㐌碼化之集信。空得返！');

  String get shredSection => tr(
      'Secure Shred', '安全擦除', 'Effacement sécurisé', 'Sicheres Löschen', '安除');
  String get shredOption => tr(
      'Shred original after encryption',
      '加密后安全擦除原文件',
      'Effacer l\'original après chiffrement',
      'Original nach dem Verschlüsseln sicher löschen',
      '碼化後安除原集信');
  String get shredHint => tr(
      'Best-effort: overwrite the original with one pass of random data, then delete it. On SSDs, snapshots and copy-on-write filesystems the physical blocks cannot be guaranteed overwritten - encryption is the real protection. Runs only after the output is verified.',
      '尽力而为：用随机数据单遍覆写原文件后再删除。在 SSD、快照与写时复制文件系统上，无法保证覆写到原始物理块——真正的保护是加密本身。仅在加密产物校验通过后执行。',
      'Au mieux : écrasement de l\'original en une passe de données aléatoires, puis suppression. Sur les SSD, les instantanés et les systèmes de fichiers copy-on-write, les blocs physiques ne sont pas garantis — le chiffrement reste la vraie protection. Ne s\'exécute qu\'après vérification de la sortie.',
      'Bestmöglich: einmaliges Überschreiben mit Zufallsdaten, dann Löschen. Auf SSDs, Snapshots und Copy-on-Write-Dateisystemen sind die physischen Blöcke nicht garantiert überschrieben – der echte Schutz ist die Verschlüsselung. Läuft nur nach verifizierter Ausgabe.',
      '盡力：用隨機資料沛遍覆寫原集信後再除。於 SSD、快照吧系統集信 copy-on-write，空保覆寫至塊物理元——保護真仍固碼化自體。只於出頭㐌確認後行。');

  String get optionalHint => tr('Leave empty to disable', '留空则不启用',
      'Laisser vide pour désactiver', 'Leer lassen zum Deaktivieren', '留空朱停');

  // ---- v2.5.0 (M7): V3 recipient mode has no deniability features ----
  String get recipientDeniabilityNote => tr(
      'Recipient mode (V3) has no decoy partition and no duress password. If you need deniability, encrypt with a password only.',
      '公钥模式（V3）不支持伪装分区与胁迫密码。如需可否认性，请仅用密码加密。',
      'Le mode destinataire (V3) n\'a ni partition leurre ni mot de passe de contrainte. Pour la déniabilité, chiffrez uniquement par mot de passe.',
      'Der Empfängermodus (V3) hat weder Täuschungspartition noch Zwangspasswort. Für Abstreitbarkeit nur mit Passwort verschlüsseln.',
      '格認（V3）空固分區偽吧密口脅。如需可認，請只碼化沛密口。');

  // ---- Recipient public key / hybrid mode (v1.6.0) ----
  String get recipientSection => tr(
      'Encrypt to a Public Key (ML-KEM-768)',
      '使用公钥加密（ML-KEM-768）',
      'Chiffrer vers une clé publique (ML-KEM-768)',
      'Mit öffentlichem Schlüssel verschlüsseln (ML-KEM-768)',
      '用鎖公開碼化（ML-KEM-768）');
  String get recipientHint => tr(
      'Post-quantum recipient encryption. With a recipient key the password becomes optional - leave it empty for key-only files.',
      '后量子收件人加密。选择公钥后密码变为可选——留空即生成仅限私钥解开的文件。',
      'Chiffrement post-quantique du destinataire. Avec une clé de destinataire, le mot de passe devient optionnel — laissez vide pour des fichiers à clé seule.',
      'Post-Quanten-Empfängerverschlüsselung. Mit einem Empfängerschlüssel wird das Passwort optional – leer lassen für Nur-Schlüssel-Dateien.',
      '後量子𠊛認碼化。固𠊛認鎖時密口變為隨選——留空朱成只固鎖之集信。');
  String get recipientPickBtn => tr('Choose .vctpub', '选择 .vctpub',
      'Choisir .vctpub', '.vctpub wählen', '選 .vctpub');
  String get recipientNone => tr('No recipient selected', '未选择收件人',
      'Aucun destinataire sélectionné', 'Kein Empfänger ausgewählt', '未選𠊛認');
  String get recipientClear => tr('Clear', '清除', 'Effacer', 'Leeren', '清除');
  String get recipientUseKey => tr(
      'Encrypt to this public key (password becomes optional)',
      '用此公钥加密（密码变为可选）',
      'Chiffrer avec cette clé publique (mot de passe optionnel)',
      'Mit diesem öffentlichen Schlüssel verschlüsseln (Passwort optional)',
      '用鎖公開尼碼化（密口變為隨選）');
  String get hybridPwOptional => tr(
      'Password is optional now: with a password the file opens with EITHER the password or the private key; without it, ONLY the private key works.',
      '密码现在是可选的：填写密码时，密码或私钥都能解开文件；留空则只有私钥能解开。',
      'Le mot de passe est désormais optionnel : avec un mot de passe, le fichier s\'ouvre AVEC le mot de passe OU la clé privée ; sans lui, seule la clé privée fonctionne.',
      'Das Passwort ist jetzt optional: mit Passwort öffnet die Datei mit EITHER Passwort ODER privatem Schlüssel; ohne Passwort funktioniert NUR der private Schlüssel.',
      '密口現羅隨選：固密口時，集信得開以密口或鎖私；空固時，只鎖私得。');
  String get hybridAdvancedDisabled => tr(
      'The decoy partition and duress password are unavailable when encrypting to a public key.',
      '使用公钥加密时，伪装分区与胁迫密码不可用。',
      'La partition leurre et le mot de passe de contrainte ne sont pas disponibles lors du chiffrement vers une clé publique.',
      'Täuschungspartition und Zwangs-Passwort sind beim Verschlüsseln mit einem öffentlichen Schlüssel nicht verfügbar.',
      '用鎖公開碼化時，偽裝分區與脅迫密口空得用。');
  String get errHybridAdvanced => tr(
      'Decoy / duress options cannot be combined with a recipient key. Clear them or remove the recipient.',
      '伪装/胁迫选项不能与收件人公钥同时使用，请清除其一。',
      'Les options leurre / contrainte ne peuvent pas être combinées avec une clé de destinataire. Effacez-les ou retirez le destinataire.',
      'Täuschungs-/Zwangsoptionen können nicht mit einem Empfängerschlüssel kombiniert werden. Leeren Sie sie oder entfernen Sie den Empfänger.',
      '偽 / 脅選項空得併用𠊛認鎖，請清除其一或除𠊛認。');
  String get errRecipientRequired => tr(
      'Select a valid .vctpub recipient key or turn the option off.',
      '请选择有效的 .vctpub 公钥，或关闭该选项。',
      'Sélectionnez une clé .vctpub valide ou désactivez cette option.',
      'Wählen Sie einen gültigen .vctpub-Empfängerschlüssel oder deaktivieren Sie die Option.',
      '請選合例之 .vctpub 鎖公開，或停選項尼。');
  String get resultKemUsed => tr('ML-KEM recipient', 'ML-KEM 收件人',
      'Destinataire ML-KEM', 'ML-KEM-Empfänger', 'ML-KEM 𠊛認');

  // ---- Decrypt with private key (v1.6.0) ----
  String get keyUnlockSection => tr(
      'Unlock with Private Key',
      '使用私钥解锁',
      'Déverrouiller avec la clé privée',
      'Mit privatem Schlüssel entsperren',
      '用鎖私開鎖');
  String get keyFileLabel => tr(
      'Private key file (.vctkey)',
      '私钥文件（.vctkey）',
      'Fichier de clé privée (.vctkey)',
      'Datei des privaten Schlüssels (.vctkey)',
      '鎖私集信（.vctkey）');
  String get keyFilePickHint => tr(
      'Pick the .vctkey file and enter its password',
      '选择 .vctkey 文件并输入其保护密码',
      'Choisissez le fichier .vctkey et saisissez son mot de passe',
      'Wählen Sie die .vctkey-Datei und geben Sie ihr Passwort ein',
      '選 .vctkey 集信並入主它密口');
  String get keyUnlockBtn => tr('Decrypt with Key', '用私钥解密',
      'Déchiffrer avec la clé', 'Mit Schlüssel entschlüsseln', '用鎖解碼');
  String keyReady(String name) => tr(
      'Private key loaded: $name',
      '私钥已加载：$name',
      'Clé privée chargée : $name',
      'Privater Schlüssel geladen: $name',
      '㐌載鎖私：$name');
  String get v3KeyChannelHint => tr(
      'This file carries an ML-KEM recipient channel - it can be opened with the recipient private key.',
      '此文件包含 ML-KEM 收件人通道，可用收件人私钥解开。',
      'Ce fichier comporte un canal destinataire ML-KEM — il peut être ouvert avec la clé privée du destinataire.',
      'Diese Datei hat einen ML-KEM-Empfängerkanal – sie kann mit dem privaten Empfängerschlüssel geöffnet werden.',
      '集信尼含 ML-KEM 𠊛認通道——得用𠊛認鎖私開。');
  String get v3PasswordOnlyHint => tr(
      'This file has no password channel - only the recipient private key can open it.',
      '此文件没有密码通道，只能用收件人私钥解开。',
      'Ce fichier n\'a pas de canal mot de passe — seule la clé privée du destinataire peut l\'ouvrir.',
      'Diese Datei hat keinen Passwortkanal – nur der private Empfängerschlüssel kann sie öffnen.',
      '集信尼空固密口通道——只𠊛認鎖私得開。');

  // ---- Decrypt screen ----
  String get decryptTitle => tr('Decrypt .VCT File', '解密 .VCT 文件',
      'Déchiffrer un fichier .VCT', '.VCT-Datei entschlüsseln', '解碼 .VCT 集信');
  String get decryptSubtitle => tr(
      'Restore your encrypted files',
      '恢复已加密的文件',
      'Restaurez vos fichiers chiffrés',
      'Stellen Sie Ihre verschlüsselten Dateien wieder her',
      '復原主伴㐌碼化之集信');
  String get selectVctFile => tr(
      'Tap to select a .VCT file',
      '点击选择 .VCT 文件',
      'Touchez pour sélectionner un fichier .VCT',
      'Zum Auswählen einer .VCT-Datei tippen',
      '按以選 .VCT 集信');

  // ---- Progress messages ----
  String get statusDeriving => tr(
      'Deriving keys (PBKDF2, 600K iterations)...',
      '派生密钥 (PBKDF2, 60万次迭代)...',
      'Dérivation des clés (PBKDF2, 600 000 itérations)...',
      'Schlüssel werden abgeleitet (PBKDF2, 600.000 Iterationen)...',
      '當引出鎖（PBKDF2，60萬次迭代）...');
  String get statusEncrypting => tr(
      'Encrypting (3-layer AES-256-GCM)...',
      '加密中 (三层 AES-256-GCM)...',
      'Chiffrement (AES-256-GCM à 3 couches)...',
      'Verschlüsseln (3-Schicht-AES-256-GCM)...',
      '當碼化（三層 AES-256-GCM）...');
  String get statusEncryptingDecoy => tr(
      'Encrypting decoy partition...',
      '正在加密伪装分区...',
      'Chiffrement de la partition leurre...',
      'Täuschungspartition wird verschlüsselt...',
      '當碼化偽裝分區...');
  String get statusShredding => tr(
      'Securely shredding original file...',
      '正在安全擦除原文件...',
      'Effacement sécurisé du fichier original...',
      'Originaldatei wird sicher gelöscht...',
      '當安除原集信...');
  String get statusVerifying => tr(
      'Verifying password...',
      '验证密码...',
      'Vérification du mot de passe...',
      'Passwort wird verifiziert...',
      '當確認密口...');
  String get statusVerified => tr('Password verified.', '密码验证通过。',
      'Mot de passe vérifié.', 'Passwort verifiziert.', '密口㐌確認。');
  String get statusDecrypting => tr(
      'Decrypting (3-layer AES-256-GCM)...',
      '解密中 (三层 AES-256-GCM)...',
      'Déchiffrement (AES-256-GCM à 3 couches)...',
      'Entschlüsseln (3-Schicht-AES-256-GCM)...',
      '當解碼（三層 AES-256-GCM）...');
  String get statusProcessing => tr(
      'Processing... Please wait.',
      '处理中... 请稍候。',
      'Traitement... Veuillez patienter.',
      'Verarbeitung... Bitte warten.',
      '當處理... 請待。');
  String get statusReady => tr('Ready.', '就绪。', 'Prêt.', 'Bereit.', '就緒。');

  // ---- Success ----
  String get encSuccess => tr('Encryption complete!', '加密完成！',
      'Chiffrement terminé !', 'Verschlüsselung abgeschlossen!', '碼化完！');
  String get decSuccess => tr('Decryption complete!', '解密完成！',
      'Déchiffrement terminé !', 'Entschlüsselung abgeschlossen!', '解碼完！');
  String get outputFile => tr('Output', '输出', 'Sortie', 'Ausgabe', '出頭');
  String get originalFile =>
      tr('Original file', '原始文件', 'Fichier original', 'Originaldatei', '原集信');
  String get mobileOutputHint => tr(
      'Saved to the VCTCrypt folder - open the Files app to find it.',
      '已保存到 VCTCrypt 文件夹，请打开系统“文件”App 查看。',
      'Enregistré dans le dossier VCTCrypt — ouvrez l\'app Fichiers pour le trouver.',
      'Im VCTCrypt-Ordner gespeichert – öffnen Sie die Dateien-App, um sie zu finden.',
      '㐌留入 VCTCrypt 書目——開「集信」App 尋。');
  String get mobileEncHint => tr(
      'The .VCT file is saved to the VCTCrypt folder - open the Files app to find it.',
      '加密产物已保存到 VCTCrypt 文件夹，请打开系统“文件”App 查看。',
      'Le fichier .VCT est enregistré dans le dossier VCTCrypt — ouvrez l\'app Fichiers pour le trouver.',
      'Die .VCT-Datei ist im VCTCrypt-Ordner gespeichert – öffnen Sie die Dateien-App, um sie zu finden.',
      '.VCT 集信㐌留入 VCTCrypt 書目——開「集信」App 尋。');
  String get fileSize => tr('Size', '大小', 'Taille', 'Größe', '容量');
  String get bytes => tr('bytes', '字节', 'octets', 'Bytes', '字節');
  String get resultDecoyUsed => tr('Decoy partition enabled', '已启用伪装分区',
      'Partition leurre activée', 'Täuschungspartition aktiviert', '㐌開偽裝分區');
  String get resultDuressUsed => tr(
      'Duress wipe enabled',
      '已启用胁迫销毁',
      'Destruction sous contrainte activée',
      'Zwangs-Löschung aktiviert',
      '㐌開脅迫除');
  String get resultShredded => tr(
      'Original file securely shredded.',
      '原文件已安全擦除。',
      'Fichier original effacé de façon sécurisée.',
      'Originaldatei sicher gelöscht.',
      '原集信㐌得安除。');

  // ---- Errors ----
  String get errRead => tr(
      'Cannot read file.',
      '无法读取文件。',
      'Impossible de lire le fichier.',
      'Datei kann nicht gelesen werden.',
      '空得讀集信。');
  String get errEmpty => tr('File is empty.', '文件为空。', 'Le fichier est vide.',
      'Die Datei ist leer.', '集信空。');
  String get errKeyFail => tr(
      'Key derivation failed.',
      '密钥派生失败。',
      'Échec de la dérivation de clé.',
      'Schlüsselableitung fehlgeschlagen.',
      '引出鎖失敗。');
  String get errL1 => tr(
      'Layer 1 encryption failed.',
      '第1层加密失败。',
      'Échec du chiffrement de la couche 1.',
      'Schicht-1-Verschlüsselung fehlgeschlagen.',
      '第一層碼化失敗。');
  String get errL2 => tr(
      'Layer 2 encryption failed.',
      '第2层加密失败。',
      'Échec du chiffrement de la couche 2.',
      'Schicht-2-Verschlüsselung fehlgeschlagen.',
      '第二層碼化失敗。');
  String get errL3 => tr(
      'Layer 3 encryption failed.',
      '第3层加密失败。',
      'Échec du chiffrement de la couche 3.',
      'Schicht-3-Verschlüsselung fehlgeschlagen.',
      '第三層碼化失敗。');
  String get errNotVct => tr('Not a valid VCT file.', '不是有效的 VCT 文件。',
      'Fichier VCT non valide.', 'Keine gültige VCT-Datei.', '空沛合例 VCT 集信。');
  String get errSmall => tr(
      'File too small or corrupted.',
      '文件过小或已损坏。',
      'Fichier trop petit ou corrompu.',
      'Datei zu klein oder beschädigt.',
      '集信過小或已壞。');
  String get errCorrupt => tr('Data corrupted.', '数据损坏。', 'Données corrompues.',
      'Daten beschädigt.', '資料已壞。');
  String get errPayload => tr('Corrupted payload data.', '负载数据损坏。',
      'Données utiles corrompues.', 'Nutzlastdaten beschädigt.', '載資料已壞。');
  // v2.5.0 (M2): the whole file is held in memory (peak ~6x), so there is a
  // hard ceiling instead of a silent OOM kill.
  String get errFileTooLarge => tr(
      'File is too large (limit 64 MB). Split or compress it before encrypting.',
      '文件超过 64 MB 上限，请分卷或压缩后再加密。',
      'Fichier trop volumineux (limite 64 Mo). Divisez-le ou compressez-le avant de chiffrer.',
      'Datei zu groß (Grenze 64 MB). Teilen oder komprimieren Sie sie vor dem Verschlüsseln.',
      '集信過大（限 64 MB）。請分卷或壓縮後再碼化。');
  String get errWrite => tr(
      'Cannot write output file.',
      '无法写入输出文件。',
      'Impossible d\'écrire le fichier de sortie.',
      'Ausgabedatei kann nicht geschrieben werden.',
      '空得寫出頭集信。');
  String get errNotFound => tr('File not found.', '文件未找到。',
      'Fichier introuvable.', 'Datei nicht gefunden.', '空尋得集信。');
  String get errDir => tr(
      'Directories are not supported.',
      '不支持目录。',
      'Les dossiers ne sont pas pris en charge.',
      'Verzeichnisse werden nicht unterstützt.',
      '空扶助書目。');
  String get errPwShort => tr(
      'Password too short (min 4 characters).',
      '密码太短（至少4个字符）。',
      'Mot de passe trop court (4 caractères min.).',
      'Passwort zu kurz (mind. 4 Zeichen).',
      '密口過短（最少4字符）。');
  String get errPwMismatch => tr(
      'Passwords do not match.',
      '两次密码不一致。',
      'Les mots de passe ne correspondent pas.',
      'Die Passwörter stimmen nicht überein.',
      '兩密口空合。');
  String get errWrongPw => tr(
      'Wrong password or file corrupted.',
      '密码错误或文件已损坏。',
      'Mot de passe incorrect ou fichier corrompu.',
      'Falsches Passwort oder Datei beschädigt.',
      '密口差或集信已壞。');
  String get errDecoyPwIdentical => tr(
      'Decoy password must differ from the main password.',
      '伪装密码不能与主密码相同。',
      'Le mot de passe leurre doit différer du mot de passe principal.',
      'Das Täuschungspasswort muss sich vom Hauptpasswort unterscheiden.',
      '偽密口沛異主密口。');
  String get errDuressPwIdentical => tr(
      'Duress password must differ from the main and decoy passwords.',
      '胁迫密码不能与主密码或伪装密码相同。',
      'Le mot de passe de contrainte doit différer des mots de passe principal et leurre.',
      'Das Zwangs-Passwort muss sich vom Haupt- und Täuschungspasswort unterscheiden.',
      '脅迫密口沛異主密口與偽密口。');
  String get errDecoyFileMissing => tr(
      'Please select a decoy file.',
      '请选择伪装文件。',
      'Veuillez sélectionner un fichier leurre.',
      'Bitte wählen Sie eine Täuschungsdatei.',
      '請選偽集信。');
  String get errDecoyPwRequired => tr(
      'A decoy file was selected - set a decoy password too.',
      '已选择伪装文件，请同时设置伪装密码。',
      'Un fichier leurre a été sélectionné — définissez aussi un mot de passe leurre.',
      'Eine Täuschungsdatei wurde gewählt – legen Sie auch ein Täuschungspasswort fest.',
      '㐌選偽集信——請並設偽密口。');
  String get errDecoyFileEmpty => tr('Decoy file is empty.', '伪装文件为空。',
      'Le fichier leurre est vide.', 'Die Täuschungsdatei ist leer.', '偽集信空。');
  String get errShredVerify => tr(
      'Output verification failed - original file was NOT shredded.',
      '加密产物校验失败，原文件未被擦除。',
      'Échec de la vérification de la sortie — le fichier original n\'a PAS été effacé.',
      'Ausgabeprüfung fehlgeschlagen – die Originaldatei wurde NICHT gelöscht.',
      '出頭確認失敗——原集信未被除。');

  // ---- Key / hybrid errors (v1.6.0) ----
  String get errBadKeyFile => tr(
      'Not a valid VCTCrypt key file.',
      '不是有效的 VCTCrypt 密钥文件。',
      'Fichier de clé VCTCrypt non valide.',
      'Keine gültige VCTCrypt-Schlüsseldatei.',
      '空沛合例 VCTCrypt 鎖集信。');
  String get errWrongKeyPassword => tr(
      'Wrong private-key password.',
      '私钥保护密码错误。',
      'Mot de passe de clé privée incorrect.',
      'Falsches Passwort des privaten Schlüssels.',
      '鎖私密口差。');
  String get errUnsupportedKeyParams => tr(
      'Unsupported key parameters.',
      '不支持的密钥参数。',
      'Paramètres de clé non pris en charge.',
      'Nicht unterstützte Schlüsselparameter.',
      '鎖參數不受扶助。');
  String get errKeyRequired => tr(
      'This file needs the recipient private key (.vctkey) - it has no password channel.',
      '此文件需要收件人私钥（.vctkey）才能解开——它没有密码通道。',
      'Ce fichier nécessite la clé privée du destinataire (.vctkey) — il n\'a pas de canal mot de passe.',
      'Diese Datei benötigt den privaten Empfängerschlüssel (.vctkey) – sie hat keinen Passwortkanal.',
      '集信尼需𠊛認鎖私（.vctkey）——它空固密口通道。');
  String get errWrongKey => tr(
      'This private key does not match the file.',
      '此私钥与文件不匹配。',
      'Cette clé privée ne correspond pas au fichier.',
      'Dieser private Schlüssel passt nicht zur Datei.',
      '鎖私尼與集信空合。');
  String get errKeyNotApplicable => tr(
      'A private key cannot open this file - use the password instead.',
      '私钥无法解开此文件，请使用密码。',
      'Une clé privée ne peut pas ouvrir ce fichier — utilisez le mot de passe.',
      'Ein privater Schlüssel kann diese Datei nicht öffnen – verwenden Sie das Passwort.',
      '鎖私空得開集信尼——請用密口。');
  String get errNoChannel => tr(
      'Nothing can open this file: no password and no recipient key.',
      '此文件无法解开：既没有密码也没有收件人密钥。',
      'Rien ne peut ouvrir ce fichier : ni mot de passe ni clé de destinataire.',
      'Nichts kann diese Datei öffnen: weder Passwort noch Empfängerschlüssel.',
      '空物得開集信尼：空密口吧空𠊛認鎖。');

  // ---- Settings ----
  String get settingsTitle =>
      tr('Settings', '设置', 'Réglages', 'Einstellungen', '設置');
  String get languageSection => tr('Language', '语言', 'Langue', 'Sprache', '言語');
  String get themeSection => tr('Theme', '主题', 'Thème', 'Design', '主題');
  String get themeLight => tr('Light', '浅色', 'Clair', 'Hell', '明');
  String get themeDark => tr('Dark', '深色', 'Sombre', 'Dunkel', '暗');
  String get themeSystem => tr('System', '跟随系统', 'Système', 'System', '隨系統');
  String get securitySection =>
      tr('Security', '安全', 'Sécurité', 'Sicherheit', '保密');
  String get autoLockLabel => tr('Auto-lock', '自动锁定',
      'Verrouillage automatique', 'Automatische Sperre', '自鎖');
  String get autoLockHint => tr(
      'Clears entered passwords after a period of inactivity.',
      '空闲一段时间后自动清空已输入的密码。',
      'Efface les mots de passe saisis après une période d\'inactivité.',
      'Leert eingegebene Passwörter nach einer Zeit der Inaktivität.',
      '空活動一段時間後自清已入之密口。');
  String get autoLockOff => tr('Off', '关闭', 'Désactivé', 'Aus', '停');
  String autoLockMinutes(int n) =>
      tr('$n min', '$n 分钟', '$n min', '$n Min.', '$n 分');
  // ---- Other section entries (v2.0.0) ----
  String get otherSection => tr('Other', '其它', 'Autres', 'Sonstiges', '別');
  String get aboutEntry => tr('About', '关于', 'À propos', 'Über', '介紹');
  String get donateEntry => tr('Donate', '捐赠', 'Faire un don', 'Spenden', '擁護');
  String get policyEntry => tr('Policies & Terms', '政策与条款',
      'Politique & Conditions', 'Richtlinien & Bedingungen', '政策與條款');
  String get changelogEntry => tr(
      'Changelog', '更新日志', 'Journal des versions', 'Änderungsprotokoll', '更新誌');

  // ---- About screen (v2.0.0) ----
  String get aboutTitle => tr('About', '关于', 'À propos', 'Über', '介紹');
  String get aboutWebsite => tr('Website', '官网', 'Site web', 'Website', '網頁');
  String get aboutLicense => tr('License', '协议', 'Licence', 'Lizenz', '許可');
  String get aboutLicenseValue => tr(
      'AGPL-3.0 License - free, open source, no ads',
      'AGPL-3.0 开源协议——免费、开源、无广告',
      'Licence AGPL-3.0 — gratuit, open source, sans publicité',
      'AGPL-3.0-Lizenz – kostenlos, Open Source, werbefrei',
      'AGPL-3.0 開源許可——免費、開源、無廣告');
  String get aboutLocalNote => tr(
      'VCTCrypt runs fully offline: no telemetry, no analytics, no ads. All encryption and decryption happens 100% on your device.',
      'VCTCrypt 完全离线运行：无遥测、无分析、无广告。所有加解密运算 100% 在你的设备上完成。',
      'VCTCrypt fonctionne entièrement hors ligne : aucune télémétrie, aucune analyse, aucune publicité. Tout le chiffrement et le déchiffrement se fait à 100 % sur votre appareil.',
      'VCTCrypt läuft vollständig offline: keine Telemetrie, keine Analyse, keine Werbung. Die gesamte Ver- und Entschlüsselung erfolgt zu 100 % auf Ihrem Gerät.',
      'VCTCrypt 完全離線行：無遙測、無分析、無廣告。每碼化吧解碼 100% 於主伴設備。');
  String get copyBtn => tr('Copy', '复制', 'Copier', 'Kopieren', '抄');
  String get websiteCopied => tr('Website address copied', '官网地址已复制',
      'Adresse du site copiée', 'Website-Adresse kopiert', '㐌抄網頁址');

  // ---- Donate screen (v2.0.0) ----
  String get donateTitle => tr('Donate', '捐赠', 'Faire un don', 'Spenden', '擁護');
  String get donateIntro => tr(
      'VCTCrypt is free, open-source and ad-free. Donate to support development.',
      'VCTCrypt 免费开源无广告，捐赠以支持开发。',
      'VCTCrypt est gratuit, open source et sans publicité. Faites un don pour soutenir le développement.',
      'VCTCrypt ist kostenlos, Open Source und werbefrei. Spenden Sie, um die Entwicklung zu unterstützen.',
      'VCTCrypt 免費開源無廣告，擁護以支持開發。');
  String get donateQrLabel => tr('Alipay donation QR code', '支付宝捐赠收款码',
      'QR code de don Alipay', 'Alipay-Spenden-QR-Code', '支付寶擁護碼 QR');
  String get donateScanHint => tr('Scan with Alipay', '使用支付宝扫码',
      'Scannez avec Alipay', 'Mit Alipay scannen', '用支付寶掃');
  String get donateThanks => tr(
      'Every donation keeps the project going - thank you!',
      '每一份捐赠都是持续开发的动力——谢谢你！',
      'Chaque don fait avancer le projet — merci !',
      'Jede Spende hält das Projekt am Laufen – danke!',
      '每份擁護都助力案繼續——多謝！');
  String get donateShareQr => tr('Share / Save QR', '分享 / 存储收款码',
      'Partager / Enregistrer le QR', 'QR teilen / speichern', '分 / 留碼 QR');

  // ---- Policies & Terms screen (v2.0.0) ----
  String get policyTitle => tr('Policies & Terms', '政策与条款',
      'Politique & Conditions', 'Richtlinien & Bedingungen', '政策與條款');
  String get policyPrivacyTab => tr('Privacy Policy', '隐私政策',
      'Politique de confidentialité', 'Datenschutzrichtlinie', '隱私政策');
  String get policyTermsTab => tr('Terms of Use', '使用条款',
      'Conditions d\'utilisation', 'Nutzungsbedingungen', '使用條款');

  // ---- Changelog screen (v2.0.0) ----
  String get changelogTitle => tr(
      'Changelog', '更新日志', 'Journal des versions', 'Änderungsprotokoll', '更新誌');

  // ---- About facts (shared by the About card & screen) ----
  String get aboutAuthor => tr('Author', '作者', 'Auteur', 'Autor', '作者');
  String get aboutAlgo =>
      tr('Algorithm', '算法', 'Algorithme', 'Algorithmus', '算法');
  String get aboutAlgoValue => tr(
      'VCT-Crypt v1.2\nTriple AES-256-GCM + PBKDF2\n600,000 iterations\n+ Decoy / Duress partitions\n+ ML-KEM-768 hybrid (FIPS 203)',
      'VCT-Crypt v1.2\n三层 AES-256-GCM + PBKDF2\n60万次迭代\n+ 伪装分区 / 胁迫销毁\n+ ML-KEM-768 混合加密（FIPS 203）',
      'VCT-Crypt v1.2\nTriple AES-256-GCM + PBKDF2\n600 000 itérations\n+ Partitions leurre / contrainte\n+ Hybride ML-KEM-768 (FIPS 203)',
      'VCT-Crypt v1.2\nDreifach AES-256-GCM + PBKDF2\n600.000 Iterationen\n+ Täuschungs-/Zwangs-Partitionen\n+ ML-KEM-768 Hybrid (FIPS 203)',
      'VCT-Crypt v1.2\n三層 AES-256-GCM + PBKDF2\n60萬次迭代\n+ 偽裝分區 / 脅迫除\n+ ML-KEM-768 混合碼化（FIPS 203）');

  // ---- Misc ----
  String get passwordStrengthWeak => tr('Weak', '弱', 'Faible', 'Schwach', '弱');
  String get passwordStrengthMedium =>
      tr('Medium', '中等', 'Moyen', 'Mittel', '中');
  String get passwordStrengthStrong => tr('Strong', '强', 'Fort', 'Stark', '強');
  String get noFileSelected => tr('No file selected', '未选择文件',
      'Aucun fichier sélectionné', 'Keine Datei ausgewählt', '未選集信');
  String get fileSelected =>
      tr('Selected', '已选择', 'Sélectionné', 'Ausgewählt', '㐌選');
  String get dialogOk => tr('OK', '好', 'OK', 'OK', '得');

  // ---- Password generator (v1.2.0) ----
  String get generatorTitle => tr('Password Generator', '密码生成器',
      'Générateur de mots de passe', 'Passwortgenerator', '密口生器');
  String get genLength => tr('Length', '长度', 'Longueur', 'Länge', '長度');
  String get genCopy => tr('Copy to clipboard', '复制到剪贴板',
      'Copier dans le presse-papiers', 'In Zwischenablage kopieren', '抄入板暫');
  String get genCopied => tr('Copied to clipboard', '已复制到剪贴板',
      'Copié dans le presse-papiers', 'In Zwischenablage kopiert', '㐌抄入板暫');
  String get genUse => tr('Use this password', '使用此密码',
      'Utiliser ce mot de passe', 'Dieses Passwort verwenden', '用密口尼');
  String get genRegenerate =>
      tr('Regenerate', '重新生成', 'Régénérer', 'Neu generieren', '造來');
  String genEntropy(int bits) => tr('~$bits bits of strength', '密码强度约 $bits 位',
      '~$bits bits de robustesse', '~$bits Bit Stärke', '強度約 $bits 位');
  String get genQualityExcellent =>
      tr('Excellent', '极强', 'Excellent', 'Ausgezeichnet', '絕妙');
  String get genExcludeAmbiguous =>
      tr('No 0O1lI', '排除 0O1lI', 'Sans 0O1lI', 'Ohne 0O1lI', '除 0O1lI');
  String get genNoClassError => tr(
      'Select at least one character type.',
      '请至少选择一种字符类型。',
      'Sélectionnez au moins un type de caractères.',
      'Wählen Sie mindestens einen Zeichentyp.',
      '請至少選一種字符類。');
  String get genApplied => tr('Password generated', '已生成密码',
      'Mot de passe généré', 'Passwort generiert', '㐌生密口');

  // ---- File inspector (v1.2.0) ----
  String get inspectTitle => tr('File Info', '文件信息',
      'Informations sur le fichier', 'Dateiinformationen', '集信信息');
  String get infoFileName =>
      tr('File name', '文件名', 'Nom du fichier', 'Dateiname', '集信名');
  String get infoFormat => tr('Format', '格式', 'Format', 'Format', '格式');
  String get infoFormatV1 => tr(
      'V1 (classic)', 'V1（经典格式）', 'V1 (classique)', 'V1 (klassisch)', 'V1（舊式）');
  String get infoFormatV2 => tr('V2 (advanced slots)', 'V2（支持高级分区）',
      'V2 (partitions avancées)', 'V2 (erweiterte Partitionen)', 'V2（高級分區）');
  String get infoFormatV3 => tr('V3 (ML-KEM hybrid)', 'V3（ML-KEM 混合格式）',
      'V3 (hybride ML-KEM)', 'V3 (ML-KEM-Hybrid)', 'V3（ML-KEM 混式）');
  String get infoChannelPassword => tr('Password channel', '密码通道',
      'Canal mot de passe', 'Passwortkanal', '密口通道');
  String get infoChannelKem => tr('ML-KEM recipient channel', 'ML-KEM 收件人通道',
      'Canal destinataire ML-KEM', 'ML-KEM-Empfängerkanal', 'ML-KEM 𠊛認通道');
  String get infoYes => tr('yes', '有', 'oui', 'ja', '固');
  String get infoNo => tr('no', '无', 'non', 'nein', '空');
  String get infoFormatInvalid => tr('Not a VCT file', '不是 VCT 文件',
      'Pas un fichier VCT', 'Keine VCT-Datei', '空沛 VCT 集信');
  String get infoFileSize =>
      tr('File size', '文件大小', 'Taille du fichier', 'Dateigröße', '集信容量');
  String get infoPayload => tr('Encrypted payload', '加密数据', 'Données chiffrées',
      'Verschlüsselte Nutzdaten', '㐌碼化資料');
  String get infoHeader => tr('Header size (bytes)', '头部大小（字节）',
      'Taille de l\'en-tête (octets)', 'Headergröße (Bytes)', '頭部大小（字節）');
  String get infoAlgo => tr('Cipher', '加密算法', 'Chiffrement', 'Chiffre', '碼化算法');
  String get infoKdf => tr('Key derivation', '密钥派生', 'Dérivation de clé',
      'Schlüsselableitung', '引出鎖');
  String get infoKdfValue => 'PBKDF2-SHA256 · 600K';
  String get infoModified => tr('Last modified', '修改时间',
      'Dernière modification', 'Zuletzt geändert', '改時');
  String get infoDeniableNote => tr(
      'V2 files always contain all advanced slots. It is impossible to tell from this file whether a decoy or duress password is set - that is by design.',
      'V2 文件始终包含全部高级分区。仅凭此文件无法判断是否设置了伪装或胁迫密码——这是有意为之的设计。',
      'Les fichiers V2 contiennent toujours toutes les partitions avancées. Il est impossible de savoir depuis ce fichier si un mot de passe leurre ou de contrainte est défini — c\'est voulu.',
      'V2-Dateien enthalten immer alle erweiterten Partitionen. Anhand dieser Datei ist nicht erkennbar, ob ein Täuschungs- oder Zwangs-Passwort gesetzt ist – das ist beabsichtigt.',
      'V2 集信常含每高級分區。空得從集信尼知固設偽或脅密口或空——底羅有意設計。');

  // ---- Checksum / Hash (v2.3.0) ----
  String get hashTitle => tr('Checksum (SHA)', '哈希校验（SHA）',
      'Somme de contrôle (SHA)', 'Prüfsumme (SHA)', '碼檢查（SHA）');
  String get hashSubtitle => tr(
      'Compute SHA-256 / SHA-512 / SHA-3-256 of any file - streamed, so huge files work too - and compare it against an expected checksum.',
      '计算任意文件的 SHA-256 / SHA-512 / SHA-3-256 校验和（流式计算，大文件也没问题），并与预期值比对验证完整性。',
      'Calculez la somme de contrôle SHA-256 / SHA-512 / SHA-3-256 de n\'importe quel fichier — en flux, donc même les gros fichiers — et comparez-la à une valeur attendue.',
      'Berechnen Sie die SHA-256 / SHA-512 / SHA-3-256-Prüfsumme jeder Datei — gestreamt, funktioniert also auch bei großen Dateien — und vergleichen Sie sie mit einem erwarteten Wert.',
      '算碼檢查 SHA-256 / SHA-512 / SHA-3-256 之丕集信——處理隨流，勢集信大共得用——吧比較與碼檢查期望。');
  String get hashEntry =>
      tr('Checksum', '哈希校验', 'Somme de contrôle', 'Prüfsumme', '碼檢查');
  String get hashAlgo =>
      tr('Algorithm', '算法', 'Algorithme', 'Algorithmus', '術算');
  String get hashCompute => tr('Compute', '开始计算', 'Calculer', 'Berechnen', '算');
  String get hashComputing =>
      tr('Hashing…', '正在计算…', 'Hachage…', 'Hashing…', '當算…');
  String get hashResult =>
      tr('checksum', '校验和', 'somme de contrôle', 'Prüfsumme', '碼檢查');
  String get hashCopy => tr('Copy', '复制', 'Copier', 'Kopieren', '抄');
  String get hashExpectedLabel => tr('Expected checksum', '预期校验和',
      'Somme attendue', 'Erwartete Prüfsumme', '碼檢查期望');
  String get hashExpectedHint => tr(
      'Paste the checksum you were given, then tap Compare',
      '粘贴收到的校验和，点击比对',
      'Collez la somme reçue, puis touchez Comparer',
      'Fügen Sie die erhaltene Prüfsumme ein und tippen Sie auf Vergleichen',
      '粘碼檢查伴得供，吧按比較');
  String get hashCompare =>
      tr('Compare', '比对', 'Comparer', 'Vergleichen', '比較');
  String get hashMatch => tr('Checksum matches', '校验和一致',
      'Somme de contrôle conforme', 'Prüfsumme stimmt überein', '碼檢查相符');
  String get hashMatchBody => tr(
      'The file is intact - it matches the expected checksum.',
      '文件完整，与预期校验和一致。',
      'Le fichier est intact — conforme à la somme attendue.',
      'Die Datei ist intakt — sie entspricht der erwarteten Prüfsumme.',
      '集信完好——它與碼檢查期望相符。');
  String get hashMismatch => tr('Checksum differs', '校验和不一致',
      'Somme de contrôle différente', 'Prüfsumme weicht ab', '碼檢查不相同');
  String get hashMismatchBody => tr(
      'The file does NOT match the expected checksum. It may be corrupted or tampered with.',
      '文件与预期校验和不一致，可能已损坏或被篡改。',
      'Le fichier ne correspond PAS à la somme attendue. Il est peut-être corrompu ou altéré.',
      'Die Datei entspricht NICHT der erwarteten Prüfsumme. Sie ist möglicherweise beschädigt oder manipuliert.',
      '集信不與碼檢查期望相符。它可能損壞或被篡改。');
  String get hashEmptyResult => tr(
      'Compute the checksum first',
      '请先计算校验和',
      'Calculez d\'abord la somme de contrôle',
      'Berechnen Sie zuerst die Prüfsumme',
      '先算碼檢查');
  String get hashNoExpected => tr(
      'Enter an expected checksum first',
      '请先输入预期校验和',
      'Saisissez d\'abord une somme attendue',
      'Geben Sie zuerst eine erwartete Prüfsumme ein',
      '先入碼檢查期望');

  // ---- Panic lock (v1.2.0) ----
  String get panicLock => tr(
      'Panic lock: clear all passwords now',
      '紧急锁定：立即清空所有密码',
      'Verrouillage d\'urgence : effacer tous les mots de passe',
      'Notfall-Sperre: alle Passwörter jetzt leeren',
      '急鎖：即清所有密口');
  String get panicLocked => tr('All passwords cleared.', '已清空所有密码。',
      'Tous les mots de passe effacés.', 'Alle Passwörter geleert.', '㐌清所有密口。');

  // ---- Usage statistics (v1.2.0) ----
  String get statsSection => tr('Usage Statistics', '使用统计',
      'Statistiques d\'utilisation', 'Nutzungsstatistik', '用統計');
  String get statsEncrypted => tr('Files encrypted', '已加密文件',
      'Fichiers chiffrés', 'Verschlüsselte Dateien', '㐌碼化集信');
  String get statsDecrypted => tr('Files decrypted', '已解密文件',
      'Fichiers déchiffrés', 'Entschlüsselte Dateien', '㐌解碼集信');
  String get statsDataEnc => tr('Data encrypted', '已加密数据量', 'Données chiffrées',
      'Verschlüsselte Daten', '㐌碼化資料');
  String get statsDataDec => tr('Data decrypted', '已解密数据量',
      'Données déchiffrées', 'Entschlüsselte Daten', '㐌解碼資料');
  String get statsDecoy => tr('Decoy partitions', '伪装分区', 'Partitions leurres',
      'Täuschungspartitionen', '偽裝分區');
  String get statsDuressArmed => tr('Duress traps armed', '胁迫陷阱',
      'Pièges de contrainte armés', 'Zwangs-Fallen aktiv', '脅迫阱已設');
  String get statsDuressTriggered => tr(
      'Duress wipes triggered',
      '胁迫销毁触发',
      'Destructions sous contrainte déclenchées',
      'Zwangs-Löschungen ausgelöst',
      '脅迫除已觸發');
  String get statsShredded => tr('Files shredded', '已擦除文件', 'Fichiers effacés',
      'Gelöschte Dateien', '㐌安除集信');
  String get statsEmpty => tr(
      'No operations recorded yet.',
      '暂无操作记录。',
      'Aucune opération enregistrée pour l\'instant.',
      'Noch keine Vorgänge erfasst.',
      '暫無操作記錄。');
  String get statsReset => tr('Reset statistics', '重置统计',
      'Réinitialiser les statistiques', 'Statistik zurücksetzen', '重置統計');
  String get statsResetConfirmTitle => tr('Reset statistics?', '重置统计？',
      'Réinitialiser les statistiques ?', 'Statistik zurücksetzen?', '重置統計？');
  String get statsResetConfirmBody => tr(
      'All counters will be cleared. This cannot be undone.',
      '所有计数将被清零，此操作不可撤销。',
      'Tous les compteurs seront remis à zéro. Cette action est irréversible.',
      'Alle Zähler werden zurückgesetzt. Dies kann nicht rückgängig gemacht werden.',
      '每計數㑹得清零，空得返。');
  String get statsPrivacyNote => tr(
      'Statistics are stored locally on this device only. No file names, passwords or paths are ever recorded.',
      '统计数据仅保存在本设备，不记录任何文件名、密码或路径。',
      'Les statistiques sont stockées uniquement sur cet appareil. Aucun nom de fichier, mot de passe ou chemin n\'est jamais enregistré.',
      'Statistiken werden nur auf diesem Gerät gespeichert. Es werden niemals Dateinamen, Passwörter oder Pfade erfasst.',
      '統計只存於設備尼。空包記集信名、密口或路徑。');

  // ---- Batch encryption (v1.3.0) ----
  String batchSelectedCount(int n) => tr('$n files selected', '已选择 $n 个文件',
      '$n fichiers sélectionnés', '$n Dateien ausgewählt', '㐌選 $n 個集信');
  String get batchDecoyDisabled => tr(
      'Batch mode: the decoy partition is unavailable here. Encrypt files one by one to use a decoy.',
      '批量模式：此处无法使用伪装分区，如需伪装请逐个加密。',
      'Mode lot : la partition leurre n\'est pas disponible ici. Chiffrez les fichiers un par un pour utiliser un leurre.',
      'Stapelmodus: Die Täuschungspartition ist hier nicht verfügbar. Verschlüsseln Sie Dateien einzeln, um eine Täuschung zu verwenden.',
      '批量式：此處空得用偽裝分區，如需偽請逐個碼化。');
  String get errDecoyBatch => tr(
      'The decoy partition is not available in batch mode.',
      '批量模式下无法使用伪装分区。',
      'La partition leurre n\'est pas disponible en mode lot.',
      'Die Täuschungspartition ist im Stapelmodus nicht verfügbar.',
      '批量式下空得用偽裝分區。');
  String batchEncrypting(int i, int n) => tr(
      'Encrypting $i of $n...',
      '正在加密 $i / $n...',
      'Chiffrement $i sur $n...',
      'Verschlüssele $i von $n...',
      '當碼化 $i / $n...');
  String batchAllOk(int n) => tr(
      'All $n files encrypted.',
      '全部 $n 个文件加密完成。',
      'Les $n fichiers ont été chiffrés.',
      'Alle $n Dateien verschlüsselt.',
      '全部 $n 個集信碼化完。');
  String batchPartial(int ok, int fail) => tr(
      '$ok succeeded, $fail failed.',
      '$ok 个成功，$fail 个失败。',
      '$ok réussis, $fail échoués.',
      '$ok erfolgreich, $fail fehlgeschlagen.',
      '$ok 個成，$fail 個失。');

  // ---- Settings: personalization & guide (v1.3.0) ----
  String get behaviorSection => tr(
      'Personalization', '个性化', 'Personnalisation', 'Personalisierung', '個性化');
  String get accentColorLabel =>
      tr('Accent color', '主题色', 'Couleur d\'accent', 'Akzentfarbe', '色按');
  String get accentColorHint => tr(
      'Pick the palette you like. Applies instantly.',
      '选择你喜欢的配色，立即生效。',
      'Choisissez la palette qui vous plaît. Appliquée instantanément.',
      'Wählen Sie die gewünschte Palette. Wirkt sofort.',
      '選你喜歡之配色，即時生效。');
  String get startPageLabel =>
      tr('Start page', '启动页', 'Page de démarrage', 'Startseite', '啟頁');
  String get startPageHint => tr(
      'Which screen the app opens on.',
      '启动应用时默认打开的页面。',
      'Écran sur lequel l\'application s\'ouvre.',
      'Welcher Bildschirm beim Start geöffnet wird.',
      '啟動應用時默認開之頁。');
  String get clipboardClearLabel => tr(
      'Clipboard auto-clear',
      '剪贴板自动清除',
      'Effacement auto du presse-papiers',
      'Zwischenablage automatisch leeren',
      '板暫自清');
  String get clipboardClearHint => tr(
      'After you copy a generated password, the clipboard is wiped automatically.',
      '复制生成的密码后，到时自动清空剪贴板。',
      'Après avoir copié un mot de passe généré, le presse-papiers est effacé automatiquement.',
      'Nach dem Kopieren eines generierten Passworts wird die Zwischenablage automatisch geleert.',
      '抄生成之密口後，到時自清板暫。');
  String clipSeconds(int n) => tr('$n s', '$n 秒', '$n s', '$n s', '$n 秒');
  String get guideSection =>
      tr('Guide & Help', '引导与帮助', 'Guide & Aide', 'Anleitung & Hilfe', '引導與幫助');
  String get showOnboardingBtn => tr('View beginner guide', '查看新手引导',
      'Voir le guide de démarrage', 'Anfängeranleitung ansehen', '看新手引導');
  String get helpTitle => tr(
      'Help & Usage', '使用说明', 'Aide & Utilisation', 'Hilfe & Nutzung', '使用說明');
  String get obSkip => tr('Skip', '跳过', 'Passer', 'Überspringen', '拋過');
  String get obNext => tr('Next', '下一步', 'Suivant', 'Weiter', '下一步');
  String get obDone => tr('Get started', '开始使用', 'Commencer', 'Loslegen', '始用');
  String genCopiedAuto(int n) => tr(
      'Copied. Clipboard clears in $n s.',
      '已复制，$n 秒后自动清空剪贴板。',
      'Copié. Le presse-papiers s\'efface dans $n s.',
      'Kopiert. Zwischenablage wird in $n s geleert.',
      '㐌抄，$n 秒後自清板暫。');

  /// Map error code to localized message
  String errorMessage(String code) {
    switch (code) {
      case 'PASSWORD_TOO_SHORT':
        return errPwShort;
      case 'EMPTY_FILE':
        return errEmpty;
      case 'NOT_VCT':
        return errNotVct;
      case 'NOT_TEXT':
        return noteNotText;
      case 'FILE_TOO_SMALL':
        return errSmall;
      case 'FILE_TOO_LARGE':
        return errFileTooLarge;
      case 'CORRUPT':
        return errCorrupt;
      case 'PAYLOAD_CORRUPT':
        return errPayload;
      case 'WRONG_PASSWORD':
        return errWrongPw;
      case 'DECOY_PW_IDENTICAL':
        return errDecoyPwIdentical;
      case 'DURESS_PW_IDENTICAL':
        return errDuressPwIdentical;
      case 'DECOY_FILE_MISSING':
        return errDecoyFileMissing;
      case 'DECOY_PW_REQUIRED':
        return errDecoyPwRequired;
      case 'DECOY_FILE_EMPTY':
        return errDecoyFileEmpty;
      case 'SHRED_VERIFY_FAILED':
        return errShredVerify;
      case 'BAD_KEY_FILE':
        return errBadKeyFile;
      case 'WRONG_KEY_PASSWORD':
        return errWrongKeyPassword;
      case 'UNSUPPORTED_KEY_PARAMS':
        return errUnsupportedKeyParams;
      case 'KEY_REQUIRED':
        return errKeyRequired;
      case 'WRONG_KEY':
        return errWrongKey;
      case 'KEY_NOT_APPLICABLE':
        return errKeyNotApplicable;
      case 'NO_UNLOCK_CHANNEL':
        return errNoChannel;
      default:
        return code;
    }
  }

  /// Map progress code to localized message
  String progressMessage(String code) {
    switch (code) {
      case 'DERIVING':
        return statusDeriving;
      case 'ENCRYPTING':
        return statusEncrypting;
      case 'ENCRYPTING_DECOY':
        return statusEncryptingDecoy;
      case 'SHREDDING':
        return statusShredding;
      case 'VERIFYING':
        return statusVerifying;
      case 'VERIFIED':
        return statusVerified;
      case 'DECRYPTING':
        return statusDecrypting;
      default:
        return statusProcessing;
    }
  }
}
