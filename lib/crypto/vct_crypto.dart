/// VCTCrypt - Core Encryption Engine (Dart)
/// Author: Tommy
/// Algorithm: VCT-Crypt v1.1 (Triple AES-256-GCM + PBKDF2)
///
/// V1 file format (.VCT) - byte-compatible with CLI versions:
///   [MAGIC 12B] [SALT 48B] [N1 12B] [N2 12B] [N3 12B] [HMAC 32B] [L3_CT NB] [T3 16B]
///   L3 = AES-GCM(K3, N3, L2b)
///   L2b = [T2 16B] [L2_CT]  where L2 = AES-GCM(K2, N2, L1b)
///   L1b = [T1 16B] [L1_CT]  where L1 = AES-GCM(K1, N1, PAYLOAD)
///   PAYLOAD = [name_len 2B LE] [orig_name NB] [file_data NB]
///
/// V2 file format (.VCT) - adds decoy partition + duress wipe (GUI 1.1.0+):
///   [MAGIC 12B "VCTCRYPT2\0\0\0"]
///   [REAL_CT_LEN 8B LE]
///   [REAL:   SALT 48B] [N1 12B] [N2 12B] [N3 12B] [HMAC 32B]
///   [DECOY:  DSALT 48B] [DN1 12B] [DN2 12B] [DN3 12B] [DHMAC 32B]
///   [DURESS: XSALT 48B] [XHMAC 32B]
///   [REAL_L3_CT NB] [T3 16B]
///   [DECOY_L3_CT NB] [DT3 16B]
///
/// Deniability: ALL three sections are ALWAYS present, even when a feature
/// is unused (unused slots hold random bytes, indistinguishable from real
/// HMACs/ciphertext). Every V2 file has the same shape, so an attacker
/// cannot tell whether a decoy partition or duress password exists.
///
/// Decryption with password P (uniform 3-way verification, constant work):
///   1. HMAC(PBKDF2(P::V, salt),   salt+n1+n2+n3)   == REAL HMAC  -> decrypt real payload
///   2. HMAC(PBKDF2(P::V, dsalt),  dsalt+dn1+dn2+dn3) == DECOY HMAC -> decrypt decoy payload
///   3. HMAC(PBKDF2(P::V, xsalt),  xsalt)           == DURESS HMAC -> PERMANENTLY SHRED file
///   4. Otherwise -> wrong password

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ---- Constants ----
const _magicV1 = 'VCTCRYPT1\x00\x00\x00'; // 12 bytes (matches C: "VCTCRYPT1\0\0" + implicit C null)
const _magicV1Old = 'VCTCRYPT1\x00\x00'; // 11 bytes - buggy old Flutter format (missing trailing \0)
const _magicV2 = 'VCTCRYPT2\x00\x00\x00'; // 12 bytes
const _magicLen = 12;
const _saltSize = 48;
const _nonceSize = 12;
const _tagSize = 16;
const _hmacSize = 32;
const _pbkdf2Iters = 600000;
const _pbkdf2VIters = 10000;
const _maxFname = 512;

// ---- V2 layout offsets ----
// [magic 12][realCtLen 8][salt 48][n1 12][n2 12][n3 12][hmac 32]
// [dsalt 48][dn1 12][dn2 12][dn3 12][dhmac 32][xsalt 48][xhmac 32]
const _v2RealCtLenOff = _magicLen; // 12
const _v2RealSaltOff = _v2RealCtLenOff + 8; // 20
const _v2RealHmacOff = _v2RealSaltOff + _saltSize + _nonceSize * 3; // 104
const _v2DecoySaltOff = _v2RealHmacOff + _hmacSize; // 136
const _v2DecoyHmacOff = _v2DecoySaltOff + _saltSize + _nonceSize * 3; // 220
const _v2DuressSaltOff = _v2DecoyHmacOff + _hmacSize; // 252
const _v2DuressHmacOff = _v2DuressSaltOff + _saltSize; // 300
const _v2HeaderLen = _v2DuressHmacOff + _hmacSize; // 332

// ---- Format codes ----
const fmtNone = 0;
const fmtV1 = 1; // 12-byte V1 magic (CLI-compatible)
const fmtV1Old = 2; // 11-byte buggy V1 magic (old Flutter builds)
const fmtV2 = 3; // V2 with decoy/duress slots

// ---- Crypto primitives ----

Future<List<int>> _secureRandom(int length) async {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

Future<List<int>> _hmacSha256(
  List<int> key,
  List<int> data,
) async {
  final hmac = Hmac.sha256();
  final mac = await hmac.calculateMac(data, secretKey: SecretKey(key));
  return mac.bytes;
}

Future<List<int>> _pbkdf2(
  String password,
  List<int> salt,
  int iterations,
  int outLen,
) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: outLen * 8,
  );
  final derived = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return derived.extractBytes();
}

// ---- Key derivation ----

class _Keys {
  final List<int> k1, k2, k3, vk;
  _Keys(this.k1, this.k2, this.k3, this.vk);
}

Future<_Keys> _deriveKeys(
  String password,
  List<int> salt,
) async {
  final vk = await _pbkdf2('$password::V', salt, _pbkdf2VIters, 32);
  final k1 = await _pbkdf2('$password::1', salt, _pbkdf2Iters, 32);
  final k2 = await _pbkdf2('$password::2', salt, _pbkdf2Iters, 32);
  final k3 = await _pbkdf2('$password::3', salt, _pbkdf2Iters, 32);
  return _Keys(k1, k2, k3, vk);
}

// ---- AES-GCM wrappers ----

Future<({List<int> cipherText, List<int> tag})> _aesGcmEncrypt(
  List<int> key,
  List<int> nonce,
  List<int> plainText,
) async {
  final aesGcm = AesGcm.with256bits();
  final secretBox = await aesGcm.encrypt(
    plainText,
    secretKey: SecretKey(key),
    nonce: nonce,
  );
  return (cipherText: secretBox.cipherText, tag: secretBox.mac.bytes);
}

Future<List<int>> _aesGcmDecrypt(
  List<int> key,
  List<int> nonce,
  List<int> cipherText,
  List<int> tag,
) async {
  final aesGcm = AesGcm.with256bits();
  final secretBox = SecretBox(
    cipherText,
    nonce: nonce,
    mac: Mac(tag),
  );
  return aesGcm.decrypt(secretBox, secretKey: SecretKey(key));
}

// ---- File helpers ----

Uint8List _readFile(String path) {
  final f = File(path);
  final bytes = f.readAsBytesSync();
  return bytes;
}

/// Atomic file write (v1.4.0): write to a sibling temp file, then
/// rename over the destination.
///
/// Why: on iOS the Files app (fileproviderd) learns about changes in
/// the app's Documents folder through file coordination. Writing in
/// place with writeAsBytesSync leaves the Files app showing an EMPTY
/// folder even though the file exists (visible in Filza). An atomic
/// rename is the documented, reliably-observed pattern. It also
/// prevents half-written outputs if the process dies mid-write.
void _writeFile(String path, List<int> data) {
  final f = File(path);
  final tmp = File('$path.vctpart');
  try {
    tmp.writeAsBytesSync(data, flush: true);
    // RenameSync atomically replaces the destination on iOS/Android/
    // desktop; falls back to delete+rename on exotic filesystems.
    tmp.renameSync(path);
  } on FileSystemException {
    // Fallback: direct write (temp may be on another volume, etc.)
    if (tmp.existsSync()) tmp.deleteSync();
    f.writeAsBytesSync(data);
  }
}

/// Overwrite the entire file with random bytes (same length kept, so the
/// file still "exists" but is unrecoverable noise - looks like corruption,
/// not deletion). Best-effort; modern storage makes multi-pass pointless.
Future<void> _shredFile(String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final size = f.lengthSync();
  final rng = Random.secure();
  final raf = f.openSync(mode: FileMode.write); // truncates
  try {
    const chunkSize = 64 * 1024;
    var remaining = size;
    while (remaining > 0) {
      final n = remaining > chunkSize ? chunkSize : remaining;
      final buf = Uint8List(n);
      for (int i = 0; i < n; i++) {
        buf[i] = rng.nextInt(256);
      }
      raf.writeFromSync(buf);
      remaining -= n;
    }
    raf.flushSync();
  } finally {
    raf.closeSync();
  }
}

// ---- Format detection ----

/// Detects file format:
/// fmtNone (0) / fmtV1 (1) / fmtV1Old (2) / fmtV2 (3)
int detectFormat(Uint8List data) {
  if (data.length < 11) return fmtNone;

  if (data.length >= 12) {
    final v2 = utf8.encode(_magicV2);
    bool v2Match = true;
    for (int i = 0; i < 12; i++) {
      if (data[i] != v2[i]) {
        v2Match = false;
        break;
      }
    }
    if (v2Match) return fmtV2;

    final v1 = utf8.encode(_magicV1);
    bool v1Match = true;
    for (int i = 0; i < 12; i++) {
      if (data[i] != v1[i]) {
        v1Match = false;
        break;
      }
    }
    if (v1Match) return fmtV1;
  }

  // 11-byte buggy V1 magic (old Flutter format - data shifted 1 byte left)
  final v1Old = utf8.encode(_magicV1Old);
  bool oldMatch = true;
  for (int i = 0; i < 11; i++) {
    if (data[i] != v1Old[i]) {
      oldMatch = false;
      break;
    }
  }
  if (oldMatch) return fmtV1Old;

  return fmtNone;
}

bool isVctFile(String path) {
  try {
    final fileData = _readFile(path);
    return detectFormat(fileData) != fmtNone;
  } catch (_) {
    return false;
  }
}

/// Metadata extracted from a VCT file header WITHOUT any password
/// (v1.2.0 "Inspect" feature).
///
/// Deniability guarantee: only format-level facts are exposed. A V2
/// file ALWAYS contains all three slots (real/decoy/duress) whether or
/// not those features were used, so the inspector can never tell
/// whether a decoy or duress password exists.
class VctFileInfo {
  /// One of [fmtV1], [fmtV1Old], [fmtV2] or [fmtNone].
  final int format;

  /// Total file size in bytes.
  final int fileSize;

  /// File modification time.
  final DateTime modified;

  /// Size of the encrypted real payload (V2 only; null for V1).
  final int? realCtLen;

  /// Header size in bytes (V2: 332, V1/V1-old: 128).
  final int headerLen;

  const VctFileInfo({
    required this.format,
    required this.fileSize,
    required this.modified,
    this.realCtLen,
    required this.headerLen,
  });

  bool get isValid => format != fmtNone;
  bool get isV2 => format == fmtV2;
}

/// Read only the header of [path] and return its public metadata.
/// Throws FileSystemException on IO errors.
VctFileInfo inspectVctFile(String path) {
  final f = File(path);
  final size = f.lengthSync();
  final modified = f.lastModifiedSync();

  final raf = f.openSync(mode: FileMode.read);
  Uint8List head;
  try {
    final n = size < _v2HeaderLen ? size : _v2HeaderLen;
    head = raf.readSync(n);
  } finally {
    raf.closeSync();
  }

  final format = detectFormat(head);
  if (format == fmtNone) {
    return VctFileInfo(
      format: fmtNone,
      fileSize: size,
      modified: modified,
      headerLen: 0,
    );
  }

  if (format == fmtV2) {
    // Guard: a truncated V2 file (< header size) has no readable
    // payload length - report the format but skip the length field.
    if (head.length >= _v2HeaderLen) {
      final ctLen = _readU64LE(head, _v2RealCtLenOff);
      return VctFileInfo(
        format: format,
        fileSize: size,
        modified: modified,
        realCtLen: ctLen,
        headerLen: _v2HeaderLen,
      );
    }
    return VctFileInfo(
      format: format,
      fileSize: size,
      modified: modified,
      headerLen: _v2HeaderLen,
    );
  }

  // V1 / V1-old: magic 12 + salt 48 + nonces 36 + hmac 32 = 128
  return VctFileInfo(
    format: format,
    fileSize: size,
    modified: modified,
    headerLen: 128,
  );
}

/// Encrypted output file name for [input]: "photo.jpg" -> "photo.VCT".
String _encFileName(String input) {
  final base = p.basename(input);
  final ext = p.extension(base);
  final name = ext.isNotEmpty ? base.substring(0, base.length - ext.length) : base;
  return '$name.VCT';
}

/// Decide where an output file should be written.
///
/// Desktop: next to the input file (classic behaviour).
///
/// Mobile: the system pickers hand us a COPY inside the app sandbox tmp
/// (iOS Inbox / Android cache). Writing "next to the input" would bury
/// the result where no file manager can see it, so we write to:
///   iOS     -> Documents (visible in the Files app via UIFileSharingEnabled)
///   Android -> external app files dir (visible to file managers / USB)
///
/// Never silently overwrites an existing file: appends " (n)" before the
/// extension. Also refuses to overwrite the input itself.
Future<String> _chooseOutputPath(String fileName, String inputPath) async {
  if (!Platform.isIOS && !Platform.isAndroid) {
    var out = p.join(p.dirname(inputPath), fileName);
    // Re-encrypting a .VCT must not clobber the source file.
    if (p.equals(out, inputPath)) {
      final dot = fileName.lastIndexOf('.');
      final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
      final ext = dot > 0 ? fileName.substring(dot) : '';
      out = p.join(p.dirname(inputPath), '${stem}_enc$ext');
    }
    return out;
  }

  String baseDir;
  try {
    if (Platform.isIOS) {
      baseDir = (await getApplicationDocumentsDirectory()).path;
    } else {
      final extDirs = await getExternalStorageDirectories();
      baseDir = (extDirs != null && extDirs.isNotEmpty)
          ? extDirs.first.path
          : (await getApplicationDocumentsDirectory()).path;
    }
  } catch (_) {
    // Path provider unavailable - fall back to old behaviour.
    return p.join(p.dirname(inputPath), fileName);
  }

  var out = p.join(baseDir, fileName);
  if (p.equals(out, inputPath)) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    out = p.join(baseDir, '${stem}_enc$ext');
  }

  // name, name (1), name (2), ...
  final dir = p.dirname(out);
  final base = p.basename(out);
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  final ext = dot > 0 ? base.substring(dot) : '';
  var candidate = out;
  var i = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$stem ($i)$ext');
    i++;
  }
  return candidate;
}

// ---- Partition encrypt/decrypt ----

/// One encrypted partition: header material + body (ciphertext + tag).
class _Partition {
  final List<int> salt;
  final List<int> n1, n2, n3;
  final List<int> hmac;
  final List<int> ct;
  final List<int> tag;
  _Partition({
    required this.salt,
    required this.n1,
    required this.n2,
    required this.n3,
    required this.hmac,
    required this.ct,
    required this.tag,
  });
}

/// Build payload: [name_len 2B LE (UTF-8 byte length)] [name] [file_data]
/// NOTE: length is the UTF-8 BYTE count (matches C CLI semantics); v1.0
/// Flutter stored the character count, which garbled non-ASCII filenames.
List<int> _buildPayload(String filePath, List<int> fileData) {
  final base = p.basename(filePath);
  var nameBytes = utf8.encode(base);
  if (nameBytes.length > 0xFFFF) {
    nameBytes = nameBytes.sublist(0, 0xFFFF);
  }
  final payload = BytesBuilder();
  payload.addByte(nameBytes.length & 0xFF);
  payload.addByte((nameBytes.length >> 8) & 0xFF);
  payload.add(nameBytes);
  payload.add(fileData);
  return payload.toBytes();
}

/// Triple-encrypt one payload under [password] with fresh random material.
Future<_Partition> _encryptPartition(
  String password,
  List<int> payload,
  String progressCode,
  ProgressCallback? onProgress,
) async {
  onProgress?.call('DERIVING');

  final salt = await _secureRandom(_saltSize);
  final n1 = await _secureRandom(_nonceSize);
  final n2 = await _secureRandom(_nonceSize);
  final n3 = await _secureRandom(_nonceSize);

  final keys = await _deriveKeys(password, salt);

  onProgress?.call(progressCode);

  // Layer 1
  final l1 = await _aesGcmEncrypt(keys.k1, n1, payload);
  final l1b = BytesBuilder()
    ..add(l1.tag)
    ..add(l1.cipherText);

  // Layer 2
  final l2 = await _aesGcmEncrypt(keys.k2, n2, l1b.toBytes());
  final l2b = BytesBuilder()
    ..add(l2.tag)
    ..add(l2.cipherText);

  // Layer 3
  final l3 = await _aesGcmEncrypt(keys.k3, n3, l2b.toBytes());

  // Verification HMAC over header material
  final hData = BytesBuilder()
    ..add(salt)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final hmacVal = await _hmacSha256(keys.vk, hData.toBytes());

  return _Partition(
    salt: salt,
    n1: n1,
    n2: n2,
    n3: n3,
    hmac: hmacVal,
    ct: l3.cipherText,
    tag: l3.tag,
  );
}

/// A partition whose slots are pure random filler (used when a feature is
/// disabled, so every V2 file has identical shape -> plausible deniability).
Future<_Partition> _randomPartition() async {
  final rng = Random.secure();
  final fillerCtLen = 240 + rng.nextInt(1800); // plausible body size
  return _Partition(
    salt: await _secureRandom(_saltSize),
    n1: await _secureRandom(_nonceSize),
    n2: await _secureRandom(_nonceSize),
    n3: await _secureRandom(_nonceSize),
    hmac: await _secureRandom(_hmacSize),
    ct: await _secureRandom(fillerCtLen),
    tag: await _secureRandom(_tagSize),
  );
}

/// Internal result carrying decrypted bytes (not yet written to disk)
class _InternalResult {
  final bool success;
  final String? error;
  final String? originalName;
  final List<int>? fileBytes;
  _InternalResult({this.success = true, this.error, this.originalName, this.fileBytes});
}

/// Decrypt the 3-layer body of one partition with pre-derived keys.
Future<_InternalResult> _decryptBody(
  _Keys keys,
  List<int> n1,
  List<int> n2,
  List<int> n3,
  List<int> l3Ct,
  List<int> t3,
) async {
  final l2b = await _aesGcmDecrypt(keys.k3, n3, l3Ct, t3);
  if (l2b.length < _tagSize) {
    return _InternalResult(success: false, error: 'CORRUPT');
  }
  final t2 = l2b.sublist(0, _tagSize);
  final l2Ct = l2b.sublist(_tagSize);

  final l1b = await _aesGcmDecrypt(keys.k2, n2, l2Ct, t2);
  if (l1b.length < _tagSize) {
    return _InternalResult(success: false, error: 'CORRUPT');
  }
  final t1 = l1b.sublist(0, _tagSize);
  final l1Ct = l1b.sublist(_tagSize);

  final payload = await _aesGcmDecrypt(keys.k1, n1, l1Ct, t1);
  if (payload.length < 2) {
    return _InternalResult(success: false, error: 'PAYLOAD_CORRUPT');
  }

  // Parse payload: [name_len 2B LE] [name] [file_data]
  final nameLen = payload[0] | (payload[1] << 8);
  if (2 + nameLen > payload.length) {
    return _InternalResult(success: false, error: 'PAYLOAD_CORRUPT');
  }

  var origNameLen = nameLen;
  if (origNameLen >= _maxFname) origNameLen = _maxFname - 1;
  String origName;
  try {
    origName = utf8.decode(payload.sublist(2, 2 + origNameLen));
  } catch (_) {
    return _InternalResult(success: false, error: 'PAYLOAD_CORRUPT');
  }
  final fileBytes = payload.sublist(2 + nameLen);

  return _InternalResult(
    success: true,
    originalName: origName,
    fileBytes: fileBytes,
  );
}

/// Constant-time comparison of two equal-length byte lists.
bool _constantTimeEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (int i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Verify a partition HMAC: HMAC(PBKDF2(password::V, salt), data)
Future<bool> _verifyPartitionHmac(
  String password,
  List<int> salt,
  List<int> n1,
  List<int> n2,
  List<int> n3,
  List<int> storedHmac,
) async {
  final vk = await _pbkdf2('$password::V', salt, _pbkdf2VIters, 32);
  final hData = BytesBuilder()
    ..add(salt)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final computed = await _hmacSha256(vk, hData.toBytes());
  return _constantTimeEq(computed, storedHmac);
}

/// Verify the duress HMAC: HMAC(PBKDF2(duressPassword::V, xsalt), xsalt)
Future<bool> _verifyDuressHmac(
  String password,
  List<int> xsalt,
  List<int> storedHmac,
) async {
  final vk = await _pbkdf2('$password::V', xsalt, _pbkdf2VIters, 32);
  final computed = await _hmacSha256(vk, xsalt);
  return _constantTimeEq(computed, storedHmac);
}

/// Write decrypted bytes to a user-visible location.
/// (Desktop: next to the .VCT file. Mobile: app Documents / external files.)
Future<DecryptResult> _writeDecrypted(String vctPath, _InternalResult internal) async {
  final origName = internal.originalName ?? 'decrypted_file';
  final outPath = await _chooseOutputPath(origName, vctPath);
  _writeFile(outPath, internal.fileBytes!);
  return DecryptResult(
    success: true,
    outputPath: outPath,
    originalName: origName,
    outputSize: internal.fileBytes!.length,
  );
}

// ---- Public API ----

/// Options for V2 encryption (GUI 1.1.0+).
class EncryptOptions {
  /// Decoy password: entering it during decryption reveals [decoyFilePath]
  /// instead of the real file (plausible deniability).
  final String? decoyPassword;

  /// File that will be revealed when the decoy password is entered.
  final String? decoyFilePath;

  /// Duress password: entering it during decryption PERMANENTLY DESTROYS
  /// the entire encrypted file (irreversible, includes the decoy partition).
  final String? duressPassword;

  /// Securely shred the original file after successful encryption
  /// (random overwrite + verified output before deleting).
  final bool shredOriginal;

  const EncryptOptions({
    this.decoyPassword,
    this.decoyFilePath,
    this.duressPassword,
    this.shredOriginal = false,
  });
}

class EncryptResult {
  final bool success;
  final String? outputPath;
  final int? outputSize;
  final String? error;
  final bool usedDecoy;
  final bool usedDuress;
  final bool shreddedOriginal;
  EncryptResult({
    this.success = true,
    this.outputPath,
    this.outputSize,
    this.error,
    this.usedDecoy = false,
    this.usedDuress = false,
    this.shreddedOriginal = false,
  });
}

class DecryptResult {
  final bool success;
  final String? outputPath;
  final String? originalName;
  final int? outputSize;
  final String? error;

  /// True when the DECOY password was entered and the decoy file was
  /// decrypted. IMPORTANT: the UI must NOT behave differently for decoy
  /// decryption - identical success screen is what makes it deniable.
  final bool isDecoy;

  /// True when the duress password was entered: the file has been
  /// permanently shredded. The returned error is 'WRONG_PASSWORD' on
  /// purpose - observers must not be able to tell duress was triggered.
  final bool duressTriggered;

  DecryptResult({
    this.success = true,
    this.outputPath,
    this.originalName,
    this.outputSize,
    this.error,
    this.isDecoy = false,
    this.duressTriggered = false,
  });
}

typedef ProgressCallback = void Function(String message);

int _readU64LE(Uint8List data, int offset) {
  var value = 0;
  for (int i = 7; i >= 0; i--) {
    value = value * 256 + data[offset + i];
  }
  return value;
}

void _writeU64LE(BytesBuilder builder, int value) {
  var v = value;
  for (int i = 0; i < 8; i++) {
    builder.addByte(v & 0xFF);
    v = v ~/ 256;
  }
}

Future<EncryptResult> encryptFile(
  String filePath,
  String password,
  ProgressCallback? onProgress, {
  EncryptOptions? options,
}) async {
  try {
    if (password.length < 4) {
      return EncryptResult(success: false, error: 'PASSWORD_TOO_SHORT');
    }

    final decoyPw = options?.decoyPassword;
    final decoyPath = options?.decoyFilePath;
    final duressPw = options?.duressPassword;
    final shred = options?.shredOriginal ?? false;

    // ---- Validate options ----
    if (decoyPw != null && decoyPw.isNotEmpty) {
      if (decoyPw.length < 4) {
        return EncryptResult(success: false, error: 'PASSWORD_TOO_SHORT');
      }
      if (decoyPw == password) {
        return EncryptResult(success: false, error: 'DECOY_PW_IDENTICAL');
      }
      if (decoyPath == null || decoyPath.isEmpty) {
        return EncryptResult(success: false, error: 'DECOY_FILE_MISSING');
      }
    }
    if (duressPw != null && duressPw.isNotEmpty) {
      if (duressPw.length < 4) {
        return EncryptResult(success: false, error: 'PASSWORD_TOO_SHORT');
      }
      if (duressPw == password || duressPw == decoyPw) {
        return EncryptResult(success: false, error: 'DURESS_PW_IDENTICAL');
      }
    }

    final fileData = _readFile(filePath);
    if (fileData.isEmpty) {
      return EncryptResult(success: false, error: 'EMPTY_FILE');
    }

    final realPayload = _buildPayload(filePath, fileData);

    // ---- Real partition ----
    final realPart = await _encryptPartition(
      password,
      realPayload,
      'ENCRYPTING',
      onProgress,
    );

    // ---- Decoy partition (random filler when disabled) ----
    _Partition decoyPart;
    if (decoyPw != null && decoyPw.isNotEmpty) {
      final decoyData = _readFile(decoyPath!);
      if (decoyData.isEmpty) {
        return EncryptResult(success: false, error: 'DECOY_FILE_EMPTY');
      }
      final decoyPayload = _buildPayload(decoyPath, decoyData);
      decoyPart = await _encryptPartition(
        decoyPw,
        decoyPayload,
        'ENCRYPTING_DECOY',
        onProgress,
      );
    } else {
      decoyPart = await _randomPartition();
    }

    // ---- Duress section (random filler when disabled) ----
    final List<int> xsalt;
    final List<int> xhmac;
    if (duressPw != null && duressPw.isNotEmpty) {
      xsalt = await _secureRandom(_saltSize);
      final xvk = await _pbkdf2('$duressPw::V', xsalt, _pbkdf2VIters, 32);
      xhmac = await _hmacSha256(xvk, xsalt);
    } else {
      xsalt = await _secureRandom(_saltSize);
      xhmac = await _secureRandom(_hmacSize);
    }

    // ---- Assemble V2 file ----
    final output = BytesBuilder();
    output.add(utf8.encode(_magicV2));
    _writeU64LE(output, realPart.ct.length);
    output.add(realPart.salt);
    output.add(realPart.n1);
    output.add(realPart.n2);
    output.add(realPart.n3);
    output.add(realPart.hmac);
    output.add(decoyPart.salt);
    output.add(decoyPart.n1);
    output.add(decoyPart.n2);
    output.add(decoyPart.n3);
    output.add(decoyPart.hmac);
    output.add(xsalt);
    output.add(xhmac);
    output.add(realPart.ct);
    output.add(realPart.tag);
    output.add(decoyPart.ct);
    output.add(decoyPart.tag);

    final outPath = await _chooseOutputPath(_encFileName(filePath), filePath);
    _writeFile(outPath, output.toBytes());

    // ---- Optional: shred the original after verifying the output ----
    var shredded = false;
    if (shred) {
      onProgress?.call('SHREDDING');
      final outputOk = await _verifyWrittenV2(outPath, password);
      if (!outputOk) {
        // NEVER destroy the original unless the output is provably valid.
        return EncryptResult(
          success: false,
          error: 'SHRED_VERIFY_FAILED',
        );
      }
      await _shredFile(filePath);
      shredded = true;
    }

    return EncryptResult(
      success: true,
      outputPath: outPath,
      outputSize: output.length,
      usedDecoy: decoyPw != null && decoyPw.isNotEmpty,
      usedDuress: duressPw != null && duressPw.isNotEmpty,
      shreddedOriginal: shredded,
    );
  } catch (e) {
    return EncryptResult(success: false, error: e.toString());
  }
}

/// Cheap sanity check of a freshly written V2 file (magic + real HMAC,
/// ~10K PBKDF2 iterations) before we allow shredding the original.
Future<bool> _verifyWrittenV2(String outPath, String password) async {
  try {
    final data = _readFile(outPath);
    if (detectFormat(data) != fmtV2) return false;
    if (data.length < _v2HeaderLen + _tagSize) return false;

    final salt = data.sublist(_v2RealSaltOff, _v2RealSaltOff + _saltSize);
    final n1 = data.sublist(
        _v2RealSaltOff + _saltSize, _v2RealSaltOff + _saltSize + _nonceSize);
    final n2 = data.sublist(_v2RealSaltOff + _saltSize + _nonceSize,
        _v2RealSaltOff + _saltSize + _nonceSize * 2);
    final n3 = data.sublist(_v2RealSaltOff + _saltSize + _nonceSize * 2,
        _v2RealSaltOff + _saltSize + _nonceSize * 3);
    final hmac = data.sublist(_v2RealHmacOff, _v2RealHmacOff + _hmacSize);

    return _verifyPartitionHmac(password, salt, n1, n2, n3, hmac);
  } catch (_) {
    return false;
  }
}

// ---- Decryption ----

Future<DecryptResult> _decryptV2(
  Uint8List fileData,
  String filePath,
  String password,
  ProgressCallback? onProgress,
) async {
  if (fileData.length < _v2HeaderLen + _tagSize + _tagSize) {
    return DecryptResult(success: false, error: 'FILE_TOO_SMALL');
  }

  // ---- Parse header ----
  final realCtLen = _readU64LE(fileData, _v2RealCtLenOff);

  final realSalt = fileData.sublist(_v2RealSaltOff, _v2RealSaltOff + _saltSize);
  final realN1 = fileData.sublist(
      _v2RealSaltOff + _saltSize, _v2RealSaltOff + _saltSize + _nonceSize);
  final realN2 = fileData.sublist(_v2RealSaltOff + _saltSize + _nonceSize,
      _v2RealSaltOff + _saltSize + _nonceSize * 2);
  final realN3 = fileData.sublist(_v2RealSaltOff + _saltSize + _nonceSize * 2,
      _v2RealSaltOff + _saltSize + _nonceSize * 3);
  final realHmac =
      fileData.sublist(_v2RealHmacOff, _v2RealHmacOff + _hmacSize);

  final decoySalt =
      fileData.sublist(_v2DecoySaltOff, _v2DecoySaltOff + _saltSize);
  final decoyN1 = fileData.sublist(
      _v2DecoySaltOff + _saltSize, _v2DecoySaltOff + _saltSize + _nonceSize);
  final decoyN2 = fileData.sublist(_v2DecoySaltOff + _saltSize + _nonceSize,
      _v2DecoySaltOff + _saltSize + _nonceSize * 2);
  final decoyN3 = fileData.sublist(_v2DecoySaltOff + _saltSize + _nonceSize * 2,
      _v2DecoySaltOff + _saltSize + _nonceSize * 3);
  final decoyHmac =
      fileData.sublist(_v2DecoyHmacOff, _v2DecoyHmacOff + _hmacSize);

  final duressSalt =
      fileData.sublist(_v2DuressSaltOff, _v2DuressSaltOff + _saltSize);
  final duressHmac =
      fileData.sublist(_v2DuressHmacOff, _v2DuressHmacOff + _hmacSize);

  // ---- Parse body: [realCt][realTag][decoyCt][decoyTag] ----
  final bodyStart = _v2HeaderLen;
  final realCtEnd = bodyStart + realCtLen;
  if (realCtLen <= 0 ||
      realCtEnd + _tagSize > fileData.length ||
      realCtEnd + _tagSize + _tagSize > fileData.length) {
    return DecryptResult(success: false, error: 'CORRUPT');
  }
  final realCt = fileData.sublist(bodyStart, realCtEnd);
  final realTag = fileData.sublist(realCtEnd, realCtEnd + _tagSize);
  final decoyStart = realCtEnd + _tagSize;
  final decoyCtEnd = fileData.length - _tagSize;
  final decoyCt = fileData.sublist(decoyStart, decoyCtEnd);
  final decoyTag = fileData.sublist(decoyCtEnd);

  onProgress?.call('VERIFYING');

  // ---- Uniform 3-way verification (constant work, no timing leak) ----
  final realOk =
      await _verifyPartitionHmac(password, realSalt, realN1, realN2, realN3, realHmac);
  final decoyOk =
      await _verifyPartitionHmac(password, decoySalt, decoyN1, decoyN2, decoyN3, decoyHmac);
  final duressOk = await _verifyDuressHmac(password, duressSalt, duressHmac);

  // ---- Real password ----
  if (realOk) {
    onProgress?.call('VERIFIED');
    onProgress?.call('DECRYPTING');
    final keys = await _deriveKeys(password, realSalt);
    final internal = await _decryptBody(keys, realN1, realN2, realN3, realCt, realTag);
    if (!internal.success) {
      return DecryptResult(success: false, error: internal.error);
    }
    return await _writeDecrypted(filePath, internal);
  }

  // ---- Decoy password (identical success behavior - deniability) ----
  if (decoyOk) {
    onProgress?.call('VERIFIED');
    onProgress?.call('DECRYPTING');
    final keys = await _deriveKeys(password, decoySalt);
    final internal =
        await _decryptBody(keys, decoyN1, decoyN2, decoyN3, decoyCt, decoyTag);
    if (!internal.success) {
      return DecryptResult(success: false, error: internal.error);
    }
    final result = await _writeDecrypted(filePath, internal);
    return DecryptResult(
      success: true,
      outputPath: result.outputPath,
      originalName: result.originalName,
      outputSize: result.outputSize,
      isDecoy: true,
    );
  }

  // ---- Duress password: permanently destroy the file ----
  if (duressOk) {
    await _shredFile(filePath);
    // Return the same error as a wrong password on purpose:
    // observers must not be able to tell that duress was triggered.
    return DecryptResult(
      success: false,
      error: 'WRONG_PASSWORD',
      duressTriggered: true,
    );
  }

  return DecryptResult(success: false, error: 'WRONG_PASSWORD');
}

/// Decrypt a V1 file (12-byte magic, or 11-byte buggy-old format).
Future<DecryptResult> _decryptV1(
  Uint8List fileData,
  String filePath,
  String password,
  int magicLen,
  ProgressCallback? onProgress,
) async {
  final minSize = magicLen + _saltSize + _nonceSize * 3 + _hmacSize + _tagSize;
  if (fileData.length < minSize) {
    return DecryptResult(success: false, error: 'FILE_TOO_SMALL');
  }

  var pos = magicLen;
  final salt = fileData.sublist(pos, pos + _saltSize);
  pos += _saltSize;
  final n1 = fileData.sublist(pos, pos + _nonceSize);
  pos += _nonceSize;
  final n2 = fileData.sublist(pos, pos + _nonceSize);
  pos += _nonceSize;
  final n3 = fileData.sublist(pos, pos + _nonceSize);
  pos += _nonceSize;
  final storedHmac = fileData.sublist(pos, pos + _hmacSize);
  pos += _hmacSize;

  final l3CtLen = fileData.length - pos - _tagSize;
  if (l3CtLen <= 0) {
    return DecryptResult(success: false, error: 'CORRUPT');
  }
  final l3Ct = fileData.sublist(pos, pos + l3CtLen);
  final t3 = fileData.sublist(pos + l3CtLen, pos + l3CtLen + _tagSize);

  onProgress?.call('VERIFYING');

  final vk = await _pbkdf2('$password::V', salt, _pbkdf2VIters, 32);
  final hData = BytesBuilder()
    ..add(salt)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final computedHmac = await _hmacSha256(vk, hData.toBytes());
  if (!_constantTimeEq(computedHmac, storedHmac)) {
    return DecryptResult(success: false, error: 'WRONG_PASSWORD');
  }

  onProgress?.call('VERIFIED');
  onProgress?.call('DECRYPTING');

  final keys = await _deriveKeys(password, salt);
  final internal = await _decryptBody(keys, n1, n2, n3, l3Ct, t3);
  if (!internal.success) {
    return DecryptResult(success: false, error: internal.error);
  }
  return await _writeDecrypted(filePath, internal);
}

Future<DecryptResult> decryptFile(
  String filePath,
  String password,
  ProgressCallback? onProgress,
) async {
  try {
    final fileData = _readFile(filePath);
    final format = detectFormat(fileData);

    if (format == fmtNone) {
      return DecryptResult(success: false, error: 'NOT_VCT');
    }

    if (format == fmtV2) {
      return await _decryptV2(fileData, filePath, password, onProgress);
    }

    if (format == fmtV1) {
      final result =
          await _decryptV1(fileData, filePath, password, 12, onProgress);
      // Edge case: old buggy file where salt[0] happened to be 0x00.
      // The 12-byte magic check passes (false positive), but data is
      // shifted - retry with the 11-byte offset.
      if (!result.success && result.error == 'WRONG_PASSWORD') {
        final result11 =
            await _decryptV1(fileData, filePath, password, 11, onProgress);
        if (result11.success) return result11;
      }
      return result;
    }

    // fmtV1Old: 11-byte buggy magic
    return await _decryptV1(fileData, filePath, password, 11, onProgress);
  } catch (e) {
    return DecryptResult(success: false, error: e.toString());
  }
}
