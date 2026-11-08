import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Browser stand-in for the file system: produced files live here until
/// the user downloads them.
///
/// Key files (.vctpub / .vctkey) are the only entries persisted across
/// reloads: the public half is not secret and the private half is
/// wrapped with its own password, so localStorage is a fair stand-in for
/// the Documents folder used by the native builds.
const String _keysDir = 'VCTCrypt-Keys';
const String _lsPrefix = 'vctcrypt.key.';

final Map<String, Uint8List> _store = _hydrateKeys();
final Random _rng = Random.secure();

Map<String, Uint8List> _hydrateKeys() {
  final out = <String, Uint8List>{};
  try {
    final ls = html.window.localStorage;
    for (final key in ls.keys) {
      if (!key.startsWith(_lsPrefix)) continue;
      final b64 = ls[key];
      if (b64 == null) continue;
      out['$_keysDir/${key.substring(_lsPrefix.length)}'] = base64Decode(b64);
    }
  } catch (_) {}
  return out;
}

bool get isWebPlatform => true;
bool get isMobileApp => false;

Uint8List readBytes(String path) {
  final b = _store[path];
  if (b == null) throw StateError('Missing web file: $path');
  return b;
}

/// Browser stand-in for streamed reads: the bytes are already in memory,
/// so hand them out in slices to keep the hashing loop identical.
Stream<List<int>> readChunks(String path) async* {
  final b = readBytes(path);
  const chunkSize = 1 << 20;
  for (var i = 0; i < b.length; i += chunkSize) {
    final end = i + chunkSize < b.length ? i + chunkSize : b.length;
    yield b.sublist(i, end);
  }
}

Uint8List readPrefix(String path, int maxBytes) {
  final b = readBytes(path);
  return b.length <= maxBytes ? b : b.sublist(0, maxBytes);
}

int lengthOf(String path) {
  final b = _store[path];
  if (b == null) throw StateError('Missing web file: $path');
  return b.length;
}

DateTime modifiedOf(String path) => DateTime.now();

bool existsAt(String path) => _store.containsKey(path);

void writeBytes(String path, List<int> data) {
  final bytes = Uint8List.fromList(data);
  _store[path] = bytes;
  if (path.startsWith('$_keysDir/')) {
    try {
      html.window.localStorage['$_lsPrefix${p.basename(path)}'] =
          base64Encode(bytes);
    } catch (_) {}
  }
}

Future<void> shredAt(String path, {bool quick = false}) async {
  deleteAt(path);
}

void deleteAt(String path) {
  _store.remove(path);
  if (path.startsWith('$_keysDir/')) {
    try {
      html.window.localStorage.remove('$_lsPrefix${p.basename(path)}');
    } catch (_) {}
  }
}

// ---- Recipient key files (.vctpub / .vctkey) ----

Future<String> keysDirectory() async => _keysDir;

List<String> listKeyFiles(String dir) {
  final prefix = '$dir/';
  final out = <String>[
    for (final path in _store.keys)
      if (path.startsWith(prefix) &&
          (path.endsWith('.vctpub') || path.endsWith('.vctkey')))
        path,
  ];
  out.sort();
  return out;
}

/// Keep a picked `File` in memory and return the virtual path the engine
/// understands. Without this the engine has nothing to read: browsers
/// expose bytes, never a durable path.
String storePickedFileBytes(String name, Uint8List bytes) {
  final path = _uniquePath(_safeName(name));
  _store[path] = bytes;
  return path;
}

/// Turn a dropped blob URL into a stored virtual file. desktop_drop gives
/// browser drops only a blob: URL plus the original name.
Future<String?> importDroppedFile(String path, String name) async {
  if (_store.containsKey(path)) return path;
  try {
    final req = html.HttpRequest();
    req.open('GET', path);
    req.responseType = 'arraybuffer';
    final done = Completer<html.HttpRequest>();
    req.onLoad.listen((_) => done.complete(req));
    req.onError.listen((_) => done.completeError(StateError('drop failed')));
    req.send();
    final loaded = await done.future;
    final buffer = loaded.response as ByteBuffer;
    return storePickedFileBytes(name, Uint8List.view(buffer));
  } catch (_) {
    return null;
  }
}

String _safeName(String raw) {
  var name = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'file';
  return name;
}

String _uniquePath(String name) {
  if (!_store.containsKey(name)) return name;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  var i = 1;
  var candidate = '$stem ($i)$ext';
  while (_store.containsKey(candidate)) {
    i++;
    candidate = '$stem ($i)$ext';
  }
  return candidate;
}

Future<String> outputPathFor(String safeName, String? inputPath) async {
  return _uniquePath(_safeName(safeName));
}

Future<String> createTempText(String text) async {
  final id = List.generate(
    16,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final path = 'note-$id.txt';
  _store[path] = Uint8List.fromList(utf8.encode(text));
  return path;
}

String tempPath(String prefix) => prefix;

/// Trigger a normal browser download for one stored file.
Future<bool> downloadFile(String path, {String? name}) async {
  final bytes = _store[path];
  if (bytes == null) return false;
  downloadBytes(name ?? p.basename(path), bytes);
  return true;
}

Future<void> saveBytes(String name, List<int> bytes) async {
  downloadBytes(name, bytes);
}

void downloadBytes(String name, List<int> bytes) {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', name)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
