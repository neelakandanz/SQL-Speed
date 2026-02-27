/// SQLite journal mode options.
enum JournalMode {
  /// Write-Ahead Logging — best for concurrent reads/writes. Default.
  wal,

  /// Traditional rollback journal.
  delete,

  /// Truncate journal file to zero length.
  truncate,

  /// Persist journal file (don't delete).
  persist,

  /// Store journal in memory (faster, less safe).
  memory,

  /// Disable journal entirely (dangerous).
  off,
}

/// Callback for database creation (first time) or migration.
typedef DatabaseCallback = Future<void> Function(
  DatabaseExecutor db,
  int version,
);

/// Callback for database upgrade/downgrade.
typedef MigrationCallback = Future<void> Function(
  DatabaseExecutor db,
  int oldVersion,
  int newVersion,
);

/// Minimal interface for executing SQL within callbacks.
abstract class DatabaseExecutor {
  /// Execute a SQL statement with no return value.
  Future<void> execute(String sql, [List<Object?>? parameters]);

  /// Execute a SQL query and return results.
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]);

  /// Insert a row and return the last insert row ID.
  Future<int> insert(String sql, [List<Object?>? parameters]);
}

/// Configuration for opening a sql_speed database.
class DatabaseConfig {
  /// Creates a new [DatabaseConfig].
  const DatabaseConfig({
    required this.path,
    this.version = 1,
    this.onCreate,
    this.onUpgrade,
    this.onDowngrade,
    this.onOpen,
    this.encrypted = false,
    this.encryptionKey,
    this.journalMode = JournalMode.wal,
    this.maxReadConnections = 3,
    this.statementCacheSize = 100,
    this.enableLogging = false,
  }) : assert(
          !encrypted || encryptionKey != null,
          'encryptionKey is required when encrypted is true',
        );

  /// Path to the database file.
  final String path;

  /// Database schema version. Used for migration management.
  final int version;

  /// Called when the database is created for the first time.
  final DatabaseCallback? onCreate;

  /// Called when [version] is greater than the stored version.
  final MigrationCallback? onUpgrade;

  /// Called when [version] is less than the stored version.
  final MigrationCallback? onDowngrade;

  /// Called after the database is opened (after migrations).
  final DatabaseCallback? onOpen;

  /// Whether to enable AES-256 encryption via SQLCipher.
  final bool encrypted;

  /// The encryption key. Required when [encrypted] is true.
  final String? encryptionKey;

  /// SQLite journal mode. Defaults to WAL for best performance.
  final JournalMode journalMode;

  /// Number of read connections in the pool. Defaults to 3.
  final int maxReadConnections;

  /// Maximum number of prepared statements to cache. Defaults to 100.
  final int statementCacheSize;

  /// Whether to log all queries and timings. Defaults to false.
  final bool enableLogging;
}
