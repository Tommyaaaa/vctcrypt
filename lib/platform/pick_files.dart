import 'package:file_picker/file_picker.dart';

import 'vfs.dart';

class PickedFileEntry {
  final String path;
  final String name;
  const PickedFileEntry({required this.path, required this.name});
}

/// Pick one or more files and return paths the crypto engine can read.
///
/// Browser pickers never expose a durable path, so the bytes are loaded
/// (withData) and registered in the in-memory store; native pickers keep
/// their real paths.
Future<List<PickedFileEntry>?> pickFilesForApp({
  bool allowMultiple = false,
  List<String>? allowedExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: isWebPlatform,
    type: (allowedExtensions == null || isMobileApp)
        ? FileType.any
        : FileType.custom,
    allowedExtensions:
        (allowedExtensions == null || isMobileApp) ? null : allowedExtensions,
  );
  if (result == null) return null;

  final out = <PickedFileEntry>[];
  for (final file in result.files) {
    if (isWebPlatform) {
      // Touching `file.path` on web throws - the browser only hands out
      // bytes, so register them in the virtual file system.
      final bytes = file.bytes;
      if (bytes == null) continue;
      out.add(PickedFileEntry(
        path: storePickedFileBytes(file.name, bytes),
        name: file.name,
      ));
      continue;
    }
    final path = file.path;
    if (path == null) continue;
    out.add(PickedFileEntry(path: path, name: file.name));
  }
  return out.isEmpty ? null : out;
}
