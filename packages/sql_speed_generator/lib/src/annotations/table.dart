/// Marks a class as a database table model.
///
/// The table name defaults to the class name in snake_case.
/// You can override it with the [name] parameter.
///
/// ```dart
/// @Table(name: 'users')
/// class UserModel {
///   @PrimaryKey(autoIncrement: true)
///   final int? id;
///   final String name;
///   final int age;
/// }
/// ```
class Table {
  /// Creates a new [Table] annotation.
  const Table({this.name});

  /// The table name in the database.
  /// Defaults to the class name converted to snake_case.
  final String? name;
}
