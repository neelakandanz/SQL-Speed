import 'dart:io';

/// Desktop-specific database setup.
///
/// Desktop platforms may need a bundled SQLite library.
/// `sqlite3_flutter_libs` handles this automatically.
class DesktopDatabaseSetup {
  /// Returns the SQLite library name for the current desktop platform.
  static String get libraryName {
    if (Platform.isMacOS) return 'libsqlite3.dylib';
    if (Platform.isWindows) return 'sqlite3.dll';
    if (Platform.isLinux) return 'libsqlite3.so';
    throw UnsupportedError('Not a desktop platform');
  }
}
