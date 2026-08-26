// One-off harness: bidirectional ML-KEM-768 interop between the vendored
// pqcrypto implementation and Go's crypto/mlkem, plus generation of a
// deterministic KAT set for the checked-in flutter_test.
//
// Run: dart run tool/mlkem_interop.dart <godir> <interopdir>
//  - <godir>  : dir with the compiled Go binary
//  - <interopdir> : scratch dir for key/ct/ss files
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/crypto/vendor/mlkem/mlkem.dart';

const rounds = 3;

void main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: dart run tool/mlkem_interop.dart <godir> <workdir>');
    exit(2);
  }
  final goBin = '${args[0]}/mlkemgo';
  final work = args[1];
  Directory(work).createSync(recursive: true);
  final kem = PqcKem.kyber768;

  final kat = <Map<String, String>>[];

  // ---- Round A: Go keygen -> Dart encapsulate -> Go decapsulate ----
  final kg = Process.runSync(goBin, ['keygen', work, '$rounds']);
  expect(kg.exitCode == 0, 'go keygen failed: ${kg.stderr}');

  for (var i = 0; i < rounds; i++) {
    final ek = File('$work/ek.$i').readAsBytesSync();
    final seed = File('$work/seed.$i').readAsBytesSync();

    // Strongest cross-check first: the same 64-byte seed must derive
    // the SAME public key in both implementations. Go serializes keys
    // as seeds, so ek agreement IS full keygen agreement; the Dart
    // dk_Pragmatic (2400 B) is derived here for the KAT below.
    final (ekDart, dkDart) = kem.generateKeyPair(seed);
    expect(listEq(ekDart, ek), 'round K$i: derived public keys differ');
    final dk = dkDart;

    // Deterministic m for the KAT (32 bytes).
    final m = Uint8List.fromList(List.generate(32, (j) => (i * 7 + j) & 0xFF));
    final (ct, ssDart) = kem.encapsulate(ek, m);

    // Independent check: Go decapsulates Dart's ciphertext (seed path).
    File('$work/ct.a$i').writeAsBytesSync(ct);
    final dec = Process.runSync(goBin, ['decap', '$work/seed.$i', '$work/ct.a$i', '$work/ss.a$i']);
    expect(dec.exitCode == 0, 'go decap failed: ${dec.stderr}');
    final ssGo = File('$work/ss.a$i').readAsBytesSync();
    expect(listEq(ssDart, ssGo), 'round A$i: shared secrets differ');

    // And Go's own encapsulation must agree with Dart's decapsulation.
    final enc = Process.runSync(goBin, ['encap', '$work/ek.$i', '$work/ct.b$i', '$work/ss.b$i']);
    expect(enc.exitCode == 0, 'go encap failed: ${enc.stderr}');
    final ctGo = File('$work/ct.b$i').readAsBytesSync();
    final ssGo2 = File('$work/ss.b$i').readAsBytesSync();
    final ssDart2 = kem.decapsulate(dk, ctGo);
    expect(listEq(ssGo2, ssDart2), 'round B$i: decapsulated secrets differ');

    // Implicit rejection: tampered ct must NOT yield the same secret.
    final bad = Uint8List.fromList(ctGo);
    bad[0] ^= 0x01;
    final ssBad = kem.decapsulate(dk, bad);
    expect(!listEq(ssBad, ssGo2), 'round C$i: tampered ct not rejected');

    kat.add({
      'ek': hex(ek),
      'dk': hex(dk),
      'm': hex(m),
      'ct': hex(ct),
      'ss': hex(ssDart),
    });
    stdout.writeln('round $i: OK (encap+decap agree with Go, rejection works)');
  }

  // Emit the KAT set for the checked-in test.
  final out = File('${work}/kat.json')..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(kat));
  stdout.writeln('KAT written: ${out.path} (${kat.length} vectors)');
  stdout.writeln('ALL_INTEROP_OK');
}

void expect(bool cond, String why) {
  if (!cond) {
    stderr.writeln('FATAL: $why');
    exit(1);
  }
}

bool listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
