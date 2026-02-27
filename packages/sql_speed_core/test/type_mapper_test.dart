import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:sql_speed_core/src/types/type_mapper.dart';

void main() {
  late TypeMapper mapper;

  setUp(() {
    mapper = TypeMapper();
  });

  group('TypeMapper', () {
    group('toSqlite', () {
      test('passes through null', () {
        expect(mapper.toSqlite(null), isNull);
      });

      test('passes through int', () {
        expect(mapper.toSqlite(42), equals(42));
      });

      test('passes through double', () {
        expect(mapper.toSqlite(3.14), equals(3.14));
      });

      test('passes through String', () {
        expect(mapper.toSqlite('hello'), equals('hello'));
      });

      test('converts bool true to 1', () {
        expect(mapper.toSqlite(true), equals(1));
      });

      test('converts bool false to 0', () {
        expect(mapper.toSqlite(false), equals(0));
      });

      test('converts DateTime to milliseconds since epoch', () {
        final dt = DateTime(2024, 1, 15, 12, 0, 0);
        expect(mapper.toSqlite(dt), equals(dt.millisecondsSinceEpoch));
      });

      test('passes through Uint8List', () {
        final bytes = Uint8List.fromList([1, 2, 3]);
        expect(mapper.toSqlite(bytes), equals(bytes));
      });

      test('converts List to JSON string', () {
        expect(mapper.toSqlite([1, 2, 3]), equals('[1,2,3]'));
      });

      test('converts Map to JSON string', () {
        final result = mapper.toSqlite({'key': 'value'});
        expect(result, equals('{"key":"value"}'));
      });
    });

    group('fromSqlite', () {
      test('decodes bool from int', () {
        expect(mapper.fromSqlite<bool>(1), isTrue);
        expect(mapper.fromSqlite<bool>(0), isFalse);
      });

      test('decodes DateTime from int', () {
        final ms = DateTime(2024, 1, 15).millisecondsSinceEpoch;
        final result = mapper.fromSqlite<DateTime>(ms);
        expect(result.year, equals(2024));
        expect(result.month, equals(1));
        expect(result.day, equals(15));
      });

      test('decodes int directly', () {
        expect(mapper.fromSqlite<int>(42), equals(42));
      });

      test('decodes String directly', () {
        expect(mapper.fromSqlite<String>('hello'), equals('hello'));
      });
    });

    group('sqliteTypeName', () {
      test('maps int to INTEGER', () {
        expect(TypeMapper.sqliteTypeName(int), equals('INTEGER'));
      });

      test('maps double to REAL', () {
        expect(TypeMapper.sqliteTypeName(double), equals('REAL'));
      });

      test('maps String to TEXT', () {
        expect(TypeMapper.sqliteTypeName(String), equals('TEXT'));
      });

      test('maps bool to INTEGER', () {
        expect(TypeMapper.sqliteTypeName(bool), equals('INTEGER'));
      });

      test('maps DateTime to INTEGER', () {
        expect(TypeMapper.sqliteTypeName(DateTime), equals('INTEGER'));
      });

      test('maps Uint8List to BLOB', () {
        expect(TypeMapper.sqliteTypeName(Uint8List), equals('BLOB'));
      });
    });

    group('custom types', () {
      test('registers and uses custom converter', () {
        mapper.register<Uri>(
          encode: (uri) => uri.toString(),
          decode: (value) => Uri.parse(value as String),
        );

        expect(mapper.registry.hasConverter<Uri>(), isTrue);
      });
    });
  });
}
