import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';

import 'annotations/table.dart';
import 'generators/table_generator.dart';
import 'generators/crud_generator.dart';
import 'generators/mapper_generator.dart';

/// Build runner entry point for sql_speed code generation.
///
/// Usage in `build.yaml`:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       sql_speed_generator|sql_speed:
///         enabled: true
/// ```
Builder sqlSpeedBuilder(BuilderOptions options) =>
    SharedPartBuilder([SqlSpeedGenerator()], 'sql_speed');

/// The main source generator for sql_speed.
///
/// Processes classes annotated with `@Table` and generates:
/// - CREATE TABLE SQL statement (as a comment)
/// - CRUD extension methods
/// - toMap/fromMap mapping methods
/// - Reactive stream watcher methods
class SqlSpeedGenerator extends GeneratorForAnnotation<Table> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@Table can only be applied to classes.',
        element: element,
      );
    }

    final classElement = element;
    final buffer = StringBuffer();

    // Header comment
    buffer.writeln('// ==========================================');
    buffer.writeln('// GENERATED CODE — DO NOT MODIFY BY HAND');
    buffer.writeln('// ==========================================');
    buffer.writeln();

    // CREATE TABLE SQL (as a comment for reference)
    final createSql = TableGenerator.generateCreateTable(classElement);
    buffer.writeln('// SQL:');
    for (final line in createSql.split('\n')) {
      buffer.writeln('// $line');
    }
    buffer.writeln();

    // CRUD methods
    buffer.writeln(CrudGenerator.generate(classElement));
    buffer.writeln();

    // Mapper methods
    buffer.writeln(MapperGenerator.generate(classElement));

    return buffer.toString();
  }
}
