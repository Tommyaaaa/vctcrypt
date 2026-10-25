/// VCTCrypt - core engine test suite (v1.6.0)
///
/// Groups:
///   1. ML-KEM-768 Known Answer Tests - fixed vectors generated with
///      Go's crypto/mlkem (see tool/mlkem_interop.dart). Failures here
///      mean the vendored implementation no longer matches the FIPS 203
///      reference behaviour.
///   2. Key containers (.vctpub / .vctkey) roundtrip + failure paths.
///   3. V1 password format roundtrip (CLI compatibility).
///   4. V3 hybrid envelope: dual-channel, key-only, wrong-key and
///      wrong-channel errors.
///
/// Note: every password-channel operation burns a 600K-iteration
/// PBKDF2 (that is the product's design), so this suite takes ~30-60s.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:vctcrypt/crypto/vendor/mlkem/mlkem.dart';

import 'package:vctcrypt/crypto/vct_crypto.dart' as crypto;
import 'package:vctcrypt/crypto/vct_keys.dart' as keys;

const _katAsset = 'test/mlkem768_kat.json';

Uint8List _unhex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16),
    ]);

late Directory _tmp;
File _tmpFile(String name, List<int> bytes) {
  final f = File('${_tmp.path}/$name');
  f.writeAsBytesSync(bytes, flush: true);
  return f;
}

List<int> _rand(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

/// v2.5.0 (M4): build a genuine legacy V1 file (12-byte magic) or the
/// 11-byte buggy variant, using the exact derivation the 1.x releases
/// used. This is a fixture generator only - production code never writes
/// V1 any more, so it is the only way to prove old files still open.
Future<Uint8List> _buildLegacyV1({
  required String name,
  required List<int> data,
  required String password,
  bool oldMagic = false,
}) async {
  const saltLen = 48, nonceLen = 12;
  final salt = _rand(saltLen);
  final n1 = _rand(nonceLen);
  final n2 = _rand(nonceLen);
  final n3 = _rand(nonceLen);

  Future<List<int>> pb(String label) async {
    final p =
        Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 600000, bits: 256);
    final k = await p.deriveKey(
        secretKey: SecretKey(utf8.encode('$password::$label')), nonce: salt);
    return k.extractBytes();
  }

  final vk = await pb('V');
  final k1 = await pb('1');
  final k2 = await pb('2');
  final k3 = await pb('3');

  Future<({List<int> ct, List<int> tag})> enc(
      List<int> key, List<int> nonce, List<int> pt) async {
    final box = await AesGcm.with256bits()
        .encrypt(pt, secretKey: SecretKey(key), nonce: nonce);
    return (ct: box.cipherText, tag: box.mac.bytes);
  }

  final nameBytes = utf8.encode(name);
  final payload = <int>[
    nameBytes.length & 0xFF,
    (nameBytes.length >> 8) & 0xFF,
    ...nameBytes,
    ...data,
  ];

  final l1 = await enc(k1, n1, payload);
  final l2 = await enc(k2, n2, [...l1.tag, ...l1.ct]);
  final l3 = await enc(k3, n3, [...l2.tag, ...l2.ct]);

  final hmac = await Hmac.sha256()
      .calculateMac([...salt, ...n1, ...n2, ...n3], secretKey: SecretKey(vk));

  final magic = oldMagic
      ? utf8.encode('VCTCRYPT1\x00\x00')
      : utf8.encode('VCTCRYPT1\x00\x00\x00');

  return Uint8List.fromList([
    ...magic,
    ...salt,
    ...n1,
    ...n2,
    ...n3,
    ...hmac.bytes,
    ...l3.ct,
    ...l3.tag,
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Path provider is never used by these code paths; stub the channel
  // anyway so any accidental use fails loudly instead of hanging.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              throw StateError('path_provider must not be used here'));

  setUpAll(() {
    _tmp = Directory.systemTemp.createTempSync('vctcrypt_test');
  });
  tearDownAll(() {
    _tmp.deleteSync(recursive: true);
  });

  // ============================================================
  // 1. ML-KEM-768 KAT (Go crypto/mlkem reference vectors)
  // ============================================================
  group('ML-KEM-768 KAT (Go cross-validation)', () {
    final kat = (jsonDecode(File(_katAsset).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    test('fixture has vectors', () {
      expect(kat, isNotEmpty);
      for (final v in kat) {
        expect(_unhex(v['ek'] as String).length, 1184);
        expect(_unhex(v['dk'] as String).length, 2400);
        expect(_unhex(v['ct'] as String).length, 1088);
        expect(_unhex(v['ss'] as String).length, 32);
      }
    });

    for (var i = 0; i < kat.length; i++) {
      test('vector $i: encapsulate matches', () {
        final kem = PqcKem.kyber768;
        final ek = _unhex(kat[i]['ek'] as String);
        final m = _unhex(kat[i]['m'] as String);
        final ct = _unhex(kat[i]['ct'] as String);
        final ss = _unhex(kat[i]['ss'] as String);

        final (outCt, outSs) = kem.encapsulate(ek, m);
        expect(outCt, equals(ct));
        expect(outSs, equals(ss));
      });

      test('vector $i: decapsulate matches', () {
        final kem = PqcKem.kyber768;
        final dk = _unhex(kat[i]['dk'] as String);
        final ct = _unhex(kat[i]['ct'] as String);
        final ss = _unhex(kat[i]['ss'] as String);

        expect(kem.decapsulate(dk, ct), equals(ss));
      });
    }

    test('implicit rejection: tampered ciphertext yields a different key', () {
      final kem = PqcKem.kyber768;
      final dk = _unhex(kat[0]['dk'] as String);
      final ct = _unhex(kat[0]['ct'] as String);
      final ss = _unhex(kat[0]['ss'] as String);

      final bad = Uint8List.fromList(ct)..[0] ^= 0x01;
      final ssBad = kem.decapsulate(dk, bad);
      expect(ssBad, isNot(equals(ss)));
      expect(ssBad.length, 32);
    });

    test('invalid public key length is rejected', () {
      final kem = PqcKem.kyber768;
      expect(() => kem.encapsulate(Uint8List(1183)),
          throwsA(isA<ArgumentError>()));
    });
  });

  // ============================================================
  // 2. Key containers
  // ============================================================
  group('key containers', () {
    test('.vctpub serialize/parse roundtrip + fingerprint', () {
      final (pub, _) = keys.generateKeyPair('Laptop');
      final bytes = pub.serialize();
      final parsed = keys.VctPublicKey.parse(bytes);

      expect(parsed.name, 'Laptop');
      expect(parsed.ek, equals(pub.ek));
      expect(parsed.fingerprint, pub.fingerprint);
      expect(parsed.fingerprint, hasLength(16));
      expect(keys.sniffKeyType(bytes), keys.keyTypePublic);
    });

    test('.vctkey wrap/unwrap roundtrip embeds the public key', () async {
      final (pub, priv) = keys.generateKeyPair('Tommy');
      final wrapped = await priv.serializeWrapped('hunter22');
      expect(keys.sniffKeyType(wrapped), keys.keyTypePrivate);

      final unwrapped =
          await keys.VctPrivateKey.parseWrapped(wrapped, 'hunter22');
      expect(unwrapped.name, 'Tommy');
      expect(unwrapped.dk, equals(priv.dk));
      expect(unwrapped.publicKey.ek, equals(pub.ek));
      expect(unwrapped.publicKey.name, 'Tommy');
    });

    test('wrong wrap password -> WRONG_KEY_PASSWORD', () async {
      final (_, priv) = keys.generateKeyPair('x');
      final wrapped = await priv.serializeWrapped('correct horse');
      expect(
        () => keys.VctPrivateKey.parseWrapped(wrapped, 'wrong battery'),
        throwsA(isA<keys.KeyFileException>()
            .having((e) => e.code, 'code', keys.errWrongKeyPassword)),
      );
    });

    test('corrupted / non-key file -> BAD_KEY_FILE', () {
      expect(
        () => keys.VctPublicKey.parse(Uint8List.fromList(List.filled(1200, 7))),
        throwsA(isA<keys.KeyFileException>()
            .having((e) => e.code, 'code', keys.errBadKeyFile)),
      );
      expect(
        () => keys.sniffKeyType(Uint8List(10)),
        throwsA(isA<keys.KeyFileException>()),
      );
    });

    test('.vctpub container is not accepted as a private key', () async {
      final (pub, _) = keys.generateKeyPair('y');
      final bytes = pub.serialize();
      expect(
        () async => keys.VctPrivateKey.parseWrapped(bytes, 'whatever'),
        throwsA(isA<keys.KeyFileException>()),
      );
    });
  });

  // ============================================================
  // 3. Password format: current release writes V4 (v2.5.0), older
  //    V1/V2/V3 files must still open.
  // ============================================================
  group('password format (V4 current)', () {
    test('encrypt/decrypt roundtrip', () async {
      final src =
          _tmpFile('hello.txt', utf8.encode('hello VCTCrypt v1 roundtrip'));
      final enc = await crypto.encryptFile(src.path, 'pass1234', null);
      expect(enc.success, isTrue);
      expect(enc.usedKem, isFalse);
      expect(enc.outputPath, endsWith('.VCT'));

      final dec = await crypto.decryptFile(enc.outputPath!, 'pass1234', null);
      expect(dec.success, isTrue);
      expect(dec.originalName, 'hello.txt');
      expect(File(dec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('hello VCTCrypt v1 roundtrip')));

      expect(crypto.detectFormat(File(enc.outputPath!).readAsBytesSync()),
          crypto.fmtV4);
    });

    test('wrong password -> WRONG_PASSWORD', () async {
      final src = _tmpFile('secret.bin', List.generate(1024, (i) => i & 0xFF));
      final enc = await crypto.encryptFile(src.path, 'right-pass', null);
      final dec = await crypto.decryptFile(enc.outputPath!, 'wrong-pass', null);
      expect(dec.success, isFalse);
      expect(dec.error, 'WRONG_PASSWORD');
    });

    test('legacy V1 file (12-byte magic) still opens', () async {
      final fixture = await _buildLegacyV1(
        name: 'legacy.txt',
        data: utf8.encode('written by VCTCrypt 1.x'),
        password: 'old-pass',
      );
      final f = _tmpFile('legacy_v1.VCT', fixture);
      expect(crypto.detectFormat(fixture), crypto.fmtV1);

      final dec = await crypto.decryptFile(f.path, 'old-pass', null);
      expect(dec.success, isTrue, reason: dec.error ?? '');
      expect(dec.originalName, 'legacy.txt');
      expect(File(dec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('written by VCTCrypt 1.x')));
    });

    test('legacy buggy V1 file (11-byte magic) still opens', () async {
      final fixture = await _buildLegacyV1(
        name: 'buggy.txt',
        data: utf8.encode('old flutter build'),
        password: 'old-pass',
        oldMagic: true,
      );
      final f = _tmpFile('legacy_v1old.VCT', fixture);
      expect(crypto.detectFormat(fixture), crypto.fmtV1Old);

      final dec = await crypto.decryptFile(f.path, 'old-pass', null);
      expect(dec.success, isTrue, reason: dec.error ?? '');
      expect(File(dec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('old flutter build')));
    });
  });

  // ============================================================
  // 4. V3 hybrid envelope (ML-KEM-768)
  // ============================================================
  group('V3 hybrid envelope', () {
    test('dual channel: password AND private key both open the file', () async {
      final payload =
          List.generate(4096, (i) => (i * 31) & 0xFF); // 4 KiB binary
      final src = _tmpFile('photo.bin', payload);
      final (pub, priv) = keys.generateKeyPair('Tester');

      final enc = await crypto.encryptFileHybrid(
        src.path,
        crypto.HybridEncryptOptions(password: 'dual-pass', recipient: pub),
        null,
      );
      expect(enc.success, isTrue, reason: enc.error ?? '');
      expect(enc.usedKem, isTrue);

      final v3Bytes = File(enc.outputPath!).readAsBytesSync();
      expect(crypto.detectFormat(v3Bytes), crypto.fmtV3);

      // Channel A: the password opens it.
      final decPw =
          await crypto.decryptFile(enc.outputPath!, 'dual-pass', null);
      expect(decPw.success, isTrue, reason: decPw.error ?? '');
      expect(decPw.originalName, 'photo.bin');
      expect(File(decPw.outputPath!).readAsBytesSync(), equals(payload));

      // Channel B: the private key opens it too.
      final decKey =
          await crypto.decryptFileWithKey(enc.outputPath!, priv, null);
      expect(decKey.success, isTrue, reason: decKey.error ?? '');
      expect(File(decKey.outputPath!).readAsBytesSync(), equals(payload));
    });

    test('key-only: password path reports KEY_REQUIRED, key path works',
        () async {
      final src =
          _tmpFile('keys_only.dat', utf8.encode('post-quantum payload'));
      final (pub, priv) = keys.generateKeyPair('KeyOnly');

      final enc = await crypto.encryptFileHybrid(
        src.path,
        crypto.HybridEncryptOptions(recipient: pub), // no password
        null,
      );
      expect(enc.success, isTrue, reason: enc.error ?? '');
      expect(enc.usedKem, isTrue);

      // Any password hits the inactive channel -> KEY_REQUIRED.
      final decPw = await crypto.decryptFile(enc.outputPath!, 'anything', null);
      expect(decPw.success, isFalse);
      expect(decPw.error, 'KEY_REQUIRED');

      // The private key works.
      final decKey =
          await crypto.decryptFileWithKey(enc.outputPath!, priv, null);
      expect(decKey.success, isTrue, reason: decKey.error ?? '');
      expect(File(decKey.outputPath!).readAsBytesSync(),
          equals(utf8.encode('post-quantum payload')));
    });

    test('wrong key -> WRONG_KEY', () async {
      final src = _tmpFile('wrongkey.txt', utf8.encode('not for you'));
      final (pub, _) = keys.generateKeyPair('Right');
      final (_, wrongPriv) = keys.generateKeyPair('Wrong');

      final enc = await crypto.encryptFileHybrid(
        src.path,
        crypto.HybridEncryptOptions(recipient: pub),
        null,
      );
      expect(enc.success, isTrue);

      final dec =
          await crypto.decryptFileWithKey(enc.outputPath!, wrongPriv, null);
      expect(dec.success, isFalse);
      expect(dec.error, 'WRONG_KEY');
    });

    test('private key cannot open a V1 password file -> KEY_NOT_APPLICABLE',
        () async {
      final src = _tmpFile('legacy.txt', utf8.encode('legacy data'));
      final (_, priv) = keys.generateKeyPair('L');

      final enc = await crypto.encryptFile(src.path, 'legacy-pass', null);
      expect(enc.success, isTrue);

      final dec = await crypto.decryptFileWithKey(enc.outputPath!, priv, null);
      expect(dec.success, isFalse);
      expect(dec.error, 'KEY_NOT_APPLICABLE');
    });

    test('no password and no recipient -> NO_UNLOCK_CHANNEL', () async {
      final src = _tmpFile('empty_channels.txt', utf8.encode('x'));
      final enc = await crypto.encryptFileHybrid(
        src.path,
        const crypto.HybridEncryptOptions(),
        null,
      );
      expect(enc.success, isFalse);
      expect(enc.error, 'NO_UNLOCK_CHANNEL');
    });

    test('wrapped .vctkey from disk unlocks a key-only file end-to-end',
        () async {
      final src = _tmpFile('e2e.bin', utf8.encode('end to end'));
      final (pub, priv) = keys.generateKeyPair('E2E');

      // Encrypt to the recipient...
      final enc = await crypto.encryptFileHybrid(
        src.path,
        crypto.HybridEncryptOptions(recipient: pub),
        null,
      );
      expect(enc.success, isTrue);

      // ...store the private key as a password-wrapped container...
      final container = await priv.serializeWrapped('key-pw-99');
      final keyFile = _tmpFile('E2E.vctkey', container);

      // ...and reopen it the way the Decrypt screen does.
      final loaded = await keys.VctPrivateKey.parseWrapped(
          keyFile.readAsBytesSync(), 'key-pw-99');
      final dec =
          await crypto.decryptFileWithKey(enc.outputPath!, loaded, null);
      expect(dec.success, isTrue, reason: dec.error ?? '');
      expect(File(dec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('end to end')));
    });
  });

  // ============================================================
  // 5. H1 - output path sanitization (Zip Slip, v2.4.0)
  // ============================================================
  group('H1 - output path sanitization', () {
    test('rejects path traversal and platform tricks', () {
      for (final raw in [
        '../evil.sh',
        '../../.bashrc',
        '../../.config/autostart/evil.desktop',
        '../etc/./passwd',
        '/etc/cron.d/evil',
        r'..\..\evil.exe', // Windows separators
        r'C:\Windows\Temp\evil.exe',
        '会议纪要.pdf/../../../.bashrc',
        'safe.txt\x00../evil',
        '${'a' * 600}/../evil',
      ]) {
        final safe = crypto.sanitizeFileName(raw);
        expect(safe.contains('/'), isFalse, reason: '$raw -> $safe');
        expect(safe.contains(r'\'), isFalse, reason: '$raw -> $safe');
        expect(safe.contains('..'), isFalse, reason: '$raw -> $safe');
        expect(safe, isNotEmpty);
      }
    });

    test('preserves normal file names', () {
      expect(crypto.sanitizeFileName('report.pdf'), 'report.pdf');
      expect(crypto.sanitizeFileName('季度财报.xlsx'), '季度财报.xlsx');
      expect(crypto.sanitizeFileName('a.b.c.tar.gz'), 'a.b.c.tar.gz');
      expect(crypto.sanitizeFileName('my file (1).txt'), 'my file (1).txt');
    });

    test('handles degenerate input', () {
      for (final raw in [
        '',
        '/',
        '.',
        '..',
        '   ',
        'evil.exe. ',
        'CON',
        'nul.txt',
      ]) {
        final safe = crypto.sanitizeFileName(raw);
        expect(safe, isNotEmpty, reason: raw);
        expect(safe.contains('/'), isFalse, reason: raw);
      }
    });

    test('decrypted output never escapes the input directory', () async {
      final src = _tmpFile('inside.txt', utf8.encode('contained payload'));
      final enc = await crypto.encryptFile(src.path, 'pass1234', null);
      expect(enc.success, isTrue, reason: enc.error ?? '');

      final dec = await crypto.decryptFile(enc.outputPath!, 'pass1234', null);
      expect(dec.success, isTrue, reason: dec.error ?? '');
      expect(dec.originalName, 'inside.txt');
      expect(dec.outputPath, isNotNull);
      expect(File(dec.outputPath!).parent.path, equals(_tmp.path));
    });
  });

  // ============================================================
  // 6. H2 - filler length must not betray whether a decoy is set
  // ============================================================
  group('H2 - filler length indistinguishable', () {
    // v2.5.0: V4 layout - magic 12 + ver 1 + flags 1 + realCtLen 8,
    // then the three slots; total header 334 bytes.
    const headerLen = 334;
    const tagLen = 16;
    const realCtLenOff = 14;

    int decoyAreaLen(Uint8List blob) {
      final realCtLen =
          ByteData.sublistView(blob, realCtLenOff, realCtLenOff + 8)
              .getUint64(0, Endian.little);
      return blob.length - headerLen - realCtLen - tagLen * 2;
    }

    test('filler scales with the real partition', () async {
      for (final size in [50 * 1024, 400 * 1024]) {
        final src =
            _tmpFile('f$size.bin', List.generate(size, (i) => i & 0xFF));
        final enc = await crypto.encryptFile(src.path, 'pw123456', null);
        expect(enc.success, isTrue, reason: enc.error ?? '');

        final blob = File(enc.outputPath!).readAsBytesSync();
        final realCtLen =
            ByteData.sublistView(blob, realCtLenOff, realCtLenOff + 8)
                .getUint64(0, Endian.little);
        final decoyLen = decoyAreaLen(blob);

        // The hole that made "a decoy exists" inferable: a fixed 240..2039
        // byte filler next to a much larger real partition.
        expect(decoyLen, greaterThan(240));
        expect(decoyLen, greaterThan((realCtLen * 0.75).round()),
            reason: 'filler must be comparable to realCtLen=$realCtLen');
        expect(decoyLen, lessThan((realCtLen * 1.25).round()),
            reason: 'filler must be comparable to realCtLen=$realCtLen');
      }
    });
  });

  // ============================================================
  // 7. M4 - decoy and duress end-to-end roundtrips
  // ============================================================
  group('M4 - decoy / duress roundtrip', () {
    test('decoy password reveals the decoy file, not the real one', () async {
      final real = _tmpFile('real.txt', utf8.encode('REAL SECRET'));
      final cover = _tmpFile('cover.txt', utf8.encode('harmless cover data'));

      final enc = await crypto.encryptFile(real.path, 'real-pass', null,
          options: crypto.EncryptOptions(
            decoyPassword: 'decoy-pass',
            decoyFilePath: cover.path,
          ));
      expect(enc.success, isTrue, reason: enc.error ?? '');
      expect(enc.usedDecoy, isTrue);

      final realDec =
          await crypto.decryptFile(enc.outputPath!, 'real-pass', null);
      expect(realDec.success, isTrue, reason: realDec.error ?? '');
      expect(realDec.isDecoy, isFalse);
      expect(File(realDec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('REAL SECRET')));

      final decDec =
          await crypto.decryptFile(enc.outputPath!, 'decoy-pass', null);
      expect(decDec.success, isTrue, reason: decDec.error ?? '');
      expect(decDec.isDecoy, isTrue);
      expect(decDec.originalName, 'cover.txt');
      expect(File(decDec.outputPath!).readAsBytesSync(),
          equals(utf8.encode('harmless cover data')));
    });

    test('duress password shreds the file and looks like a wrong password',
        () async {
      final real = _tmpFile('coercion.txt', utf8.encode('must stay hidden'));
      final enc = await crypto.encryptFile(real.path, 'real-pass', null,
          options: const crypto.EncryptOptions(duressPassword: 'duress-pass'));
      expect(enc.success, isTrue, reason: enc.error ?? '');
      expect(enc.usedDuress, isTrue);

      final dec =
          await crypto.decryptFile(enc.outputPath!, 'duress-pass', null);
      // Indistinguishable from a wrong password, but the file is gone.
      expect(dec.success, isFalse);
      expect(dec.error, 'WRONG_PASSWORD');
      expect(dec.duressTriggered, isTrue);
      expect(File(enc.outputPath!).existsSync(), isFalse);

      // Even the correct password cannot reopen a destroyed file.
      final again =
          await crypto.decryptFile(enc.outputPath!, 'real-pass', null);
      expect(again.success, isFalse);
    });

    test('a plain wrong password does NOT destroy the file', () async {
      final real = _tmpFile('safe.txt', utf8.encode('keep me'));
      final enc = await crypto.encryptFile(real.path, 'real-pass', null,
          options: const crypto.EncryptOptions(duressPassword: 'duress-pass'));
      expect(enc.success, isTrue, reason: enc.error ?? '');

      final dec = await crypto.decryptFile(enc.outputPath!, 'nope-nope', null);
      expect(dec.success, isFalse);
      expect(dec.duressTriggered, isFalse);
      expect(File(enc.outputPath!).existsSync(), isTrue);
    });
  });

  // ============================================================
  // 8. H5 - the V4 header is authenticated as GCM AAD
  // ============================================================
  group('H5 - authenticated V4 header', () {
    test('flipping the stored ciphertext length is detected', () async {
      final src =
          _tmpFile('tamper_len.bin', List.generate(2048, (i) => i & 0xFF));
      final enc = await crypto.encryptFile(src.path, 'pw-tamper', null);
      expect(enc.success, isTrue, reason: enc.error ?? '');

      final blob = File(enc.outputPath!).readAsBytesSync();
      blob[14] ^= 0x01; // REAL_CT_LEN low byte
      final broken = _tmpFile('tamper_len_broken.VCT', blob);

      final dec = await crypto.decryptFile(broken.path, 'pw-tamper', null);
      expect(dec.success, isFalse);
    });

    test('flipping a salt byte is detected', () async {
      final src = _tmpFile('tamper_salt.bin', utf8.encode('salt-bound'));
      final enc = await crypto.encryptFile(src.path, 'pw-tamper', null);
      expect(enc.success, isTrue, reason: enc.error ?? '');

      final blob = File(enc.outputPath!).readAsBytesSync();
      blob[22] ^= 0x01; // first byte of the real salt
      final broken = _tmpFile('tamper_salt_broken.VCT', blob);

      final dec = await crypto.decryptFile(broken.path, 'pw-tamper', null);
      expect(dec.success, isFalse);
      // The HMAC no longer matches, so this must look like a wrong password.
      expect(dec.error, 'WRONG_PASSWORD');
    });

    test('unknown V4 layout version is rejected', () async {
      final src = _tmpFile('tamper_ver.bin', utf8.encode('version bound'));
      final enc = await crypto.encryptFile(src.path, 'pw-tamper', null);
      expect(enc.success, isTrue, reason: enc.error ?? '');

      final blob = File(enc.outputPath!).readAsBytesSync();
      blob[12] = 0x7F; // layout version byte
      final broken = _tmpFile('tamper_ver_broken.VCT', blob);

      final dec = await crypto.decryptFile(broken.path, 'pw-tamper', null);
      expect(dec.success, isFalse);
      expect(dec.error, 'UNSUPPORTED_FORMAT');
    });
  });
}
