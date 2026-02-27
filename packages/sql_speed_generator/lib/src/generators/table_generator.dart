import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

/// Generates CREATE TABLE SQL statements from annotated Dart classes.
class TableGenerator {
  /// Generates the CREATE TABLE SQL for a class annotated with @Table.
  static String generateCreateTable(ClassElement classElement) {
    final tableName = _getTableName(classElement);
    final columns = <String>[];

    for (final field in classElement.fields) {
      if (field.isStatic) continue;
      if (_hasAnnotation(field, 'Ignore')) continue;

      final columnDef = _generateColumnDef(field, tableName);
      if (columnDef != null) {
        columns.add(columnDef);
      }
    }

    return 'CREATE TABLE $tableName (\n  ${columns.join(',\n  ')}\n)';
  }

  /// Gets the table name from the @Table annotation or derives from class name.
  static String _getTableName(ClassElement classElement) {
    final tableAnnotation = _getAnnotation(classElement, 'Table');
    if (tableAnnotation != null) {
      final name = tableAnnotation.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) return name;
    }
    return _toSnakeCase(classElement.name);
  }

  /// Generates a column definition for a single field.
  static String? _generateColumnDef(FieldElement field, String tableName) {
    final columnName = _getColumnName(field);
    final sqlType = _getSqlType(field);
    final buffer = StringBuffer('$columnName $sqlType');

    // Primary key
    if (_hasAnnotation(field, 'PrimaryKey')) {
      buffer.write(' PRIMARY KEY');
      final pkAnnotation = _getAnnotation(field, 'PrimaryKey');
      final autoIncrement =
          pkAnnotation?.getField('autoIncrement')?.toBoolValue() ?? true;
      if (autoIncrement) {
        buffer.write(' AUTOINCREMENT');
      }
    }

    // NOT NULL
    if (_hasAnnotation(field, 'NotNull')) {
      buffer.write(' NOT NULL');
    }

    // DEFAULT value
    if (_hasAnnotation(field, 'DefaultValue')) {
      final defaultAnnotation = _getAnnotation(field, 'DefaultValue');
      final value = defaultAnnotation?.getField('value');
      if (value != null) {
        final defaultStr = value.toBoolValue() != null
            ? (value.toBoolValue()! ? '1' : '0')
            : value.toIntValue()?.toString() ??
                value.toDoubleValue()?.toString() ??
                "'${value.toStringValue()}'";
        buffer.write(' DEFAULT $defaultStr');
      }
    }

    return buffer.toString();
  }

  /// Gets the column name from @Column annotation or derives from field name.
  static String _getColumnName(FieldElement field) {
    final columnAnnotation = _getAnnotation(field, 'Column');
    if (columnAnnotation != null) {
      final name = columnAnnotation.getField('name')?.toStringValue();
      if (name != null && name.isNotEmpty) return name;
    }
    return _toSnakeCase(field.name);
  }

  /// Determines the SQLite type for a field.
  static String _getSqlType(FieldElement field) {
    // Check for explicit @ColumnType
    final typeAnnotation = _getAnnotation(field, 'ColumnType');
    if (typeAnnotation != null) {
      final typeIndex = typeAnnotation.getField('type')?.getField('index')?.toIntValue();
      if (typeIndex != null) {
        return const ['INTEGER', 'REAL', 'TEXT', 'BLOB'][typeIndex];
      }
    }

    // Check for @JsonColumn
    if (_hasAnnotation(field, 'JsonColumn')) return 'TEXT';

    // Auto-detect from Dart type
    final typeName = field.type.getDisplayString();
    if (typeName.startsWith('int')) return 'INTEGER';
    if (typeName.startsWith('double')) return 'REAL';
    if (typeName.startsWith('String')) return 'TEXT';
    if (typeName.startsWith('bool')) return 'INTEGER';
    if (typeName.startsWith('DateTime')) return 'INTEGER';
    if (typeName.startsWith('Uint8List')) return 'BLOB';
    return 'TEXT';
  }

  static bool _hasAnnotation(Element element, String name) {
    return element.metadata.any(
      (m) => m.element?.enclosingElement3?.name == name,
    );
  }

  static DartObject? _getAnnotation(Element element, String name) {
    for (final metadata in element.metadata) {
      if (metadata.element?.enclosingElement3?.name == name) {
        return metadata.computeConstantValue();
      }
    }
    return null;
  }

  /// Converts a camelCase string to snake_case.
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
