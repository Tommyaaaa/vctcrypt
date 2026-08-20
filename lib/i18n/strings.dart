/// VCTCrypt - Internationalization
/// Supports English and Chinese (Simplified)

enum AppLanguage { english, chinese }

extension AppLanguageX on AppLanguage {
  String get code => this == AppLanguage.english ? 'en' : 'zh';
  String get displayName =>
      this == AppLanguage.english ? 'English' : '中文';
}

class AppStrings {
  final AppLanguage lang;

  const AppStrings(this.lang);

  static AppStrings of(AppLanguage lang) => AppStrings(lang);

  // ---- App ----
  String get appName => 'VCTCrypt';
  String get appVersion => 'v1.2.0';
  String get guiVersion => lang == AppLanguage.english
      ? '[GUI Version]'
      : '[图形界面版]';
  String get author => 'Tommy';
  String get algorithm => lang == AppLanguage.english
      ? 'Algorithm: VCT-Crypt (AES-256 x3)'
      : '算法: VCT-Crypt (AES-256 x3)';
  String get whatsNew => lang == AppLanguage.english
      ? 'New in v1.2.0: Password generator · File inspector · Usage stats · Panic lock'
      : 'v1.2.0 新特性：密码生成器 · 文件检查器 · 使用统计 · 紧急锁定';

  // ---- Navigation ----
  String get navEncrypt => lang == AppLanguage.english ? 'Encrypt' : '加密';
  String get navDecrypt => lang == AppLanguage.english ? 'Decrypt' : '解密';
  String get navSettings => lang == AppLanguage.english ? 'Settings' : '设置';

  // ---- Encrypt screen ----
  String get encryptTitle => lang == AppLanguage.english
      ? 'Encrypt File'
      : '加密文件';
  String get encryptSubtitle => lang == AppLanguage.english
      ? 'Secure any file with triple AES-256-GCM'
      : '使用三层 AES-256-GCM 加密任意文件';
  String get selectFile => lang == AppLanguage.english
      ? 'Tap to select a file'
      : '点击选择文件';
  String get selectFileHint => lang == AppLanguage.english
      ? 'Or drag and drop a file here (desktop)'
      : '或将文件拖放到此处（桌面端）';
  String get passwordLabel => lang == AppLanguage.english
      ? 'Password'
      : '密码';
  String get confirmPasswordLabel => lang == AppLanguage.english
      ? 'Confirm Password'
      : '确认密码';
  String get passwordHint => lang == AppLanguage.english
      ? 'Enter password (min 4 chars)'
      : '输入密码（至少4个字符）';
  String get browse => lang == AppLanguage.english ? 'Browse' : '浏览';
  String get encryptBtn => lang == AppLanguage.english
      ? 'Encrypt'
      : '加密';
  String get cancel => lang == AppLanguage.english ? 'Cancel' : '取消';

  // ---- Advanced security options (v1.1.0) ----
  String get advancedOptions => lang == AppLanguage.english
      ? 'Advanced Security Options'
      : '高级安全选项';
  String get advancedOptionsHint => lang == AppLanguage.english
      ? 'Optional. Decoy partition and duress wipe.'
      : '可选。伪装分区与胁迫销毁。';

  String get decoySection => lang == AppLanguage.english
      ? 'Decoy Partition'
      : '伪装分区';
  String get decoyPwLabel => lang == AppLanguage.english
      ? 'Decoy Password'
      : '伪装密码';
  String get decoyPwHint => lang == AppLanguage.english
      ? 'Entering this password during decryption reveals the decoy file instead of the real one.'
      : '解密时输入此密码将解出伪装文件，而非真实文件。';
  String get decoyFileLabel => lang == AppLanguage.english
      ? 'Decoy File'
      : '伪装文件';
  String get decoyFileHint => lang == AppLanguage.english
      ? 'Pick a plausible file to show (e.g. an innocent document)'
      : '选择一个无所谓的文件作为伪装内容（例如普通文档）';

  String get duressSection => lang == AppLanguage.english
      ? 'Duress Password'
      : '胁迫密码';
  String get duressPwHint => lang == AppLanguage.english
      ? 'WARNING: entering this password during decryption PERMANENTLY DESTROYS the encrypted file. Irreversible!'
      : '警告：解密时输入此密码将永久销毁整个加密文件，不可恢复！';

  String get shredSection => lang == AppLanguage.english
      ? 'Secure Shred'
      : '安全擦除';
  String get shredOption => lang == AppLanguage.english
      ? 'Shred original after encryption'
      : '加密后安全擦除原文件';
  String get shredHint => lang == AppLanguage.english
      ? 'Overwrite the original with random data before deleting. Only runs after the output is verified.'
      : '用随机数据覆写原文件后再删除。仅在加密产物校验通过后执行。';

  String get optionalHint => lang == AppLanguage.english
      ? 'Leave empty to disable'
      : '留空则不启用';

  // ---- Decrypt screen ----
  String get decryptTitle => lang == AppLanguage.english
      ? 'Decrypt .VCT File'
      : '解密 .VCT 文件';
  String get decryptSubtitle => lang == AppLanguage.english
      ? 'Restore your encrypted files'
      : '恢复已加密的文件';
  String get selectVctFile => lang == AppLanguage.english
      ? 'Tap to select a .VCT file'
      : '点击选择 .VCT 文件';

  // ---- Progress messages ----
  String get statusDeriving => lang == AppLanguage.english
      ? 'Deriving keys (PBKDF2, 600K iterations)...'
      : '派生密钥 (PBKDF2, 60万次迭代)...';
  String get statusEncrypting => lang == AppLanguage.english
      ? 'Encrypting (3-layer AES-256-GCM)...'
      : '加密中 (三层 AES-256-GCM)...';
  String get statusEncryptingDecoy => lang == AppLanguage.english
      ? 'Encrypting decoy partition...'
      : '正在加密伪装分区...';
  String get statusShredding => lang == AppLanguage.english
      ? 'Securely shredding original file...'
      : '正在安全擦除原文件...';
  String get statusVerifying => lang == AppLanguage.english
      ? 'Verifying password...'
      : '验证密码...';
  String get statusVerified => lang == AppLanguage.english
      ? 'Password verified.'
      : '密码验证通过。';
  String get statusDecrypting => lang == AppLanguage.english
      ? 'Decrypting (3-layer AES-256-GCM)...'
      : '解密中 (三层 AES-256-GCM)...';
  String get statusProcessing => lang == AppLanguage.english
      ? 'Processing... Please wait.'
      : '处理中... 请稍候。';
  String get statusReady => lang == AppLanguage.english ? 'Ready.' : '就绪。';

  // ---- Success ----
  String get encSuccess => lang == AppLanguage.english
      ? 'Encryption complete!'
      : '加密完成！';
  String get decSuccess => lang == AppLanguage.english
      ? 'Decryption complete!'
      : '解密完成！';
  String get outputFile => lang == AppLanguage.english ? 'Output' : '输出';
  String get originalFile => lang == AppLanguage.english
      ? 'Original file'
      : '原始文件';
  String get mobileOutputHint => lang == AppLanguage.english
      ? 'Saved to the VCTCrypt folder - open the Files app to find it.'
      : '已保存到 VCTCrypt 文件夹，请打开系统“文件”App 查看。';
  String get mobileEncHint => lang == AppLanguage.english
      ? 'The .VCT file is saved to the VCTCrypt folder - open the Files app to find it.'
      : '加密产物已保存到 VCTCrypt 文件夹，请打开系统“文件”App 查看。';
  String get fileSize => lang == AppLanguage.english ? 'Size' : '大小';
  String get bytes => lang == AppLanguage.english ? 'bytes' : '字节';
  String get resultDecoyUsed => lang == AppLanguage.english
      ? 'Decoy partition enabled'
      : '已启用伪装分区';
  String get resultDuressUsed => lang == AppLanguage.english
      ? 'Duress wipe enabled'
      : '已启用胁迫销毁';
  String get resultShredded => lang == AppLanguage.english
      ? 'Original file securely shredded.'
      : '原文件已安全擦除。';

  // ---- Errors ----
  String get errRead => lang == AppLanguage.english
      ? 'Cannot read file.'
      : '无法读取文件。';
  String get errEmpty => lang == AppLanguage.english
      ? 'File is empty.'
      : '文件为空。';
  String get errKeyFail => lang == AppLanguage.english
      ? 'Key derivation failed.'
      : '密钥派生失败。';
  String get errL1 => lang == AppLanguage.english
      ? 'Layer 1 encryption failed.'
      : '第1层加密失败。';
  String get errL2 => lang == AppLanguage.english
      ? 'Layer 2 encryption failed.'
      : '第2层加密失败。';
  String get errL3 => lang == AppLanguage.english
      ? 'Layer 3 encryption failed.'
      : '第3层加密失败。';
  String get errNotVct => lang == AppLanguage.english
      ? 'Not a valid VCT file.'
      : '不是有效的 VCT 文件。';
  String get errSmall => lang == AppLanguage.english
      ? 'File too small or corrupted.'
      : '文件过小或已损坏。';
  String get errCorrupt => lang == AppLanguage.english
      ? 'Data corrupted.'
      : '数据损坏。';
  String get errPayload => lang == AppLanguage.english
      ? 'Corrupted payload data.'
      : '负载数据损坏。';
  String get errWrite => lang == AppLanguage.english
      ? 'Cannot write output file.'
      : '无法写入输出文件。';
  String get errNotFound => lang == AppLanguage.english
      ? 'File not found.'
      : '文件未找到。';
  String get errDir => lang == AppLanguage.english
      ? 'Directories are not supported.'
      : '不支持目录。';
  String get errPwShort => lang == AppLanguage.english
      ? 'Password too short (min 4 characters).'
      : '密码太短（至少4个字符）。';
  String get errPwMismatch => lang == AppLanguage.english
      ? 'Passwords do not match.'
      : '两次密码不一致。';
  String get errWrongPw => lang == AppLanguage.english
      ? 'Wrong password or file corrupted.'
      : '密码错误或文件已损坏。';
  String get errDecoyPwIdentical => lang == AppLanguage.english
      ? 'Decoy password must differ from the main password.'
      : '伪装密码不能与主密码相同。';
  String get errDuressPwIdentical => lang == AppLanguage.english
      ? 'Duress password must differ from the main and decoy passwords.'
      : '胁迫密码不能与主密码或伪装密码相同。';
  String get errDecoyFileMissing => lang == AppLanguage.english
      ? 'Please select a decoy file.'
      : '请选择伪装文件。';
  String get errDecoyPwRequired => lang == AppLanguage.english
      ? 'A decoy file was selected - set a decoy password too.'
      : '已选择伪装文件，请同时设置伪装密码。';
  String get errDecoyFileEmpty => lang == AppLanguage.english
      ? 'Decoy file is empty.'
      : '伪装文件为空。';
  String get errShredVerify => lang == AppLanguage.english
      ? 'Output verification failed - original file was NOT shredded.'
      : '加密产物校验失败，原文件未被擦除。';

  // ---- Settings ----
  String get settingsTitle => lang == AppLanguage.english
      ? 'Settings'
      : '设置';
  String get languageSection => lang == AppLanguage.english
      ? 'Language'
      : '语言';
  String get themeSection => lang == AppLanguage.english
      ? 'Theme'
      : '主题';
  String get themeLight => lang == AppLanguage.english ? 'Light' : '浅色';
  String get themeDark => lang == AppLanguage.english ? 'Dark' : '深色';
  String get themeSystem => lang == AppLanguage.english ? 'System' : '跟随系统';
  String get securitySection => lang == AppLanguage.english
      ? 'Security'
      : '安全';
  String get autoLockLabel => lang == AppLanguage.english
      ? 'Auto-lock'
      : '自动锁定';
  String get autoLockHint => lang == AppLanguage.english
      ? 'Clears entered passwords after a period of inactivity.'
      : '空闲一段时间后自动清空已输入的密码。';
  String get autoLockOff => lang == AppLanguage.english ? 'Off' : '关闭';
  String autoLockMinutes(int n) => lang == AppLanguage.english
      ? '$n min'
      : '$n 分钟';
  String get aboutSection => lang == AppLanguage.english ? 'About' : '关于';
  String get aboutAuthor => lang == AppLanguage.english ? 'Author' : '作者';
  String get aboutVersion => lang == AppLanguage.english ? 'Version' : '版本';
  String get aboutAlgo => lang == AppLanguage.english
      ? 'Algorithm'
      : '算法';
  String get aboutAlgoValue => lang == AppLanguage.english
      ? 'VCT-Crypt v1.1\nTriple AES-256-GCM + PBKDF2\n600,000 iterations\n+ Decoy / Duress partitions'
      : 'VCT-Crypt v1.1\n三层 AES-256-GCM + PBKDF2\n60万次迭代\n+ 伪装分区 / 胁迫销毁';
  String get aboutFormatValue => lang == AppLanguage.english
      ? 'VCT format v1 & v2\nv2: deniable partitions'
      : 'VCT 格式 v1 与 v2\nv2：可否认分区';

  // ---- Misc ----
  String get passwordStrengthWeak => lang == AppLanguage.english
      ? 'Weak'
      : '弱';
  String get passwordStrengthMedium => lang == AppLanguage.english
      ? 'Medium'
      : '中等';
  String get passwordStrengthStrong => lang == AppLanguage.english
      ? 'Strong'
      : '强';
  String get noFileSelected => lang == AppLanguage.english
      ? 'No file selected'
      : '未选择文件';
  String get fileSelected => lang == AppLanguage.english
      ? 'Selected'
      : '已选择';
  String get dialogOk => lang == AppLanguage.english ? 'OK' : '好';

  // ---- Password generator (v1.2.0) ----
  String get generatorTitle => lang == AppLanguage.english
      ? 'Password Generator'
      : '密码生成器';
  String get genLength => lang == AppLanguage.english
      ? 'Length'
      : '长度';
  String get genCopy => lang == AppLanguage.english
      ? 'Copy to clipboard'
      : '复制到剪贴板';
  String get genCopied => lang == AppLanguage.english
      ? 'Copied to clipboard'
      : '已复制到剪贴板';
  String get genUse => lang == AppLanguage.english
      ? 'Use this password'
      : '使用此密码';
  String get genRegenerate => lang == AppLanguage.english
      ? 'Regenerate'
      : '重新生成';
  String genEntropy(int bits) => lang == AppLanguage.english
      ? '~$bits bits'
      : '约 $bits 位熵';
  String get genQualityExcellent => lang == AppLanguage.english
      ? 'Excellent'
      : '极强';
  String get genExcludeAmbiguous => lang == AppLanguage.english
      ? 'No 0O1lI'
      : '排除 0O1lI';
  String get genNoClassError => lang == AppLanguage.english
      ? 'Select at least one character type.'
      : '请至少选择一种字符类型。';
  String get genApplied => lang == AppLanguage.english
      ? 'Password generated'
      : '已生成密码';

  // ---- File inspector (v1.2.0) ----
  String get inspectTitle => lang == AppLanguage.english
      ? 'File Info'
      : '文件信息';
  String get infoFileName => lang == AppLanguage.english
      ? 'File name'
      : '文件名';
  String get infoFormat => lang == AppLanguage.english
      ? 'Format'
      : '格式';
  String get infoFormatV1 => lang == AppLanguage.english
      ? 'V1 (classic)'
      : 'V1（经典格式）';
  String get infoFormatV2 => lang == AppLanguage.english
      ? 'V2 (advanced slots)'
      : 'V2（支持高级分区）';
  String get infoFormatInvalid => lang == AppLanguage.english
      ? 'Not a VCT file'
      : '不是 VCT 文件';
  String get infoFileSize => lang == AppLanguage.english
      ? 'File size'
      : '文件大小';
  String get infoPayload => lang == AppLanguage.english
      ? 'Encrypted payload'
      : '加密数据';
  String get infoHeader => lang == AppLanguage.english
      ? 'Header size (bytes)'
      : '头部大小（字节）';
  String get infoAlgo => lang == AppLanguage.english
      ? 'Cipher'
      : '加密算法';
  String get infoKdf => lang == AppLanguage.english
      ? 'Key derivation'
      : '密钥派生';
  String get infoKdfValue => 'PBKDF2-SHA256 · 600K';
  String get infoModified => lang == AppLanguage.english
      ? 'Last modified'
      : '修改时间';
  String get infoDeniableNote => lang == AppLanguage.english
      ? 'V2 files always contain all advanced slots. It is impossible to tell from this file whether a decoy or duress password is set - that is by design.'
      : 'V2 文件始终包含全部高级分区。仅凭此文件无法判断是否设置了伪装或胁迫密码——这是有意为之的设计。';

  // ---- Panic lock (v1.2.0) ----
  String get panicLock => lang == AppLanguage.english
      ? 'Panic lock: clear all passwords now'
      : '紧急锁定：立即清空所有密码';
  String get panicLocked => lang == AppLanguage.english
      ? 'All passwords cleared.'
      : '已清空所有密码。';

  // ---- Usage statistics (v1.2.0) ----
  String get statsSection => lang == AppLanguage.english
      ? 'Usage Statistics'
      : '使用统计';
  String get statsEncrypted => lang == AppLanguage.english
      ? 'Files encrypted'
      : '已加密文件';
  String get statsDecrypted => lang == AppLanguage.english
      ? 'Files decrypted'
      : '已解密文件';
  String get statsDataEnc => lang == AppLanguage.english
      ? 'Data encrypted'
      : '已加密数据量';
  String get statsDataDec => lang == AppLanguage.english
      ? 'Data decrypted'
      : '已解密数据量';
  String get statsDecoy => lang == AppLanguage.english
      ? 'Decoy partitions'
      : '伪装分区';
  String get statsDuressArmed => lang == AppLanguage.english
      ? 'Duress traps armed'
      : '胁迫陷阱';
  String get statsDuressTriggered => lang == AppLanguage.english
      ? 'Duress wipes triggered'
      : '胁迫销毁触发';
  String get statsShredded => lang == AppLanguage.english
      ? 'Files shredded'
      : '已擦除文件';
  String get statsEmpty => lang == AppLanguage.english
      ? 'No operations recorded yet.'
      : '暂无操作记录。';
  String get statsReset => lang == AppLanguage.english
      ? 'Reset statistics'
      : '重置统计';
  String get statsResetConfirmTitle => lang == AppLanguage.english
      ? 'Reset statistics?'
      : '重置统计？';
  String get statsResetConfirmBody => lang == AppLanguage.english
      ? 'All counters will be cleared. This cannot be undone.'
      : '所有计数将被清零，此操作不可撤销。';
  String get statsPrivacyNote => lang == AppLanguage.english
      ? 'Statistics are stored locally on this device only. No file names, passwords or paths are ever recorded.'
      : '统计数据仅保存在本设备，不记录任何文件名、密码或路径。';

  /// Map error code to localized message
  String errorMessage(String code) {
    switch (code) {
      case 'PASSWORD_TOO_SHORT': return errPwShort;
      case 'EMPTY_FILE': return errEmpty;
      case 'NOT_VCT': return errNotVct;
      case 'FILE_TOO_SMALL': return errSmall;
      case 'CORRUPT': return errCorrupt;
      case 'PAYLOAD_CORRUPT': return errPayload;
      case 'WRONG_PASSWORD': return errWrongPw;
      case 'DECOY_PW_IDENTICAL': return errDecoyPwIdentical;
      case 'DURESS_PW_IDENTICAL': return errDuressPwIdentical;
      case 'DECOY_FILE_MISSING': return errDecoyFileMissing;
      case 'DECOY_PW_REQUIRED': return errDecoyPwRequired;
      case 'DECOY_FILE_EMPTY': return errDecoyFileEmpty;
      case 'SHRED_VERIFY_FAILED': return errShredVerify;
      default: return code;
    }
  }

  /// Map progress code to localized message
  String progressMessage(String code) {
    switch (code) {
      case 'DERIVING': return statusDeriving;
      case 'ENCRYPTING': return statusEncrypting;
      case 'ENCRYPTING_DECOY': return statusEncryptingDecoy;
      case 'SHREDDING': return statusShredding;
      case 'VERIFYING': return statusVerifying;
      case 'VERIFIED': return statusVerified;
      case 'DECRYPTING': return statusDecrypting;
      default: return statusProcessing;
    }
  }
}
