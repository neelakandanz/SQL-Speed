import 'dart:typed_data';

import 'built_in_types.dart';
import 'type_registry.dart';

/// Maps Dart types to SQLite types and handles value conversion.
///
/// Uses a [TypeRegistry] for custom types and handles built-in types
/// (int, double, String, bool, DateTime, Uint8List) automatically.
class TypeMapper {
  /// Creates a new [TypeMapper] with built-in type converters registered.
  TypeMapper() {
    registerBuiltInTypes(_registry);
  }

  final TypeRegistry _registry = TypeRegistry();

  /// Access the underlying registry to add custom converters.
  TypeRegistry get registry => _registry;

  /// Registers a custom type converter for type [T].
  void register<T>({
    required TypeEncoder<T> encode,
    required TypeDecoder<T> decode,
  }) {
    _registry.register<T>(encode: encode, decode: decode);
  }

  /// Converts a Dart value to a SQLite-compatible value.
  ///
  /// - `null` → `null`
  /// - `int`, `double`, `String` → passthrough (native SQLite types)
  /// - `bool` → `int` (0/1)
  /// - `DateTime` → `int` (milliseconds since epoch)
  /// - `Uint8List` → `Uint8List` (BLOB)
  /// - Custom types → uses registered converter
  Object? toSqlite(Object? value) {
    if (value == null) return null;
    if (value is int || value is double || value is String) return value;
    if (value is Uint8List) return value;

    if (value is bool) return _registry.encode<bool>(value);
    if (value is DateTime) return _registry.encode<DateTime>(value);
    if (value is List) return _registry.encode<List<dynamic>>(value);
    if (value is Map<String, dynamic>) {
      return _registry.encode<Map<String, dynamic>>(value);
    }

    // Try custom converter by runtime type
    if (_registry.hasConverterForType(value.runtimeType)) {
      return _registry.encode(value);
    }

    return value;
  }

  /// Converts a SQLite value to the expected Dart type [T].
  T fromSqlite<T>(Object? value) {
    if (value == null) return null as T;
    if (_registry.hasConverter<T>()) {
      return _registry.decode<T>(value);
    }
    return value as T;
  }

  /// Returns the SQLite type name for a Dart type.
  static String sqliteTypeName(Type dartType) {
    if (dartType == int) return 'INTEGER';
    if (dartType == double) return 'REAL';
    if (dartType == String) return 'TEXT';
    if (dartType == bool) return 'INTEGER';
    if (dartType == DateTime) return 'INTEGER';
    if (dartType == Uint8List) return 'BLOB';
    return 'TEXT'; // Default: store as TEXT (JSON)
  }
}
