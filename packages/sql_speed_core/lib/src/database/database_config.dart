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

/// Where SQLite stores temporary tables and indices.
enum TempStore {
  /// Use the compile-time default (usually file).
  defaultMode,

  /// Store temp data in a file.
  file,

  /// Store temp data in memory (faster).
  memory,
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
    this.useSynchronousMode = false,
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
    this.pageSize = 4096,
    this.cacheSize = -8000,
    this.mmapSize = 268435456,
    this.tempStore = TempStore.memory,
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

  /// When true, all database operations run synchronously on the
  /// calling thread via direct FFI calls instead of a background isolate.
  /// Eliminates ~1000µs of isolate round-trip overhead per operation.
  final bool useSynchronousMode;

  /// SQLite page size in bytes. Default 4096 matches Android memory page size.
  final int pageSize;

  /// SQLite page cache size. Negative = KB (e.g. -8000 = 8MB). Default -8000.
  final int cacheSize;

  /// Memory-mapped I/O size in bytes. Default 256MB (268435456). Set 0 to disable.
  final int mmapSize;

  /// Where to store temporary tables. Default: memory.
  final TempStore tempStore;
}
