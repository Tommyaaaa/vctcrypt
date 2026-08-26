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
import 'dart:typed_data';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Path provider is never used by these code paths; stub the channel
  // anyway so any accidental use fails loudly instead of hanging.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => throw StateError('path_provider must not be used here'));

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

    test('implicit rejection: tampered ciphertext yields a different key',
        () {
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
      expect(parsed.fingerprint, hasLength(8));
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
        throwsA(isA<keys.KeyFileException>().having(
            (e) => e.code, 'code', keys.errWrongKeyPassword)),
      );
    });

    test('corrupted / non-key file -> BAD_KEY_FILE', () {
      expect(
        () => keys.VctPublicKey.parse(Uint8List.fromList(List.filled(1200, 7))),
        throwsA(isA<keys.KeyFileException>().having(
            (e) => e.code, 'code', keys.errBadKeyFile)),
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
  // 3. V1 password format
  // ============================================================
  group('V1 password format', () {
    test('encrypt/decrypt roundtrip', () async {
      final src = _tmpFile(
          'hello.txt', utf8.encode('hello VCTCrypt v1 roundtrip'));
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
          crypto.fmtV2);
    });

    test('wrong password -> WRONG_PASSWORD', () async {
      final src = _tmpFile('secret.bin', List.generate(1024, (i) => i & 0xFF));
      final enc = await crypto.encryptFile(src.path, 'right-pass', null);
      final dec = await crypto.decryptFile(enc.outputPath!, 'wrong-pass', null);
      expect(dec.success, isFalse);
      expect(dec.error, 'WRONG_PASSWORD');
    });
  });

  // ============================================================
  // 4. V3 hybrid envelope (ML-KEM-768)
  // ============================================================
  group('V3 hybrid envelope', () {
    test('dual channel: password AND private key both open the file',
        () async {
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
      final decPw =
          await crypto.decryptFile(enc.outputPath!, 'anything', null);
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

      final dec = await crypto.decryptFileWithKey(
          enc.outputPath!, wrongPriv, null);
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
}
