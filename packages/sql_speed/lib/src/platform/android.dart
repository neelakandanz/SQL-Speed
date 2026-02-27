/// Android-specific database setup.
///
/// Android ships with SQLite, but the version varies by OS version.
/// For consistent behavior, we recommend using `sqlite3_flutter_libs`
/// which bundles a known SQLite version.
class AndroidDatabaseSetup {
  /// Returns the recommended SQLite library path for Android.
  static String get libraryPath => 'libsqlite3.so';

  /// Minimum recommended Android API level for WAL mode.
  static const int minApiForWal = 16;
}
