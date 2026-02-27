import 'package:analyzer/dart/element/element.dart';

/// Generates `toMap()` and `fromMap()` methods for model classes.
class MapperGenerator {
  /// Generates the fromMap factory and toMap method for a model class.
  static String generate(ClassElement classElement) {
    final className = classElement.name;
    final fields = classElement.fields
        .where((f) => !f.isStatic && !_hasAnnotation(f, 'Ignore'))
        .toList();

    final buffer = StringBuffer();

    // fromMap factory
    buffer.writeln('extension ${className}Mapping on $className {');
    buffer.writeln(
        '  static $className fromMap(Map<String, Object?> map) {');
    buffer.writeln('    return $className(');
    for (final field in fields) {
      final columnName = _getColumnName(field);
      final dartType = field.type.getDisplayString();
      buffer.writeln(
          "      ${field.name}: map['$columnName'] as $dartType,");
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // toMap method
    buffer.writeln('  Map<String, Object?> toMap() {');
    buffer.writeln('    return {');
    for (final field in fields) {
      final columnName = _getColumnName(field);
      buffer.writeln("      '$columnName': ${field.name},");
    }
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  static String _getColumnName(FieldElement field) {
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
