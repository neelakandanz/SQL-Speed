/// Marks a one-to-many relationship.
///
/// The annotated field should be a `List<T>` where T is the related model.
///
/// ```dart
/// @HasMany(PostModel)
/// List<PostModel>? posts;
/// ```
class HasMany {
  /// Creates a new [HasMany] annotation.
  const HasMany(this.relatedType, {this.foreignKey});

  /// The related model type.
  final Type relatedType;

  /// The foreign key column in the related table.
  /// Defaults to `<current_table>_id`.
  final String? foreignKey;
}

/// Marks a many-to-one relationship.
///
/// ```dart
/// @BelongsTo(UserModel)
/// final int userId;
/// ```
class BelongsTo {
  /// Creates a new [BelongsTo] annotation.
  const BelongsTo(this.relatedType, {this.foreignKey});

  /// The related model type.
  final Type relatedType;

  /// The foreign key column in this table.
  /// Defaults to `<related_table>_id`.
  final String? foreignKey;
}

/// Marks a many-to-many relationship.
///
/// A junction table is automatically created/expected.
///
/// ```dart
/// @ManyToMany(TagModel)
/// List<TagModel>? tags;
/// ```
class ManyToMany {
  /// Creates a new [ManyToMany] annotation.
  const ManyToMany(this.relatedType, {this.junctionTable});

  /// The related model type.
  final Type relatedType;

  /// The junction table name.
  /// Defaults to `<table1>_<table2>` (alphabetically sorted).
  final String? junctionTable;
}
