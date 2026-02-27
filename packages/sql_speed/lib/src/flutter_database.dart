import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sql_speed_core/sql_speed_core.dart';

/// Flutter-specific database helper that resolves paths automatically.
///
/// Uses `path_provider` to get the app's documents directory and
/// opens the database there.
///
/// ```dart
/// final db = await FlutterSqlSpeed.openDefault('app.db', version: 1);
/// ```
class FlutterSqlSpeed {
  FlutterSqlSpeed._();

  /// Opens a database in the app's default documents directory.
  ///
  /// The [name] is the database filename (e.g., 'app.db').
  /// The database file will be stored at `<documents_dir>/<name>`.
  static Future<SqlSpeedDatabase> openDefault(
    String name, {
    int version = 1,
    DatabaseCallback? onCreate,
    MigrationCallback? onUpgrade,
    MigrationCallback? onDowngrade,
    DatabaseCallback? onOpen,
    bool encrypted = false,
    String? encryptionKey,
    JournalMode journalMode = JournalMode.wal,
    int maxReadConnections = 3,
    int statementCacheSize = 100,
    bool enableLogging = false,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, name);

    return SqlSpeed.open(
      path: path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      onDowngrade: onDowngrade,
      onOpen: onOpen,
      encrypted: encrypted,
      encryptionKey: encryptionKey,
      journalMode: journalMode,
      maxReadConnections: maxReadConnections,
      statementCacheSize: statementCacheSize,
      enableLogging: enableLogging,
    );
  }

  /// Deletes a database from the app's default documents directory.
  static Future<void> deleteDefault(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, name);
    await SqlSpeed.delete(path);
  }

  /// Checks if a database exists in the app's default documents directory.
  static Future<bool> existsDefault(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, name);
    return SqlSpeed.exists(path);
  }

  /// Returns the full path for a database name in the documents directory.
  static Future<String> getPath(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, name);
  }
}
