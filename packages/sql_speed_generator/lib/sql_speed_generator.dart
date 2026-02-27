/// Code generation for sql_speed.
///
/// Provides annotations for defining database models and a build_runner
/// generator that produces CRUD operations, type mappings, and
/// reactive stream watchers.
///
/// ## Usage
///
/// 1. Annotate your model classes:
/// ```dart
/// @Table(name: 'users')
/// class UserModel {
///   @PrimaryKey(autoIncrement: true)
///   final int? id;
///
///   @NotNull()
///   final String name;
///
///   final int age;
/// }
/// ```
///
/// 2. Run code generation:
/// ```bash
/// dart run build_runner build
/// ```
library sql_speed_generator;

// Annotations
export 'src/annotations/table.dart';
export 'src/annotations/column.dart';
export 'src/annotations/relationship.dart';
export 'src/annotations/index.dart';
