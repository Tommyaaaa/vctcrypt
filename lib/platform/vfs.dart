/// Cross-platform byte/file access used by the web port.
///
/// Native builds keep real file-system semantics; the browser build keeps
/// the same API backed by an in-memory store, because a web page cannot
/// write into the user's file system without a save dialog. Engine outputs
/// land in that store and the UI offers an explicit Download button.
export 'vfs_io.dart' if (dart.library.html) 'vfs_web.dart';
