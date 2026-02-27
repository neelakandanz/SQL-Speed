import 'dart:io';

/// Manages pre-migration database file backups.
///
/// Before any migration, the database file is copied to a backup location.
/// If migration fails, the backup is restored. On success, the backup is deleted.
class BackupManager {
  /// Returns the backup path for a given database path.
  String backupPath(String dbPath) => '$dbPath.backup';

  /// Creates a backup copy of the database file.
  Future<void> createBackup(String dbPath) async {
    final file = File(dbPath);
    if (await file.exists()) {
      await file.copy(backupPath(dbPath));
    }
  }

  /// Restores the database from the backup file.
  Future<void> restoreBackup(String dbPath) async {
    final backup = File(backupPath(dbPath));
    if (await backup.exists()) {
      await backup.copy(dbPath);
      await backup.delete();
    }
  }

  /// Deletes the backup file after a successful migration.
  Future<void> deleteBackup(String dbPath) async {
    final backup = File(backupPath(dbPath));
    if (await backup.exists()) {
      await backup.delete();
    }
  }

  /// Returns true if a backup file exists for the given database.
  Future<bool> hasBackup(String dbPath) async {
    return File(backupPath(dbPath)).exists();
  }
}
