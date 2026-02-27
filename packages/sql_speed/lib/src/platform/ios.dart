/// iOS-specific database setup.
///
/// iOS ships SQLite as part of the system frameworks.
/// No additional setup is needed for basic usage.
class IosDatabaseSetup {
  /// iOS always has SQLite available.
  static bool get isAvailable => true;

  /// Returns the SQLite framework reference for iOS.
  static String get libraryPath => 'sqlite3';
}
