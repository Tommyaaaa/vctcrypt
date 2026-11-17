@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vctcrypt/platform/vfs.dart';

/// v2.7.1 (audit N-03): the browser filesystem is an in-memory map with a
/// localStorage mirror for key files, so it needs its own round-trip test.
/// Run with:
///   flutter test --platform chrome test/vfs_web_test.dart
void main() {
  test('key files survive write/list/read/delete', () async {
    final dir = await keysDirectory();
    final pub = '$dir/browser-roundtrip.vctpub';
    final key = '$dir/browser-roundtrip.vctkey';
    final pubBytes = List<int>.generate(64, (i) => i);
    final keyBytes = List<int>.generate(128, (i) => 255 - i);

    writeBytes(pub, pubBytes);
    writeBytes(key, keyBytes);

    expect(existsAt(pub), isTrue);
    expect(existsAt(key), isTrue);
    final listed = listKeyFiles(dir);
    expect(listed, contains(pub));
    expect(listed, contains(key));
    expect(readBytes(pub), pubBytes);
    expect(readBytes(key), keyBytes);

    deleteAt(pub);
    deleteAt(key);
    expect(existsAt(pub), isFalse);
    expect(existsAt(key), isFalse);
    expect(listKeyFiles(dir), isNot(contains(pub)));
  });

  test('listing ignores non-key files', () async {
    final dir = await keysDirectory();
    final other = '$dir/browser-roundtrip.txt';
    writeBytes(other, [1, 2, 3]);
    expect(listKeyFiles(dir), isNot(contains(other)));
    deleteAt(other);
  });
}
