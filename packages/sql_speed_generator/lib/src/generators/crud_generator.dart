import 'package:analyzer/dart/element/element.dart';

/// Generates CRUD (Create, Read, Update, Delete) extension methods
/// for annotated model classes.
class CrudGenerator {
  /// Generates the full CRUD extension code for a model class.
  static String generate(ClassElement classElement) {
    final className = classElement.name;
    final tableName = _toSnakeCase(className);
    final fields = classElement.fields
        .where((f) => !f.isStatic && !_hasAnnotation(f, 'Ignore'))
        .toList();

    final pkField = fields.firstWhere(
      (f) => _hasAnnotation(f, 'PrimaryKey'),
      orElse: () => fields.first,
    );

    final buffer = StringBuffer();

    // Extension header
    buffer.writeln('extension ${className}Queries on SqlSpeedDatabase {');

    // Insert
    _generateInsert(buffer, className, tableName, fields, pkField);
    buffer.writeln();

    // Update
    _generateUpdate(buffer, className, tableName, fields, pkField);
    buffer.writeln();

    // Delete
    _generateDelete(buffer, className, tableName, pkField);
    buffer.writeln();

    // Find by ID
    _generateFindById(buffer, className, tableName, pkField);
    buffer.writeln();

    // Find all
    _generateFindAll(buffer, className, tableName);
    buffer.writeln();

    // Find where
    _generateFindWhere(buffer, className, tableName);
    buffer.writeln();

    // Watch all
    _generateWatchAll(buffer, className, tableName);
    buffer.writeln();

    // Watch where
    _generateWatchWhere(buffer, className, tableName);

    buffer.writeln('}');

    return buffer.toString();
  }

  static void _generateInsert(
    StringBuffer buffer,
    String className,
    String tableName,
    List<FieldElement> fields,
    FieldElement pkField,
  ) {
    final insertFields =
        fields.where((f) => f != pkField || !_hasAnnotation(f, 'PrimaryKey'));
    final columns = insertFields.map((f) => _getColumnName(f)).join(', ');
    final placeholders = List.filled(insertFields.length, '?').join(', ');

    buffer.writeln('  Future<int> insert$className($className model) {');
    buffer.writeln('    return insert(');
    buffer.writeln("      'INSERT INTO $tableName ($columns) VALUES ($placeholders)',");
    buffer.write('      [');
    buffer.write(insertFields.map((f) => 'model.${f.name}').join(', '));
    buffer.writeln('],');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  static void _generateUpdate(
    StringBuffer buffer,
    String className,
    String tableName,
    List<FieldElement> fields,
    FieldElement pkField,
  ) {
    final updateFields =
        fields.where((f) => f != pkField).toList();
    final setClauses =
        updateFields.map((f) => '${_getColumnName(f)} = ?').join(', ');
    final pkColumn = _getColumnName(pkField);

    buffer.writeln('  Future<int> update$className($className model) {');
    buffer.writeln('    return update(');
    buffer.writeln("      'UPDATE $tableName SET $setClauses WHERE $pkColumn = ?',");
    buffer.write('      [');
    buffer.write(updateFields.map((f) => 'model.${f.name}').join(', '));
    buffer.write(', model.${pkField.name}');
    buffer.writeln('],');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  static void _generateDelete(
    StringBuffer buffer,
    String className,
    String tableName,
    FieldElement pkField,
  ) {
    final pkType = pkField.type.getDisplayString().replaceAll('?', '');
    final pkColumn = _getColumnName(pkField);

    buffer.writeln('  Future<int> delete$className($pkType id) {');
    buffer.writeln(
        "    return delete('DELETE FROM $tableName WHERE $pkColumn = ?', [id]);");
    buffer.writeln('  }');
  }

  static void _generateFindById(
    StringBuffer buffer,
    String className,
    String tableName,
    FieldElement pkField,
  ) {
    final pkType = pkField.type.getDisplayString().replaceAll('?', '');
    final pkColumn = _getColumnName(pkField);

    buffer.writeln('  Future<$className?> find$className($pkType id) async {');
    buffer.writeln(
        "    final results = await query('SELECT * FROM $tableName WHERE $pkColumn = ?', [id]);");
    buffer.writeln('    if (results.isEmpty) return null;');
    buffer.writeln('    return $className.fromMap(results.first);');
    buffer.writeln('  }');
  }

  static void _generateFindAll(
    StringBuffer buffer,
    String className,
    String tableName,
  ) {
    buffer.writeln('  Future<List<$className>> all${className}s() async {');
    buffer.writeln(
        "    final results = await query('SELECT * FROM $tableName');");
    buffer.writeln(
        '    return results.map((row) => $className.fromMap(row)).toList();');
    buffer.writeln('  }');
  }

  static void _generateFindWhere(
    StringBuffer buffer,
    String className,
    String tableName,
  ) {
    buffer.writeln(
        '  Future<List<$className>> find${className}sWhere(String where, List<Object?> args) async {');
    buffer.writeln(
        "    final results = await query('SELECT * FROM $tableName WHERE \$where', args);");
    buffer.writeln(
        '    return results.map((row) => $className.fromMap(row)).toList();');
    buffer.writeln('  }');
  }

  static void _generateWatchAll(
    StringBuffer buffer,
    String className,
    String tableName,
  ) {
    buffer.writeln('  Stream<List<$className>> watchAll${className}s() {');
    buffer.writeln(
        "    return watch('SELECT * FROM $tableName').map(");
    buffer.writeln(
        '      (rows) => rows.map((row) => $className.fromMap(row)).toList(),');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  static void _generateWatchWhere(
    StringBuffer buffer,
    String className,
    String tableName,
  ) {
    buffer.writeln(
        '  Stream<List<$className>> watch${className}sWhere(String where, List<Object?> args) {');
    buffer.writeln(
        "    return watch('SELECT * FROM $tableName WHERE \$where', args).map(");
    buffer.writeln(
        '      (rows) => rows.map((row) => $className.fromMap(row)).toList(),');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  static String _getColumnName(FieldElement field) {
    // Check for @Column(name: ...) annotation
    for (final metadata in field.metadata) {
      if (metadata.element?.enclosingElement3?.name == 'Column') {
        final value = metadata.computeConstantValue();
        final name = value?.getField('name')?.toStringValue();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return _toSnakeCase(field.name);
  }

  static bool _hasAnnotation(FieldElement field, String name) {
    return field.metadata.any(
      (m) => m.element?.enclosingElement3?.name == name,
    );
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp('([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst(RegExp('^_'), '')
        .toLowerCase();
  }
}
