/// High-performance SQL-first local database for Flutter.
///
/// `sql_speed` provides a Flutter-friendly wrapper around `sql_speed_core`,
/// adding platform path resolution, a reactive `SqlSpeedBuilder` widget,
/// and platform-specific database setup.
///
/// ```dart
/// final db = await FlutterSqlSpeed.openDefault('app.db', version: 1);
/// ```
library sql_speed;

// Re-export everything from core
export 'package:sql_speed_core/sql_speed_core.dart';

// Flutter-specific
export 'src/flutter_database.dart';
export 'src/sql_speed_builder.dart';
export 'src/platform/platform_resolver.dart';
