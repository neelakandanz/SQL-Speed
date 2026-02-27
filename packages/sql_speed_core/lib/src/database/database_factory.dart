import 'dart:io';

import 'package:sqlite3/sqlite3.dart' hide DatabaseConfig;

import '../engine/isolate_engine.dart';
import '../migration/backup_manager.dart';
import '../migration/migration_engine.dart';
import 'database.dart';
import 'database_config.dart';

/// Factory for creating, opening, and deleting sql_speed databases.
///
/// This is the main entry point for using sql_speed.
///
/// ```dart
/// final db = await SqlSpeed.open(path: 'app.db', version: 1);
/// ```
class SqlSpeed {
  SqlSpeed._();

  /// Opens a database at the given [path].
  ///
  /// If the database does not exist, it is created and [onCreate] is called.
  /// If the stored version differs from [version], [onUpgrade] or
  /// [onDowngrade] is called.
  static Future<SqlSpeedDatabase> open({
    required String path,
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
    final config = DatabaseConfig(
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

    return openWithConfig(config);
  }

  /// Opens a database with a [DatabaseConfig] object.
  static Future<SqlSpeedDatabase> openWithConfig(DatabaseConfig config) async {
    final isMemory = config.path == ':memory:';

    if (!isMemory) {
      // Run migrations on a temporary synchronous connection first
      await _runMigrations(config);
    }

    // Start the background isolate engine
    final engine = await IsolateEngine.start(config);

    if (isMemory) {
      // For in-memory databases, run migrations through the engine
      // since each sqlite3.open(':memory:') creates a separate database.
      await _runInMemoryMigrations(engine, config);
    }

    return SqlSpeedDatabase.create(engine: engine, config: config);
  }

  /// Runs migrations for in-memory databases through the isolate engine.
  static Future<void> _runInMemoryMigrations(
    IsolateEngine engine,
    DatabaseConfig config,
  ) async {
    final executor = _EngineExecutor(engine);
    if (config.onCreate != null) {
      await config.onCreate!(executor, config.version);
    }
    if (config.onOpen != null) {
      await config.onOpen!(executor, config.version);
    }
  }

  /// Deletes a database file at the given [path].
  ///
  /// Also deletes associated WAL and SHM files.
  static Future<void> delete(String path) async {
    final files = [
      File(path),
      File('$path-wal'),
      File('$path-shm'),
      File('$path-journal'),
    ];

    for (final file in files) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Returns true if a database file exists at the given [path].
  static Future<bool> exists(String path) {
    return File(path).exists();
  }

  /// Returns the file size of the database in bytes.
  static Future<int> fileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Runs migrations synchronously before starting the isolate engine.
  static Future<void> _runMigrations(DatabaseConfig config) async {
    // Migrations need direct database access, so we do them before
    // the isolate engine starts. This runs on the calling isolate.
    final migrationEngine = MigrationEngine(
      backupManager: BackupManager(),
    );

    // Open a temporary direct connection for migrations
    final sqlite3lib = _openDirect(config);
    try {
      await migrationEngine.migrate(db: sqlite3lib, config: config);
    } finally {
      sqlite3lib.dispose();
    }
  }

  /// Opens a direct SQLite connection (not pooled, not isolate).
  static Database _openDirect(DatabaseConfig config) {
    return sqlite3.open(config.path);
  }
}

/// A [DatabaseExecutor] that delegates to an [IsolateEngine].
class _EngineExecutor implements DatabaseExecutor {
  _EngineExecutor(this._engine);

  final IsolateEngine _engine;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) =>
      _engine.execute(sql, parameters);

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) =>
      _engine.query(sql, parameters);

  @override
  Future<int> insert(String sql, [List<Object?>? parameters]) =>
      _engine.insert(sql, parameters);
}
