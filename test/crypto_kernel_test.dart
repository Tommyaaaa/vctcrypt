/// VCTCrypt kernel tests.
///
/// Two jobs:
///   1. Behavioural tests over the public engine API (V2 roundtrip,
///      decoy, duress, shred, secure notes, error codes).
///   2. FORMAT COMPATIBILITY CONTRACT: V1 fixtures are built by an
///      INDEPENDENT implementation (the `cryptography` package used
///      directly, following the documented byte layout). If the engine
///      ever stops decrypting them, a format regression has shipped.
///
/// These tests run the real 600k-iteration PBKDF2, so the suite takes a
/// few minutes. That is the point - the numbers on the box are the
/// numbers that ship.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vctcrypt/crypto/vct_crypto.dart' as crypto;

/// Heavy tests: full pure-Dart PBKDF2 (600k x3; x6 when a decoy partition
/// is written). The stock 30s per-test budget does not survive that on a
/// slow CI runner, so every test that runs real triple-layer crypto gets
/// generous headroom.
const _heavy = Timeout(Duration(minutes: 3));

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vct_kernel_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  File put(String name, List<int> bytes) {
    final f = File(p.join(tmp.path, name));
    f.writeAsBytesSync(bytes, flush: true);
    return f;
  }

  group('V2 engine (current format)', () {
    test('encrypt -> decrypt roundtrip restores bytes and name',
        timeout: _heavy, () async {
      final src = put('hello.txt', utf8.encode('hello kernel'));
      final progress = <String>[];

      final enc = await crypto.encryptFile(
        src.path,
        'correct horse battery',
        progress.add,
      );
      expect(enc.success, isTrue, reason: enc.error);
      expect(enc.usedDecoy, isFalse);
      expect(enc.usedDuress, isFalse);
      expect(enc.shreddedOriginal, isFalse);
      expect(progress, containsAll(<String>['DERIVING', 'ENCRYPTING']));

      // Output landed next to the source and is a valid V2 file.
      expect(enc.outputPath, p.join(tmp.path, 'hello.VCT'));
      final info = crypto.inspectVctFile(enc.outputPath!);
      expect(info.format, crypto.fmtV2);
      expect(info.headerLen, 332);
      expect(info.realCtLen, greaterThan(0));

      final dec = await crypto.decryptFile(
        enc.outputPath!,
        'correct horse battery',
        null,
      );
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.isDecoy, isFalse);
      expect(dec.originalName, 'hello.txt');
      expect(File(dec.outputPath!).readAsBytesSync(), utf8.encode('hello kernel'));
    });

    test('wrong password -> WRONG_PASSWORD (no duress flag)',
        timeout: _heavy, () async {
      final src = put('wrongpw.txt', utf8.encode('data'));
      final enc = await crypto.encryptFile(src.path, 'real password', null);
      expect(enc.success, isTrue, reason: enc.error);

      final dec = await crypto.decryptFile(enc.outputPath!, 'false password', null);
      expect(dec.success, isFalse);
      expect(dec.error, 'WRONG_PASSWORD');
      expect(dec.duressTriggered, isFalse);
    });

    test('instant validation errors (no heavy work)', () async {
      final src = put('short.txt', utf8.encode('data'));
      final short = await crypto.encryptFile(src.path, 'abc', null);
      expect(short.success, isFalse);
      expect(short.error, 'PASSWORD_TOO_SHORT');

      final empty = put('empty.bin', <int>[]);
      final emptyRes = await crypto.encryptFile(empty.path, 'valid password', null);
      expect(emptyRes.success, isFalse);
      expect(emptyRes.error, 'EMPTY_FILE');

      final notVct = put('garbage.VCT', List.filled(500, 7));
      final bad = await crypto.decryptFile(notVct.path, 'whatever', null);
      expect(bad.success, isFalse);
      expect(bad.error, 'NOT_VCT');
    });

    test('decoy password reveals the decoy content (deniable path)',
        timeout: _heavy, () async {
      final real = put('real.txt', utf8.encode('REAL-SECRET'));
      final decoy = put('decoy.txt', utf8.encode('DECOY-CONTENT'));

      final enc = await crypto.encryptFile(
        real.path,
        'realpass',
        null,
        options: crypto.EncryptOptions(
          decoyPassword: 'decoypass',
          decoyFilePath: decoy.path,
        ),
      );
      expect(enc.success, isTrue, reason: enc.error);
      expect(enc.usedDecoy, isTrue);

      // File-shape check: a decoy-enabled file is indistinguishable from
      // a plain one (both always carry all three slots). Use a SEPARATE
      // source so the second encryption does not overwrite the first
      // output (desktop outputs land next to the source, same name).
      final real2 = put('real2.txt', utf8.encode('REAL-SECRET'));
      final plain = await crypto.encryptFile(real2.path, 'realpass', null);
      expect(plain.success, isTrue);
      expect(
        crypto.inspectVctFile(enc.outputPath!).headerLen,
        crypto.inspectVctFile(plain.outputPath!).headerLen,
      );

      final dec = await crypto.decryptFile(enc.outputPath!, 'decoypass', null);
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.isDecoy, isTrue);
      expect(dec.originalName, 'decoy.txt');
      expect(File(dec.outputPath!).readAsBytesSync(),
          utf8.encode('DECOY-CONTENT'));
    });

    test('duress password permanently shreds the file',
        timeout: _heavy, () async {
      final src = put('duress.txt', utf8.encode('destroy-me'));
      final enc = await crypto.encryptFile(
        src.path,
        'realpass',
        null,
        options: crypto.EncryptOptions(duressPassword: 'burnitall'),
      );
      expect(enc.success, isTrue, reason: enc.error);
      expect(enc.usedDuress, isTrue);

      final before = File(enc.outputPath!).readAsBytesSync();
      final dec = await crypto.decryptFile(enc.outputPath!, 'burnitall', null);
      expect(dec.success, isFalse);
      // Same error as a wrong password - observers cannot tell.
      expect(dec.error, 'WRONG_PASSWORD');
      expect(dec.duressTriggered, isTrue);

      final after = File(enc.outputPath!).readAsBytesSync();
      expect(after.length, before.length); // still "exists"
      expect(after, isNot(equals(before))); // but is noise now
      expect(crypto.detectFormat(after), crypto.fmtNone); // magic gone
    });

    test('shredOriginal overwrites the source after a verified write',
        timeout: _heavy, () async {
      final src = put('shredme.txt', utf8.encode('original plaintext'));
      final enc = await crypto.encryptFile(
        src.path,
        'realpass',
        null,
        options: const crypto.EncryptOptions(shredOriginal: true),
      );
      expect(enc.success, isTrue, reason: enc.error);
      expect(enc.shreddedOriginal, isTrue);

      // Source still exists (same size) but no longer contains plaintext.
      final after = src.readAsBytesSync();
      expect(after.length, utf8.encode('original plaintext').length);
      expect(after, isNot(equals(utf8.encode('original plaintext'))));

      // The .VCT output is internally verified before the shred happened.
      final info = crypto.inspectVctFile(enc.outputPath!);
      expect(info.format, crypto.fmtV2);
    });
  });

  group('V1 format compatibility (independent fixtures)', () {
    // Builds a V1 .VCT from scratch with the cryptography package used
    // DIRECTLY - no engine code involved. Mirrors the documented format:
    //   [MAGIC] [SALT 48] [N1 12] [N2 12] [N3 12] [HMAC 32] [L3_CT] [T3]
    //   keys = PBKDF2(password::V|1|2|3, salt), 10k / 600k / 600k / 600k
    Future<Uint8List> buildV1(
      String password,
      String name,
      List<int> content, {
      required int magicLen,
      required int saltFirstByte,
    }) async {
      final rng = Random.secure();
      Uint8List rnd(int n) {
        final out = Uint8List(n);
        for (var i = 0; i < n; i++) {
          out[i] = rng.nextInt(256);
        }
        return out;
      }

      final salt = rnd(48);
      salt[0] = saltFirstByte;
      final n1 = rnd(12);
      final n2 = rnd(12);
      final n3 = rnd(12);

      Future<List<int>> kdf(String suffix, int iters) async {
        final pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: iters,
          bits: 256,
        );
        final k = await pbkdf2.deriveKey(
          secretKey: SecretKey(utf8.encode('$password$suffix')),
          nonce: salt,
        );
        return k.extractBytes();
      }

      final vk = await kdf('::V', 10000);
      final k1 = await kdf('::1', 600000);
      final k2 = await kdf('::2', 600000);
      final k3 = await kdf('::3', 600000);

      final nameBytes = utf8.encode(name);
      final payload = BytesBuilder()
        ..addByte(nameBytes.length & 0xFF)
        ..addByte((nameBytes.length >> 8) & 0xFF)
        ..add(nameBytes)
        ..add(content);

      Future<(List<int>, List<int>)> gcm(
          List<int> key, List<int> nonce, List<int> pt) async {
        final box = await AesGcm.with256bits()
            .encrypt(pt, secretKey: SecretKey(key), nonce: nonce);
        return (box.cipherText, box.mac.bytes);
      }

      final l1 = await gcm(k1, n1, payload.toBytes());
      final l1b = (BytesBuilder()..add(l1.$2)..add(l1.$1)).toBytes();
      final l2 = await gcm(k2, n2, l1b);
      final l2b = (BytesBuilder()..add(l2.$2)..add(l2.$1)).toBytes();
      final l3 = await gcm(k3, n3, l2b);

      final hData = (BytesBuilder()
            ..add(salt)
            ..add(n1)
            ..add(n2)
            ..add(n3))
          .toBytes();
      final hmac = await Hmac.sha256()
          .calculateMac(hData, secretKey: SecretKey(vk));

      final magic = utf8.encode(
          magicLen == 12 ? 'VCTCRYPT1\x00\x00\x00' : 'VCTCRYPT1\x00\x00');
      return (BytesBuilder()
            ..add(magic)
            ..add(salt)
            ..add(n1)
            ..add(n2)
            ..add(n3)
            ..add(hmac.bytes)
            ..add(l3.$1)
            ..add(l3.$2))
          .toBytes();
    }

    test('decrypts a V1 file built by an independent implementation',
        timeout: _heavy, () async {
      final bytes = await buildV1(
        'legacy password',
        'legacy.txt',
        utf8.encode('file from the CLI era'),
        magicLen: 12,
        saltFirstByte: 0x42,
      );
      final f = put('legacy.VCT', bytes);
      expect(crypto.detectFormat(bytes), crypto.fmtV1);

      final dec = await crypto.decryptFile(f.path, 'legacy password', null);
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.originalName, 'legacy.txt');
      expect(File(dec.outputPath!).readAsBytesSync(),
          utf8.encode('file from the CLI era'));
    });

    test('decrypts the 11-byte buggy V1-old file (salt[0]=0 retry path)',
        timeout: _heavy, () async {
      // Historical bug: old Flutter builds wrote an 11-byte magic. When
      // salt[0] == 0x00 the 12-byte check produces a FALSE POSITIVE, and
      // the engine must fall back to the 11-byte layout to succeed.
      final bytes = await buildV1(
        'legacy password',
        'oldbug.txt',
        utf8.encode('from the buggy era'),
        magicLen: 11,
        saltFirstByte: 0x00,
      );
      final f = put('oldbug.VCT', bytes);
      // Detected as V1 (12-byte false positive) but must still decrypt.
      expect(crypto.detectFormat(bytes), crypto.fmtV1);

      final dec = await crypto.decryptFile(f.path, 'legacy password', null);
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.originalName, 'oldbug.txt');
      expect(File(dec.outputPath!).readAsBytesSync(),
          utf8.encode('from the buggy era'));
    });
  });

  group('Secure Notes (fully in-memory)', () {
    test('encryptText -> decryptFileToText roundtrip, no temp leftovers',
        timeout: _heavy, () async {
      final progress = <String>[];
      // Explicit output target, exactly like the desktop Notes screen
      // (save dialog). Plaintext must NEVER hit disk anywhere.
      final noteOut = p.join(tmp.path, 'note.VCT');
      final enc = await crypto.encryptText(
        'my secret note',
        'notepass',
        progress.add,
        outputPath: noteOut,
      );
      expect(enc.success, isTrue, reason: enc.error);
      expect(enc.outputPath, noteOut);
      expect(progress, containsAll(<String>['DERIVING', 'ENCRYPTING']));
      expect(enc.outputPath, endsWith('.VCT'));

      // The note is a plain, ordinary V2 file.
      expect(crypto.inspectVctFile(enc.outputPath!).format, crypto.fmtV2);

      final dec =
          await crypto.decryptFileToText(enc.outputPath!, 'notepass', null);
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.text, 'my secret note');
      expect(dec.originalName, startsWith('VCTCrypt-Note-'));
      expect(dec.originalName, endsWith('.txt'));

      // Plaintext must never have existed on disk: no temp plaintext
      // files from either the encrypt or the decrypt direction.
      final leftovers = Directory.systemTemp.listSync().where((e) {
        final base = p.basename(e.path);
        return (base.startsWith('VCTCrypt-Note-') && base.endsWith('.txt')) ||
            base.contains('vctcrypt_textout');
      });
      expect(leftovers, isEmpty);
    });

    test('empty note -> EMPTY_FILE', () async {
      final res = await crypto.encryptText('', 'notepass', null);
      expect(res.success, isFalse);
      expect(res.error, 'EMPTY_FILE');
    });

    test('binary .VCT -> NOT_TEXT (clean error instead of mojibake)',
        timeout: _heavy, () async {
      final src = put('photo.bin', <int>[0, 1, 2, 255, 254, 0, 9, 8, 7]);
      final enc = await crypto.encryptFile(src.path, 'filepass', null);
      expect(enc.success, isTrue, reason: enc.error);

      final dec = await crypto.decryptFileToText(enc.outputPath!, 'filepass', null);
      expect(dec.success, isFalse);
      expect(dec.error, 'NOT_TEXT');
    });

    test('notes honour unicode content', timeout: _heavy, () async {
      final note = '密钥：天王盖地虎 🕊 border case — naïve';
      final out = p.join(tmp.path, 'unicode-note.VCT');
      final enc =
          await crypto.encryptText(note, 'notepass', null, outputPath: out);
      expect(enc.success, isTrue, reason: enc.error);

      final dec = await crypto.decryptFileToText(enc.outputPath!, 'notepass', null);
      expect(dec.success, isTrue, reason: dec.error);
      expect(dec.text, note);
    });
  });
}
