/// High-performance SQL-first local database engine for Dart.
///
/// `sql_speed_core` provides the pure Dart core of the sql_speed database,
/// including prepared statement caching, background isolate execution,
/// reactive stream queries, and optional encryption.
///
/// ```dart
/// final db = await SqlSpeed.open(path: 'app.db', version: 1);
/// await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
/// final users = await db.query('SELECT * FROM users');
/// await db.close();
/// ```
library sql_speed_core;

// Exceptions
export 'src/exceptions/exceptions.dart';

// Database
export 'src/database/database_config.dart';
export 'src/database/database.dart';
export 'src/database/database_factory.dart';

// Engine
export 'src/engine/statement_cache.dart';
export 'src/engine/connection_pool.dart';
export 'src/engine/isolate_engine.dart';
export 'src/engine/query_executor.dart';

// Streams
export 'src/stream/stream_manager.dart';
export 'src/stream/table_tracker.dart';
export 'src/stream/change_debouncer.dart';

// Migration
export 'src/migration/migration_engine.dart';
export 'src/migration/schema_verifier.dart';
export 'src/migration/backup_manager.dart';

// Types
export 'src/types/type_mapper.dart';
export 'src/types/type_registry.dart';
export 'src/types/built_in_types.dart';

// Batch
export 'src/batch/batch_executor.dart';

// Query Builder
export 'src/query_builder/select_builder.dart';
export 'src/query_builder/insert_builder.dart';
export 'src/query_builder/update_builder.dart';
export 'src/query_builder/delete_builder.dart';
export 'src/query_builder/join_builder.dart';

// Encryption
export 'src/encryption/encryption_config.dart';
export 'src/encryption/sqlcipher_loader.dart';

// Utils
export 'src/utils/logger.dart';
export 'src/utils/sql_parser.dart';
