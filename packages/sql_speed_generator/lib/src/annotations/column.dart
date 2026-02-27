/// Marks a field as a database column with custom configuration.
///
/// ```dart
/// @Column(name: 'full_name')
/// final String name;
/// ```
class Column {
  /// Creates a new [Column] annotation.
  const Column({this.name, this.type});

  /// Custom column name in the database.
  /// Defaults to the field name converted to snake_case.
  final String? name;

  /// Override the auto-detected SQLite type.
  final SqlType? type;
}

/// Marks a field as the primary key.
///
/// ```dart
/// @PrimaryKey(autoIncrement: true)
/// final int? id;
/// ```
class PrimaryKey {
  /// Creates a new [PrimaryKey] annotation.
  const PrimaryKey({this.autoIncrement = true});

  /// Whether the primary key auto-increments. Defaults to true.
  final bool autoIncrement;
}

/// Marks a field as NOT NULL in the database.
class NotNull {
  /// Creates a new [NotNull] annotation.
  const NotNull();
}

/// Sets a default value for the column.
///
/// ```dart
/// @DefaultValue(0)
/// final int score;
/// ```
class DefaultValue {
  /// Creates a new [DefaultValue] annotation.
  const DefaultValue(this.value);

  /// The default value. Must be a valid SQL literal.
  final Object value;
}

/// Marks a field to be ignored (not stored in the database).
///
/// ```dart
/// @Ignore()
/// String? tempField;
/// ```
class Ignore {
  /// Creates a new [Ignore] annotation.
  const Ignore();
}

/// Overrides the auto-detected SQLite column type.
///
/// ```dart
/// @ColumnType(SqlType.text)
/// final String data;
/// ```
class ColumnType {
  /// Creates a new [ColumnType] annotation.
  const ColumnType(this.type);

  /// The SQLite type for this column.
  final SqlType type;
}

/// Marks a field as a JSON-serialized column.
///
/// The field value is stored as TEXT and automatically
/// serialized/deserialized using JSON.
///
/// ```dart
/// @JsonColumn()
/// final Map<String, dynamic> metadata;
/// ```
class JsonColumn {
  /// Creates a new [JsonColumn] annotation.
  const JsonColumn();
}

/// SQLite column types.
enum SqlType {
  /// INTEGER type.
  integer,

  /// REAL (floating point) type.
  real,

  /// TEXT type.
  text,

  /// BLOB (binary) type.
  blob,
}
