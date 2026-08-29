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

import 'vct_keys.dart';
import 'vendor/mlkem/mlkem.dart';

// ---- Constants ----
const _magicV1 = 'VCTCRYPT1\x00\x00\x00'; // 12 bytes (matches C: "VCTCRYPT1\0\0" + implicit C null)
const _magicV1Old = 'VCTCRYPT1\x00\x00'; // 11 bytes - buggy old Flutter format (missing trailing \0)
const _magicV2 = 'VCTCRYPT2\x00\x00\x00'; // 12 bytes
const _magicV3 = 'VCTCRYPT3\x00\x00\x00'; // 12 bytes - hybrid ML-KEM mode (v1.6.0)
const _magicLen = 12;
const _saltSize = 48;
const _nonceSize = 12;
const _tagSize = 16;
const _hmacSize = 32;
const _pbkdf2Iters = 600000;
// v2.1.0 (P0 fix): the verification key now uses the SAME full iteration
// count as the encryption keys. Before, it used 10k, letting an offline
// attacker test a candidate password 60x cheaper by only checking the
// header HMAC. Files written before 2.1.0 used a 10k verification key,
// so every verify/decrypt path falls back to the legacy count below.
const _pbkdf2VIters = 600000;
const _pbkdf2VItersLegacy = 10000;
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

// ---- V3 layout (hybrid ML-KEM, v1.6.0) ----
// Envelope: a random 32-byte CEK triple-encrypts the payload; the CEK
// is wrapped by one or two independent channels:
//   password channel : AES-GCM(PBKDF2("pw::V3", pwSalt), pwCt)
//   KEM channel      : (kemCt, ss) = ML-KEM-768.Encaps(ek_recipient)
//                      AES-GCM(HMAC(ss, "VCT3::KEM"||kemCt), kwCt)
//
// [magic 12][ver 1][flags 1][bodyCtLen 8]
// [KEM slot:  kemCt 1088][kwNonce 12][kwCt 32][kwTag 16]   (1148, filler when off)
// [PW slot:   pwSalt 48][pwNonce 12][pwCt 32][pwTag 16]    (108, filler when off)
// [body hdr:  salt2 48][n1 12][n2 12][n3 12][hmac 32]      (116)
// [bodyCt NB][bodyTag 16]
//
// flags bit0 = password channel active, bit1 = KEM channel active.
// Both slots are ALWAYS present (random filler when unused) so the
// file shape is uniform regardless of which channels are enabled.
// Body keys: k_i = HMAC(cek, "VCT3::i" || salt2), vk = HMAC(cek, "VCT3::V" || salt2)
// stored hmac = HMAC(vk, salt2 || n1 || n2 || n3)
const _v3VerOff = _magicLen; // 12
const _v3FlagsOff = _v3VerOff + 1; // 13
const _v3CtLenOff = _v3FlagsOff + 1; // 14
const _v3KemCtOff = _v3CtLenOff + 8; // 22
const _v3KemCtLen = 1088;
const _v3KwNonceOff = _v3KemCtOff + _v3KemCtLen; // 1110
const _v3KwCtOff = _v3KwNonceOff + _nonceSize; // 1122
const _v3KwTagOff = _v3KwCtOff + 32; // 1154
const _v3PwSaltOff = _v3KwTagOff + _tagSize; // 1170
const _v3PwNonceOff = _v3PwSaltOff + _saltSize; // 1218
const _v3PwCtOff = _v3PwNonceOff + _nonceSize; // 1230
const _v3PwTagOff = _v3PwCtOff + 32; // 1262
const _v3Salt2Off = _v3PwTagOff + _tagSize; // 1278
const _v3N1Off = _v3Salt2Off + _saltSize; // 1326
const _v3HmacOff = _v3N1Off + _nonceSize * 3; // 1362
const _v3HeaderLen = _v3HmacOff + _hmacSize; // 1394
const _v3LayoutVer = 0x01;
const _v3FlagPassword = 0x01;
const _v3FlagKem = 0x02;
const _kemCtLen = _v3KemCtLen;

// ---- Format codes ----
const fmtNone = 0;
const fmtV1 = 1; // 12-byte V1 magic (CLI-compatible)
const fmtV1Old = 2; // 11-byte buggy V1 magic (old Flutter builds)
const fmtV2 = 3; // V2 with decoy/duress slots
const fmtV3 = 4; // V3 hybrid envelope (password and/or ML-KEM-768)

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

/// Derive only the three body keys (no verification key). Used by the
/// V1/V2 decrypt path: the password was already verified by
/// _verifyPartitionHmac, so re-deriving the vk would be wasted work.
/// (v2.1.0 - keeps decrypt cost at 3x full-strength iterations.)
Future<_Keys> _deriveBodyKeys(
  String password,
  List<int> salt,
) async {
  final k1 = await _pbkdf2('$password::1', salt, _pbkdf2Iters, 32);
  final k2 = await _pbkdf2('$password::2', salt, _pbkdf2Iters, 32);
  final k3 = await _pbkdf2('$password::3', salt, _pbkdf2Iters, 32);
  return _Keys(k1, k2, k3, const []);
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
/// fmtNone (0) / fmtV1 (1) / fmtV1Old (2) / fmtV2 (3) / fmtV3 (4)
int detectFormat(Uint8List data) {
  if (data.length < 11) return fmtNone;

  if (data.length >= 12) {
    final v3 = utf8.encode(_magicV3);
    bool v3Match = true;
    for (int i = 0; i < 12; i++) {
      if (data[i] != v3[i]) {
        v3Match = false;
        break;
      }
    }
    if (v3Match) return fmtV3;

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
  /// One of [fmtV1], [fmtV1Old], [fmtV2], [fmtV3] or [fmtNone].
  final int format;

  /// Total file size in bytes.
  final int fileSize;

  /// File modification time.
  final DateTime modified;

  /// Size of the encrypted real payload (V2/V3 only; null for V1).
  final int? realCtLen;

  /// Header size in bytes (V3: 1394, V2: 332, V1/V1-old: 128).
  final int headerLen;

  /// V3 only: the file carries an active ML-KEM recipient channel.
  final bool hasKemChannel;

  /// V3 only: the file carries an active password channel.
  final bool hasPasswordChannel;

  const VctFileInfo({
    required this.format,
    required this.fileSize,
    required this.modified,
    this.realCtLen,
    required this.headerLen,
    this.hasKemChannel = false,
    this.hasPasswordChannel = false,
  });

  bool get isValid => format != fmtNone;
  bool get isV2 => format == fmtV2;
  bool get isV3 => format == fmtV3;
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
    final n = size < _v3HeaderLen ? size : _v3HeaderLen;
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

  if (format == fmtV3) {
    if (head.length < _v3HeaderLen) {
      return VctFileInfo(
        format: format,
        fileSize: size,
        modified: modified,
        headerLen: _v3HeaderLen,
      );
    }
    final ctLen = _readU64LE(head, _v3CtLenOff);
    final flags = head[_v3FlagsOff];
    return VctFileInfo(
      format: format,
      fileSize: size,
      modified: modified,
      realCtLen: ctLen,
      headerLen: _v3HeaderLen,
      hasKemChannel: (flags & _v3FlagKem) != 0,
      hasPasswordChannel: (flags & _v3FlagPassword) != 0,
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
/// v2.1.0: verifies with the full iteration count first (closes the cheap
/// 10k offline-brute-force shortcut), then falls back to the legacy 10k
/// count so files written before 2.1.0 still open.
Future<bool> _verifyPartitionHmac(
  String password,
  List<int> salt,
  List<int> n1,
  List<int> n2,
  List<int> n3,
  List<int> storedHmac,
) async {
  final hData = BytesBuilder()
    ..add(salt)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final hb = hData.toBytes();

  final vk = await _pbkdf2('$password::V', salt, _pbkdf2VIters, 32);
  final computed = await _hmacSha256(vk, hb);
  if (_constantTimeEq(computed, storedHmac)) return true;

  final legacyVk =
      await _pbkdf2('$password::V', salt, _pbkdf2VItersLegacy, 32);
  final legacyComputed = await _hmacSha256(legacyVk, hb);
  return _constantTimeEq(legacyComputed, storedHmac);
}

/// Verify the duress HMAC: HMAC(PBKDF2(duressPassword::V, xsalt), xsalt)
/// v2.1.0: full iteration count first, legacy 10k fallback for old files.
Future<bool> _verifyDuressHmac(
  String password,
  List<int> xsalt,
  List<int> storedHmac,
) async {
  final vk = await _pbkdf2('$password::V', xsalt, _pbkdf2VIters, 32);
  final computed = await _hmacSha256(vk, xsalt);
  if (_constantTimeEq(computed, storedHmac)) return true;

  final legacyVk =
      await _pbkdf2('$password::V', xsalt, _pbkdf2VItersLegacy, 32);
  final legacyComputed = await _hmacSha256(legacyVk, xsalt);
  return _constantTimeEq(legacyComputed, storedHmac);
}

/// Write decrypted bytes to a user-visible location.
/// (Desktop: next to the .VCT file. Mobile: app Documents / external files.)
/// [outputPath], when given, bypasses the location chooser (used by the
/// Secure Notes feature to keep plaintext out of Documents).
Future<DecryptResult> _writeDecrypted(String vctPath, _InternalResult internal,
    {String? outputPath}) async {
  final origName = internal.originalName ?? 'decrypted_file';
  final outPath =
      outputPath ?? await _chooseOutputPath(origName, vctPath);
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

  /// v1.6.0: the output is a V3 hybrid file with an ML-KEM recipient.
  final bool usedKem;
  EncryptResult({
    this.success = true,
    this.outputPath,
    this.outputSize,
    this.error,
    this.usedDecoy = false,
    this.usedDuress = false,
    this.shreddedOriginal = false,
    this.usedKem = false,
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
  String? outputPath,
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

    final outPath = outputPath ??
        await _chooseOutputPath(_encFileName(filePath), filePath);
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
/// full-strength 600K PBKDF2 iterations, v2.1.0) before we allow
/// shredding the original.
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

// ---- Hybrid V3 encryption (v1.6.0, ML-KEM-768) ----

/// Options for the hybrid envelope. At least ONE of [password] /
/// [recipient] must be given; both may be given (dual-channel file:
/// openable with the password OR the recipient's private key).
class HybridEncryptOptions {
  final String? password;
  final VctPublicKey? recipient;
  final bool shredOriginal;
  const HybridEncryptOptions({
    this.password,
    this.recipient,
    this.shredOriginal = false,
  });
}

/// Derive the body key set from the CEK (HMAC-based, mirroring the
/// V2 PBKDF2 key split: three AES keys + one verification key).
Future<_Keys> _v3DeriveBodyKeys(List<int> cek, List<int> salt2) async {
  Future<List<int>> k(String label) =>
      _hmacSha256(cek, utf8.encode(label).followedBy(salt2).toList());
  return _Keys(await k('VCT3::1'), await k('VCT3::2'), await k('VCT3::3'),
      await k('VCT3::V'));
}

/// Encrypt [payload] with the triple-GCM body under CEK-derived keys.
/// Returns the body header material + ciphertext + tag.
Future<({
  List<int> salt2,
  List<int> n1,
  List<int> n2,
  List<int> n3,
  List<int> hmac,
  List<int> ct,
  List<int> tag,
})> _v3EncryptBody(List<int> cek, List<int> payload) async {
  final salt2 = await _secureRandom(_saltSize);
  final n1 = await _secureRandom(_nonceSize);
  final n2 = await _secureRandom(_nonceSize);
  final n3 = await _secureRandom(_nonceSize);
  final keys = await _v3DeriveBodyKeys(cek, salt2);

  final l1 = await _aesGcmEncrypt(keys.k1, n1, payload);
  final l1b = BytesBuilder()..add(l1.tag)..add(l1.cipherText);
  final l2 = await _aesGcmEncrypt(keys.k2, n2, l1b.toBytes());
  final l2b = BytesBuilder()..add(l2.tag)..add(l2.cipherText);
  final l3 = await _aesGcmEncrypt(keys.k3, n3, l2b.toBytes());

  final hData = BytesBuilder()
    ..add(salt2)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final hmacVal = await _hmacSha256(keys.vk, hData.toBytes());

  return (
    salt2: salt2,
    n1: n1,
    n2: n2,
    n3: n3,
    hmac: hmacVal,
    ct: l3.cipherText,
    tag: l3.tag,
  );
}

/// Wrap the CEK into both channels and assemble the V3 container.
Future<Uint8List> _v3Assemble({
  required List<int> cek,
  required List<int> body,
  required ({List<int> salt2, List<int> n1, List<int> n2, List<int> n3,
      List<int> hmac, List<int> ct, List<int> tag}) enc,
  required bool usePassword,
  required bool useKem,
  String? password,
  VctPublicKey? recipient,
}) async {
  // --- KEM slot ---
  List<int> kemCt, kwNonce, kwCt, kwTag;
  if (useKem) {
    final (ct, ss) = _kem768.encapsulate(recipient!.ek);
    kemCt = ct;
    final wrapK = await _hmacSha256(
        ss, utf8.encode('VCT3::KEM').followedBy(ct).toList());
    final nonce = await _secureRandom(_nonceSize);
    final box = await _aesGcmEncrypt(wrapK, nonce, cek);
    kwNonce = nonce;
    kwCt = box.cipherText;
    kwTag = box.tag;
  } else {
    kemCt = await _secureRandom(_v3KemCtLen);
    kwNonce = await _secureRandom(_nonceSize);
    kwCt = await _secureRandom(32);
    kwTag = await _secureRandom(_tagSize);
  }

  // --- Password slot ---
  List<int> pwSalt, pwNonce, pwCt, pwTag;
  if (usePassword) {
    pwSalt = await _secureRandom(_saltSize);
    final wrap = await _pbkdf2('${password!}::V3', pwSalt, _pbkdf2Iters, 32);
    final nonce = await _secureRandom(_nonceSize);
    final box = await _aesGcmEncrypt(wrap, nonce, cek);
    pwNonce = nonce;
    pwCt = box.cipherText;
    pwTag = box.tag;
  } else {
    pwSalt = await _secureRandom(_saltSize);
    pwNonce = await _secureRandom(_nonceSize);
    pwCt = await _secureRandom(32);
    pwTag = await _secureRandom(_tagSize);
  }

  var flags = 0;
  if (usePassword) flags |= _v3FlagPassword;
  if (useKem) flags |= _v3FlagKem;

  final out = BytesBuilder();
  out.add(utf8.encode(_magicV3));
  out.addByte(_v3LayoutVer);
  out.addByte(flags);
  _writeU64LE(out, enc.ct.length);
  out.add(kemCt);
  out.add(kwNonce);
  out.add(kwCt);
  out.add(kwTag);
  out.add(pwSalt);
  out.add(pwNonce);
  out.add(pwCt);
  out.add(pwTag);
  out.add(enc.salt2);
  out.add(enc.n1);
  out.add(enc.n2);
  out.add(enc.n3);
  out.add(enc.hmac);
  out.add(enc.ct);
  out.add(enc.tag);
  return out.toBytes();
}

final _kem768 = PqcKem.kyber768;

/// Self-consistency proof of a freshly written V3 file BEFORE the
/// original may be shredded: re-read, re-parse, and re-check the body
/// HMAC with the CEK we still hold in memory.
Future<bool> _verifyWrittenV3(String outPath, List<int> cek) async {
  try {
    final data = _readFile(outPath);
    if (detectFormat(data) != fmtV3) return false;
    if (data.length < _v3HeaderLen + _tagSize) return false;
    if (data[_v3VerOff] != _v3LayoutVer) return false;

    final salt2 = data.sublist(_v3Salt2Off, _v3Salt2Off + _saltSize);
    final n1 = data.sublist(_v3N1Off, _v3N1Off + _nonceSize);
    final n2 = data.sublist(_v3N1Off + _nonceSize, _v3N1Off + _nonceSize * 2);
    final n3 = data.sublist(
        _v3N1Off + _nonceSize * 2, _v3N1Off + _nonceSize * 3);
    final stored = data.sublist(_v3HmacOff, _v3HmacOff + _hmacSize);

    final keys = await _v3DeriveBodyKeys(cek, salt2);
    final hData = BytesBuilder()
      ..add(salt2)
      ..add(n1)
      ..add(n2)
      ..add(n3);
    final computed = await _hmacSha256(keys.vk, hData.toBytes());
    return _constantTimeEq(computed, stored);
  } catch (_) {
    return false;
  }
}

/// Encrypt [filePath] into a V3 hybrid file. At least one channel
/// (password and/or recipient public key) must be active.
Future<EncryptResult> encryptFileHybrid(
  String filePath,
  HybridEncryptOptions options,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  try {
    final password = options.password;
    final recipient = options.recipient;
    final usePassword = password != null && password.isNotEmpty;
    final useKem = recipient != null;

    if (!usePassword && !useKem) {
      return EncryptResult(success: false, error: 'NO_UNLOCK_CHANNEL');
    }
    if (usePassword && password.length < 4) {
      return EncryptResult(success: false, error: 'PASSWORD_TOO_SHORT');
    }

    final fileData = _readFile(filePath);
    if (fileData.isEmpty) {
      return EncryptResult(success: false, error: 'EMPTY_FILE');
    }
    final payload = _buildPayload(filePath, fileData);

    // Fresh random CEK - never derived from anything guessable.
    final cek = await _secureRandom(32);

    onProgress?.call('DERIVING');

    // Encapsulate FIRST so an invalid recipient key fails before any
    // expensive body work (also keeps 'ENCRYPTING' semantics intact).
    Uint8List assembled;
    try {
      final enc = await _v3EncryptBody(cek, payload);
      onProgress?.call('ENCRYPTING');
      assembled = await _v3Assemble(
        cek: cek,
        body: payload,
        enc: enc,
        usePassword: usePassword,
        useKem: useKem,
        password: password,
        recipient: recipient,
      );
    } on ArgumentError {
      return EncryptResult(success: false, error: 'BAD_KEY_FILE');
    }

    final outPath = outputPath ??
        await _chooseOutputPath(_encFileName(filePath), filePath);
    _writeFile(outPath, assembled);

    var shredded = false;
    if (options.shredOriginal) {
      onProgress?.call('SHREDDING');
      final ok = await _verifyWrittenV3(outPath, cek);
      if (!ok) {
        return EncryptResult(success: false, error: 'SHRED_VERIFY_FAILED');
      }
      await _shredFile(filePath);
      shredded = true;
    }

    return EncryptResult(
      success: true,
      outputPath: outPath,
      outputSize: assembled.length,
      shreddedOriginal: shredded,
      usedKem: useKem,
    );
  } catch (e) {
    return EncryptResult(success: false, error: e.toString());
  }
}

/// Recover the CEK from the KEM channel with the recipient's private
/// key, then verify + decrypt the body.
Future<DecryptResult> _decryptV3WithKey(
  Uint8List fileData,
  String filePath,
  VctPrivateKey privateKey,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  final flags = fileData[_v3FlagsOff];
  if ((flags & _v3FlagKem) == 0) {
    return DecryptResult(success: false, error: 'KEY_NOT_APPLICABLE');
  }

  onProgress?.call('VERIFYING');
  final kemCt = fileData.sublist(_v3KemCtOff, _v3KemCtOff + _v3KemCtLen);
  final ss = privateKey.dk.length == 2400
      ? _kem768.decapsulate(privateKey.dk, kemCt)
      : throw const FormatException('bad dk');
  final wrapK = await _hmacSha256(
      ss, utf8.encode('VCT3::KEM').followedBy(kemCt).toList());
  final kwNonce = fileData.sublist(_v3KwNonceOff, _v3KwNonceOff + _nonceSize);
  final kwCt = fileData.sublist(_v3KwCtOff, _v3KwCtOff + 32);
  final kwTag = fileData.sublist(_v3KwTagOff, _v3KwTagOff + _tagSize);

  List<int> cek;
  try {
    cek = await _aesGcmDecrypt(wrapK, kwNonce, kwCt, kwTag);
  } catch (_) {
    return DecryptResult(success: false, error: 'WRONG_KEY');
  }

  return await _v3DecryptBody(cek, fileData, filePath, onProgress,
      outputPath: outputPath);
}

/// Shared V3 tail: verify body HMAC under the CEK, decrypt, write out.
Future<DecryptResult> _v3DecryptBody(
  List<int> cek,
  Uint8List fileData,
  String filePath,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  onProgress?.call('VERIFIED');
  onProgress?.call('DECRYPTING');

  final salt2 = fileData.sublist(_v3Salt2Off, _v3Salt2Off + _saltSize);
  final n1 = fileData.sublist(_v3N1Off, _v3N1Off + _nonceSize);
  final n2 =
      fileData.sublist(_v3N1Off + _nonceSize, _v3N1Off + _nonceSize * 2);
  final n3 =
      fileData.sublist(_v3N1Off + _nonceSize * 2, _v3N1Off + _nonceSize * 3);
  final storedHmac =
      fileData.sublist(_v3HmacOff, _v3HmacOff + _hmacSize);

  final keys = await _v3DeriveBodyKeys(cek, salt2);
  final hData = BytesBuilder()
    ..add(salt2)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final computed = await _hmacSha256(keys.vk, hData.toBytes());
  if (!_constantTimeEq(computed, storedHmac)) {
    return DecryptResult(success: false, error: 'CORRUPT');
  }

  final ctLen = _readU64LE(fileData, _v3CtLenOff);
  final bodyStart = _v3HeaderLen;
  final ctEnd = bodyStart + ctLen;
  if (ctLen <= 0 || ctEnd + _tagSize > fileData.length) {
    return DecryptResult(success: false, error: 'CORRUPT');
  }
  final bodyCt = fileData.sublist(bodyStart, ctEnd);
  final bodyTag = fileData.sublist(ctEnd, ctEnd + _tagSize);

  final internal =
      await _decryptBody(keys, n1, n2, n3, bodyCt, bodyTag);
  if (!internal.success) {
    return DecryptResult(success: false, error: internal.error);
  }
  return await _writeDecrypted(filePath, internal, outputPath: outputPath);
}

/// Decrypt a V3 file with the password channel.
Future<DecryptResult> _decryptV3WithPassword(
  Uint8List fileData,
  String filePath,
  String password,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  final flags = fileData[_v3FlagsOff];

  onProgress?.call('DERIVING');

  // Uniform work: always run the full PBKDF2 even when the channel is
  // inactive, so timing does not reveal which channels a file has.
  final pwSalt = fileData.sublist(_v3PwSaltOff, _v3PwSaltOff + _saltSize);
  final wrap = await _pbkdf2('${password}::V3', pwSalt, _pbkdf2Iters, 32);

  if ((flags & _v3FlagPassword) != 0) {
    final pwNonce =
        fileData.sublist(_v3PwNonceOff, _v3PwNonceOff + _nonceSize);
    final pwCt = fileData.sublist(_v3PwCtOff, _v3PwCtOff + 32);
    final pwTag = fileData.sublist(_v3PwTagOff, _v3PwTagOff + _tagSize);
    try {
      final cek = await _aesGcmDecrypt(wrap, pwNonce, pwCt, pwTag);
      return await _v3DecryptBody(cek, fileData, filePath, onProgress,
          outputPath: outputPath);
    } on SecretBoxAuthenticationError {
      return DecryptResult(success: false, error: 'WRONG_PASSWORD');
    } catch (_) {
      return DecryptResult(success: false, error: 'CORRUPT');
    }
  }

  // Password channel inactive: this file needs the private key.
  return DecryptResult(success: false, error: 'KEY_REQUIRED');
}

/// Public: decrypt a V3 file using a private key object (already
/// unwrapped from its .vctkey container by the UI layer).
Future<DecryptResult> decryptFileWithKey(
  String filePath,
  VctPrivateKey privateKey,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  try {
    final fileData = _readFile(filePath);
    final format = detectFormat(fileData);
    if (format == fmtNone) {
      return DecryptResult(success: false, error: 'NOT_VCT');
    }
    if (format != fmtV3) {
      return DecryptResult(success: false, error: 'KEY_NOT_APPLICABLE');
    }
    if (fileData.length < _v3HeaderLen + _tagSize) {
      return DecryptResult(success: false, error: 'FILE_TOO_SMALL');
    }
    if (fileData[_v3VerOff] != _v3LayoutVer) {
      return DecryptResult(success: false, error: 'UNSUPPORTED_FORMAT');
    }
    return await _decryptV3WithKey(fileData, filePath, privateKey, onProgress,
        outputPath: outputPath);
  } on FormatException {
    return DecryptResult(success: false, error: 'BAD_KEY_FILE');
  } on ArgumentError {
    return DecryptResult(success: false, error: 'BAD_KEY_FILE');
  } catch (e) {
    return DecryptResult(success: false, error: e.toString());
  }
}

// ---- Decryption ----

Future<DecryptResult> _decryptV2(
  Uint8List fileData,
  String filePath,
  String password,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
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
    final keys = await _deriveBodyKeys(password, realSalt);
    final internal = await _decryptBody(keys, realN1, realN2, realN3, realCt, realTag);
    if (!internal.success) {
      return DecryptResult(success: false, error: internal.error);
    }
    return await _writeDecrypted(filePath, internal, outputPath: outputPath);
  }

  // ---- Decoy password (identical success behavior - deniability) ----
  if (decoyOk) {
    onProgress?.call('VERIFIED');
    onProgress?.call('DECRYPTING');
    final keys = await _deriveBodyKeys(password, decoySalt);
    final internal =
        await _decryptBody(keys, decoyN1, decoyN2, decoyN3, decoyCt, decoyTag);
    if (!internal.success) {
      return DecryptResult(success: false, error: internal.error);
    }
    final result = await _writeDecrypted(filePath, internal, outputPath: outputPath);
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
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
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

  // v2.1.0 (P0 fix): verify at full iteration count, then fall back to
  // the legacy 10k count so files written before 2.1.0 still open.
  final vk = await _pbkdf2('$password::V', salt, _pbkdf2VIters, 32);
  final hData = BytesBuilder()
    ..add(salt)
    ..add(n1)
    ..add(n2)
    ..add(n3);
  final hb = hData.toBytes();
  var vkOk = _constantTimeEq(
    await _hmacSha256(vk, hb),
    storedHmac,
  );
  if (!vkOk) {
    final legacyVk =
        await _pbkdf2('$password::V', salt, _pbkdf2VItersLegacy, 32);
    vkOk = _constantTimeEq(await _hmacSha256(legacyVk, hb), storedHmac);
  }
  if (!vkOk) {
    return DecryptResult(success: false, error: 'WRONG_PASSWORD');
  }

  onProgress?.call('VERIFIED');
  onProgress?.call('DECRYPTING');

  final keys = await _deriveBodyKeys(password, salt);
  final internal = await _decryptBody(keys, n1, n2, n3, l3Ct, t3);
  if (!internal.success) {
    return DecryptResult(success: false, error: internal.error);
  }
  return await _writeDecrypted(filePath, internal, outputPath: outputPath);
}

Future<DecryptResult> decryptFile(
  String filePath,
  String password,
  ProgressCallback? onProgress, {
  String? outputPath,
}) async {
  try {
    final fileData = _readFile(filePath);
    final format = detectFormat(fileData);

    if (format == fmtNone) {
      return DecryptResult(success: false, error: 'NOT_VCT');
    }

    if (format == fmtV3) {
      if (fileData.length < _v3HeaderLen + _tagSize) {
        return DecryptResult(success: false, error: 'FILE_TOO_SMALL');
      }
      if (fileData[_v3VerOff] != _v3LayoutVer) {
        return DecryptResult(success: false, error: 'UNSUPPORTED_FORMAT');
      }
      return await _decryptV3WithPassword(fileData, filePath, password,
          onProgress,
          outputPath: outputPath);
    }

    if (format == fmtV2) {
      return await _decryptV2(fileData, filePath, password, onProgress,
        outputPath: outputPath);
    }

    if (format == fmtV1) {
      final result =
          await _decryptV1(fileData, filePath, password, 12, onProgress,
            outputPath: outputPath);
      // Edge case: old buggy file where salt[0] happened to be 0x00.
      // The 12-byte magic check passes (false positive), but data is
      // shifted - retry with the 11-byte offset.
      if (!result.success && result.error == 'WRONG_PASSWORD') {
        final result11 =
            await _decryptV1(fileData, filePath, password, 11, onProgress,
            outputPath: outputPath);
        if (result11.success) return result11;
      }
      return result;
    }

    // fmtV1Old: 11-byte buggy magic
    return await _decryptV1(fileData, filePath, password, 11, onProgress,
            outputPath: outputPath);
  } catch (e) {
    return DecryptResult(success: false, error: e.toString());
  }
}

// ---- Secure Notes (v1.5.0) ----

/// Marker prefix for the embedded payload name of Secure Notes. The note
/// itself is a completely ordinary VCT file - the marker only lets the
/// Notes screen recognize its own notes.
const noteNamePrefix = 'VCTCrypt-Note-';

/// Encrypt an in-memory text note into a normal .VCT file (format-
/// compatible with every VCTCrypt release and the CLI).
///
/// [outputPath] is REQUIRED on desktop (chosen via the save dialog); on
/// mobile leave it null and the output lands in Documents like a regular
/// encryption.
Future<EncryptResult> encryptText(
  String text,
  String password,
  ProgressCallback? onProgress, {
  EncryptOptions? options,
  String? outputPath,
}) async {
  final ts = DateTime.now();
  final stamp = '${ts.year}${_two(ts.month)}${_two(ts.day)}-'
      '${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}';
  final tmp = File(p.join(
    Directory.systemTemp.path,
    '$noteNamePrefix$stamp.txt',
  ));
  try {
    tmp.writeAsStringSync(text, flush: true);
    return await encryptFile(
      tmp.path,
      password,
      onProgress,
      options: options,
      outputPath: outputPath,
    );
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

/// Result of [decryptFileToText]: the note text plus the flags the UI
/// needs for identical-success decoy handling.
class TextDecryptResult {
  final bool success;
  final String? text;
  final String? originalName;
  final String? error;
  final bool isDecoy;
  final bool duressTriggered;
  const TextDecryptResult({
    this.success = false,
    this.text,
    this.originalName,
    this.error,
    this.isDecoy = false,
    this.duressTriggered = false,
  });
}

/// Decrypt a .VCT file to TEXT in memory. The plaintext is written to a
/// temporary location ONLY transiently, then shredded - it never lands
/// in Documents / next to the .VCT file. Nothing is left on disk.
Future<TextDecryptResult> decryptFileToText(
  String vctPath,
  String password,
  ProgressCallback? onProgress,
) async {
  final tmp = File(p.join(
    Directory.systemTemp.path,
    'vctcrypt_textout_${DateTime.now().microsecondsSinceEpoch}.tmp',
  ));
  try {
    final result = await decryptFile(
      vctPath,
      password,
      onProgress,
      outputPath: tmp.path,
    );
    if (!result.success) {
      return TextDecryptResult(
        success: false,
        error: result.error,
        duressTriggered: result.duressTriggered,
      );
    }
    final text = utf8.decode(tmp.readAsBytesSync(), allowMalformed: true);
    return TextDecryptResult(
      success: true,
      text: text,
      originalName: result.originalName,
      isDecoy: result.isDecoy,
    );
  } on FormatException {
    // utf8.decode with allowMalformed never throws, but stay defensive.
    return TextDecryptResult(success: false, error: 'NOT_TEXT');
  } catch (e) {
    return TextDecryptResult(success: false, error: e.toString());
  } finally {
    if (tmp.existsSync()) {
      try {
        await _shredFile(tmp.path);
      } catch (_) {
        try {
          tmp.deleteSync();
        } catch (_) {}
      }
    }
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
