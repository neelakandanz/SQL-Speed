import 'package:analyzer/dart/element/element.dart';

/// Generates reactive stream watcher methods for model classes.
///
/// These methods return `Stream<List<T>>` that auto-update
/// when the underlying table changes.
class StreamGenerator {
  /// Generates stream extension methods for a model class.
  static String generate(ClassElement classElement) {
    final className = classElement.name;
    final tableName = _toSnakeCase(className);

    final buffer = StringBuffer();

    buffer.writeln(
        'extension ${className}StreamQueries on SqlSpeedDatabase {');

    // Watch all
    buffer.writeln('  Stream<List<$className>> watchAll${className}s() {');
    buffer.writeln("    return watch('SELECT * FROM $tableName').map(");
    buffer.writeln(
        '      (rows) => rows.map((row) => $className.fromMap(row)).toList(),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Watch with WHERE
    buffer.writeln(
        '  Stream<List<$className>> watch${className}sWhere(String where, [List<Object?>? args]) {');
    buffer.writeln(
        "    return watch('SELECT * FROM $tableName WHERE \$where', args).map(");
    buffer.writeln(
        '      (rows) => rows.map((row) => $className.fromMap(row)).toList(),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // Watch count
    buffer.writeln('  Stream<int> watch${className}Count() {');
    buffer.writeln(
        "    return watch('SELECT COUNT(*) as count FROM $tableName').map(");
    buffer.writeln('      (rows) => (rows.first[\'count\'] as int?) ?? 0,');
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');

    return buffer.toString();
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
