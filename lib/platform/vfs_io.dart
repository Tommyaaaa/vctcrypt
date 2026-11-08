import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get isWebPlatform => false;
bool get isMobileApp => Platform.isIOS || Platform.isAndroid;

/// Files dropped on the window come with real paths on native builds.
Future<String?> importDroppedFile(String path, String name) async =>
    File(path).existsSync() ? path : null;

Uint8List readBytes(String path) => File(path).readAsBytesSync();

/// Chunked read used by the checksum screen so large files are never
/// loaded into memory on native builds.
Stream<List<int>> readChunks(String path) => File(path).openRead();

Uint8List readPrefix(String path, int maxBytes) {
  final f = File(path);
  final size = f.lengthSync();
  final raf = f.openSync(mode: FileMode.read);
  try {
    return raf.readSync(size < maxBytes ? size : maxBytes);
  } finally {
    raf.closeSync();
  }
}

int lengthOf(String path) => File(path).lengthSync();

DateTime modifiedOf(String path) => File(path).lastModifiedSync();

bool existsAt(String path) => File(path).existsSync();

void writeBytes(String path, List<int> data) {
  final f = File(path);
  final tmp = File('$path.vctpart');
  try {
    tmp.writeAsBytesSync(data, flush: true);
    tmp.renameSync(path);
  } on FileSystemException {
    if (tmp.existsSync()) tmp.deleteSync();
    f.writeAsBytesSync(data);
  }
}

Future<void> shredAt(String path, {bool quick = false}) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final size = f.lengthSync();
  final rng = Random.secure();
  final raf = f.openSync(mode: FileMode.write);
  try {
    final cap = quick ? 4 * 1024 : size;
    const chunkSize = 64 * 1024;
    var remaining = cap;
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
  try {
    f.deleteSync();
  } catch (_) {}
}

/// Resolve where a produced file should be written.
/// Desktop: next to the input. Mobile app: Documents / external files
/// (the pickers hand us sandbox copies, so "next to the input" would be
/// invisible to file managers).
Future<String> outputPathFor(String safeName, String? inputPath) async {
  if (!Platform.isIOS && !Platform.isAndroid) {
    final baseDir = p.dirname(inputPath ?? '.');
    var out = p.join(baseDir, safeName);
    if (inputPath != null && p.equals(out, inputPath)) {
      final dot = safeName.lastIndexOf('.');
      final stem = dot > 0 ? safeName.substring(0, dot) : safeName;
      final ext = dot > 0 ? safeName.substring(dot) : '';
      out = p.join(baseDir, '${stem}_enc$ext');
    }
    out = _uniquePath(out);
    if (!p.isWithin(baseDir, out)) {
      out = p.join(baseDir, 'decrypted_file');
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
    final dir = p.dirname(inputPath ?? '.');
    final out = p.join(dir, safeName);
    return p.isWithin(dir, out) ? out : p.join(dir, 'decrypted_file');
  }

  var out = p.join(baseDir, safeName);
  if (inputPath != null && p.equals(out, inputPath)) {
    final dot = safeName.lastIndexOf('.');
    final stem = dot > 0 ? safeName.substring(0, dot) : safeName;
    final ext = dot > 0 ? safeName.substring(dot) : '';
    out = p.join(baseDir, '${stem}_enc$ext');
  }
  out = _uniquePath(out);
  if (!p.isWithin(baseDir, out)) {
    out = p.join(baseDir, 'decrypted_file');
  }
  return out;
}

String _uniquePath(String path) {
  if (!File(path).existsSync()) return path;
  final dir = p.dirname(path);
  final base = p.basename(path);
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  final ext = dot > 0 ? base.substring(dot) : '';
  var i = 1;
  var candidate = path;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$stem ($i)$ext');
    i++;
  }
  return candidate;
}

/// Plaintext hand-off file for Secure Notes - private temp directory,
/// random name, 0700/0600 permissions where the OS supports it.
Future<String> createTempText(String text) async {
  final dir = Directory(p.join(Directory.systemTemp.path, 'vctcrypt_notes'));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  if (!Platform.isWindows) {
    try {
      Process.runSync('chmod', ['700', dir.path]);
    } catch (_) {}
  }
  final id = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final tmp = File(p.join(dir.path, 'note-$id.txt'));
  tmp.createSync(exclusive: true);
  if (!Platform.isWindows) {
    try {
      Process.runSync('chmod', ['600', tmp.path]);
    } catch (_) {}
  }
  tmp.writeAsStringSync(text, flush: true);
  return tmp.path;
}

/// Transient path used by the note reader (shredded immediately).
///
/// v2.6.1 (N-02): this used to hand out a predictable name directly in
/// the shared temp directory, while carrying DECRYPTED note text. It now
/// lives in the same private 0700 directory the note writer uses, under
/// a random 128-bit name.
String tempPath(String prefix) {
  final dir = Directory(p.join(Directory.systemTemp.path, 'vctcrypt_notes'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  if (!Platform.isWindows) {
    try {
      Process.runSync('chmod', ['700', dir.path]);
    } catch (_) {}
  }
  final id = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return p.join(dir.path, '${prefix}_$id.tmp');
}

// ---- Recipient key files (.vctpub / .vctkey) ----

/// Key files live in the user's Documents folder on native builds.
Future<String> keysDirectory() async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}

/// Existing .vctpub / .vctkey files in [dir], sorted for stable display.
List<String> listKeyFiles(String dir) {
  try {
    return [
      for (final f in Directory(dir).listSync(followLinks: false))
        if (f is File) f.path,
    ]..sort();
  } catch (_) {
    return <String>[];
  }
}

void deleteAt(String path) {
  try {
    File(path).deleteSync();
  } catch (_) {}
}

String storePickedFileBytes(String name, Uint8List bytes) {
  final dir = Directory(p.join(Directory.systemTemp.path, 'vctcrypt_picked'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final id = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final path = p.join(dir.path, '${id}_${p.basename(name)}');
  File(path).writeAsBytesSync(bytes, flush: true);
  return path;
}

/// Native builds use the share sheet instead of a browser download.
Future<bool> downloadFile(String path, {String? name}) async => false;

/// Native builds already wrote the file to disk.
Future<void> saveBytes(String name, List<int> bytes) async {}
