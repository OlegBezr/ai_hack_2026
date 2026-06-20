/// Read a recorded clip's bytes from the path `record` returns.
///
/// `record` hands back a filesystem path on native and a blob URL on web, so
/// the two implementations differ. The conditional export keeps `dart:io` out
/// of the web build (where it doesn't exist).
library;

export 'read_bytes_io.dart' if (dart.library.html) 'read_bytes_web.dart';
