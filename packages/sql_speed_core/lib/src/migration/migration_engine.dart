import 'package:sqlite3/sqlite3.dart' hide DatabaseConfig;

import '../database/database_config.dart';
import '../exceptions/exceptions.dart';
import 'backup_manager.dart';

/// A database executor adapter for migration callbacks.
class _MigrationExecutor implements DatabaseExecutor {
  _MigrationExecutor(this._db);

  final Database _db;

  @override
  Future<void> execute(String sql, [List<Object?>? parameters]) async {
    if (parameters != null && parameters.isNotEmpty) {
      final stmt = _db.prepare(sql);
      stmt.execute(parameters);
      stmt.dispose();
    } else {
      _db.execute(sql);
    }
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?>? parameters,
  ]) async {
    final stmt = _db.prepare(sql);
    final result = parameters != null && parameters.isNotEmpty
        ? stmt.select(parameters)
        : stmt.select();
    final rows = result.rows.map((row) {
      final map = <String, Object?>{};
      for (var i = 0; i < result.columnNames.length; i++) {
        map[result.columnNames[i]] = row[i];
      }
      return map;
    }).toList();
    stmt.dispose();
    return rows;
  }

  @override
  Future<int> insert(String sql, [List<Object?>? parameters]) async {
    final stmt = _db.prepare(sql);
    if (parameters != null && parameters.isNotEmpty) {
      stmt.execute(parameters);
    } else {
      stmt.execute([]);
    }
    stmt.dispose();
    return _db.lastInsertRowId;
  }
}

/// Handles version-based database schema migrations.
///
/// Migrations run inside a transaction — if any step fails, the entire
/// migration rolls back. A backup is created before migration starts.
class MigrationEngine {
  /// Creates a new [MigrationEngine].
  MigrationEngine({required this.backupManager});

  /// Manages pre-migration backups.
  final BackupManager backupManager;

  /// Runs migrations based on the stored version vs the target version.
  ///
  /// Called during database open. Handles onCreate, onUpgrade, and
  /// onDowngrade callbacks.
  Future<void> migrate({
    required Database db,
    required DatabaseConfig config,
  }) async {
    final currentVersion = _getVersion(db);
    final targetVersion = config.version;

    if (currentVersion == 0 && config.onCreate != null) {
      // Fresh database — run onCreate
      await _runInTransaction(db, () async {
        final executor = _MigrationExecutor(db);
        await config.onCreate!(executor, targetVersion);
        _setVersion(db, targetVersion);
      });
      return;
    }

    if (currentVersion == targetVersion) {
      // No migration needed
      if (config.onOpen != null) {
        final executor = _MigrationExecutor(db);
        await config.onOpen!(executor, targetVersion);
      }
      return;
    }

    // Create backup before migration
    await backupManager.createBackup(config.path);

    try {
      if (currentVersion < targetVersion && config.onUpgrade != null) {
        // Upgrade
        await _runInTransaction(db, () async {
          final executor = _MigrationExecutor(db);
          await config.onUpgrade!(executor, currentVersion, targetVersion);
          _setVersion(db, targetVersion);
        });
      } else if (currentVersion > targetVersion && config.onDowngrade != null) {
        // Downgrade
        await _runInTransaction(db, () async {
          final executor = _MigrationExecutor(db);
          await config.onDowngrade!(executor, currentVersion, targetVersion);
          _setVersion(db, targetVersion);
        });
      } else {
        // No callback provided — just set version
        _setVersion(db, targetVersion);
      }

      // Migration successful — delete backup
      await backupManager.deleteBackup(config.path);
    } catch (e) {
      // Migration failed — restore from backup
      await backupManager.restoreBackup(config.path);
      throw MigrationException(
        'Migration from v$currentVersion to v$targetVersion failed: $e',
        originalError: e,
      );
    }

    if (config.onOpen != null) {
      final executor = _MigrationExecutor(db);
      await config.onOpen!(executor, targetVersion);
    }
  }

  /// Gets the current database version via PRAGMA user_version.
  int _getVersion(Database db) {
    final result = db.select('PRAGMA user_version');
    if (result.isEmpty) return 0;
    return result.first['user_version'] as int? ?? 0;
  }

  /// Sets the database version via PRAGMA user_version.
  void _setVersion(Database db, int version) {
    db.execute('PRAGMA user_version = $version');
  }

  /// Runs the given callback inside a SAVEPOINT transaction.
  Future<void> _runInTransaction(
    Database db,
    Future<void> Function() callback,
  ) async {
    db.execute('SAVEPOINT migration');
    try {
      await callback();
      db.execute('RELEASE SAVEPOINT migration');
    } catch (e) {
      db.execute('ROLLBACK TO SAVEPOINT migration');
      rethrow;
    }
  }
}
