/// VCTCrypt - key pair containers for the hybrid ML-KEM mode (v1.6.0)
///
/// Two container types (both plain files the user can move/share):
///
///   .vctpub  PUBLIC key ("recipient key") - not secret, share it with
///            anyone who should be able to encrypt files TO you.
///
///   .vctkey  PRIVATE key - ALWAYS stored password-wrapped. The wrap
///            password only protects the key FILE; it is unrelated to
///            any .VCT file password. Losing it loses every file that
///            was encrypted to this key.
///
/// Layouts (ML-KEM-768 only in v1.6.0, kpar byte reserved for 512/1024):
///
///   public:  [magic 8 "VCTKEY1\0"] [type 0x01] [kpar 0x03]
///            [name_len 2 LE] [name UTF-8] [ek 1184]
///
///   private: [magic 8] [type 0x02] [kpar 0x03] [name_len 2] [name]
///            [salt 48] [nonce 12] [ct 2400] [tag 16]
///            wrap = AES-256-GCM(PBKDF2("pw::VCTKEY", salt, 600000, 32))
///
/// All parsing is strict: bad magic, wrong type byte, unknown parameter
/// set or truncated key material is rejected.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vendor/mlkem/mlkem.dart';

// ---- Constants ----
const keyMagic = 'VCTKEY1\x00'; // 8 bytes
const _magicLen = 8;
const keyTypePublic = 0x01;
const keyTypePrivate = 0x02;
const kparMlKem768 = 0x03;

const _ekLen = 1184; // ML-KEM-768 public key
const _dkLen = 2400; // ML-KEM-768 private key
const _saltLen = 48;
const _nonceLen = 12;
const _tagLen = 16;
const _wrapIters = 600000;
const _maxName = 200;

final _kem = PqcKem.kyber768;
final _rng = Random.secure();

// ---- Errors ----
/// Caller-facing error codes (mapped by the UI).
const errBadKeyFile = 'BAD_KEY_FILE';
const errWrongKeyPassword = 'WRONG_KEY_PASSWORD';
const errUnsupportedKeyParams = 'UNSUPPORTED_KEY_PARAMS';

/// Thrown by parsers with one of the err* codes above.
class KeyFileException implements Exception {
  final String code;
  const KeyFileException(this.code);
  @override
  String toString() => 'KeyFileException($code)';
}

// ---- Public key ----

class VctPublicKey {
  final String name;
  final Uint8List ek;

  const VctPublicKey({required this.name, required this.ek});

  /// Short display id taken from the first bytes of the key itself
  /// ("A1B2C3D4" style hex) - enough to eyeball-match two exports.
  String get fingerprint {
    final b = ek.sublist(0, 4);
    return b
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  Uint8List serialize() {
    final nameBytes = utf8.encode(name);
    if (nameBytes.isEmpty || nameBytes.length > _maxName) {
      throw const KeyFileException(errBadKeyFile);
    }
    final out = BytesBuilder();
    out.add(utf8.encode(keyMagic));
    out.addByte(keyTypePublic);
    out.addByte(kparMlKem768);
    out.addByte(nameBytes.length & 0xFF);
    out.addByte((nameBytes.length >> 8) & 0xFF);
    out.add(nameBytes);
    out.add(ek);
    return out.toBytes();
  }

  /// Strict parse of a .vctpub container.
  static VctPublicKey parse(Uint8List data) {
    _checkContainerHeader(data, keyTypePublic);
    final nameLen = data[_magicLen + 2] | (data[_magicLen + 3] << 8);
    final nameEnd = _magicLen + 4 + nameLen;
    if (nameEnd + _ekLen != data.length) {
      throw const KeyFileException(errBadKeyFile);
    }
    String name;
    try {
      name = utf8.decode(data.sublist(_magicLen + 4, nameEnd));
    } catch (_) {
      throw const KeyFileException(errBadKeyFile);
    }
    return VctPublicKey(
      name: name,
      ek: Uint8List.fromList(data.sublist(nameEnd)),
    );
  }
}

// ---- Private key (password-wrapped container) ----

class VctPrivateKey {
  final String name;
  final Uint8List dk;

  const VctPrivateKey({required this.name, required this.dk});

  /// The matching public key is embedded verbatim inside dk:
  /// dk = s(1152) || ek(1184) || H(ek)(32) || z(32)  for ML-KEM-768.
  VctPublicKey get publicKey => VctPublicKey(
        name: name,
        ek: Uint8List.fromList(dk.sublist(1152, 1152 + _ekLen)),
      );

  /// Wrap [dk] with [password] and serialize the container.
  Future<Uint8List> serializeWrapped(String password) async {
    final nameBytes = utf8.encode(name);
    if (nameBytes.isEmpty || nameBytes.length > _maxName) {
      throw const KeyFileException(errBadKeyFile);
    }
    final salt = _secureBytes(_saltLen);
    final nonce = _secureBytes(_nonceLen);

    final wrap = await _pbkdf2('${password}::VCTKEY', salt, 32);
    final box = await _gcmEncrypt(wrap, nonce, dk);

    final out = BytesBuilder();
    out.add(utf8.encode(keyMagic));
    out.addByte(keyTypePrivate);
    out.addByte(kparMlKem768);
    out.addByte(nameBytes.length & 0xFF);
    out.addByte((nameBytes.length >> 8) & 0xFF);
    out.add(nameBytes);
    out.add(salt);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac);
    return out.toBytes();
  }

  /// Unwrap a .vctkey container. Throws [KeyFileException] with
  /// errWrongKeyPassword when the password does not match.
  static Future<VctPrivateKey> parseWrapped(
      Uint8List data, String password) async {
    _checkContainerHeader(data, keyTypePrivate);
    final nameLen = data[_magicLen + 2] | (data[_magicLen + 3] << 8);
    final bodyStart = _magicLen + 4 + nameLen;
    if (bodyStart + _saltLen + _nonceLen + _dkLen + _tagLen != data.length) {
      throw const KeyFileException(errBadKeyFile);
    }
    String name;
    try {
      name = utf8.decode(data.sublist(_magicLen + 4, bodyStart));
    } catch (_) {
      throw const KeyFileException(errBadKeyFile);
    }

    var pos = bodyStart;
    final salt = Uint8List.sublistView(data, pos, pos + _saltLen);
    pos += _saltLen;
    final nonce = Uint8List.sublistView(data, pos, pos + _nonceLen);
    pos += _nonceLen;
    final ct = Uint8List.sublistView(data, pos, pos + _dkLen);
    pos += _dkLen;
    final tag = Uint8List.sublistView(data, pos, pos + _tagLen);

    final wrap = await _pbkdf2('${password}::VCTKEY', salt, 32);
    Uint8List dk;
    try {
      dk = await _gcmDecrypt(wrap, nonce, ct, tag);
    } on SecretBoxAuthenticationError {
      throw const KeyFileException(errWrongKeyPassword);
    }
    return VctPrivateKey(name: name, dk: dk);
  }
}

// ---- Generation & file IO ----

/// Generate a fresh ML-KEM-768 key pair named [name].
(VctPublicKey, VctPrivateKey) generateKeyPair(String name) {
  final (ek, dk) = _kem.generateKeyPair();
  return (
    VctPublicKey(name: name, ek: ek),
    VctPrivateKey(name: name, dk: dk),
  );
}

/// Sniff a key container: returns keyTypePublic / keyTypePrivate, or
/// throws KeyFileException(errBadKeyFile).
int sniffKeyType(Uint8List data) {
  final magic = utf8.encode(keyMagic);
  if (data.length < _magicLen + 4) {
    throw const KeyFileException(errBadKeyFile);
  }
  for (var i = 0; i < _magicLen; i++) {
    if (data[i] != magic[i]) throw const KeyFileException(errBadKeyFile);
  }
  final type = data[_magicLen];
  if (type != keyTypePublic && type != keyTypePrivate) {
    throw const KeyFileException(errBadKeyFile);
  }
  return type;
}

/// Where key files live (the same user-visible location encrypted
/// outputs go: Documents on every platform).
Future<String> keysDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

/// Unique path for a new key file: name.vctpub, name (1).vctpub, ...
Future<String> uniqueKeyPath(String dir, String name, String ext) async {
  var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (safe.isEmpty) safe = 'key';
  if (safe.length > 60) safe = safe.substring(0, 60);
  var candidate = p.join(dir, '$safe$ext');
  var i = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$safe ($i)$ext');
    i++;
  }
  return candidate;
}

/// Atomic write (same pattern as the .VCT writer: temp + rename).
void writeKeyFile(String path, List<int> bytes) {
  final tmp = File('$path.vctpart');
  try {
    tmp.writeAsBytesSync(bytes, flush: true);
    tmp.renameSync(path);
  } on FileSystemException {
    if (tmp.existsSync()) tmp.deleteSync();
    File(path).writeAsBytesSync(bytes);
  }
}

// ---- internals ----

void _checkContainerHeader(Uint8List data, int expectedType) {
  final magic = utf8.encode(keyMagic);
  if (data.length < _magicLen + 4) {
    throw const KeyFileException(errBadKeyFile);
  }
  for (var i = 0; i < _magicLen; i++) {
    if (data[i] != magic[i]) throw const KeyFileException(errBadKeyFile);
  }
  if (data[_magicLen] != expectedType) {
    throw const KeyFileException(errBadKeyFile);
  }
  if (data[_magicLen + 1] != kparMlKem768) {
    throw const KeyFileException(errUnsupportedKeyParams);
  }
}

Uint8List _secureBytes(int len) {
  final b = Uint8List(len);
  for (var i = 0; i < len; i++) {
    b[i] = _rng.nextInt(256);
  }
  return b;
}

Future<List<int>> _pbkdf2(String password, List<int> salt, int outLen) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _wrapIters,
    bits: outLen * 8,
  );
  final derived = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return derived.extractBytes();
}

Future<({Uint8List cipherText, Uint8List mac})> _gcmEncrypt(
    List<int> key, List<int> nonce, List<int> plain) async {
  final box = await AesGcm.with256bits().encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: nonce,
  );
  return (
    cipherText: Uint8List.fromList(box.cipherText),
    mac: Uint8List.fromList(box.mac.bytes),
  );
}

Future<Uint8List> _gcmDecrypt(
    List<int> key, List<int> nonce, List<int> ct, List<int> tag) async {
  final clear = await AesGcm.with256bits().decrypt(
    SecretBox(ct, nonce: nonce, mac: Mac(tag)),
    secretKey: SecretKey(key),
  );
  return Uint8List.fromList(clear);
}
