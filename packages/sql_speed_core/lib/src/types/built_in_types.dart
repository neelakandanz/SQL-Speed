import 'dart:convert';
import 'dart:typed_data';

import 'type_registry.dart';

/// Registers all built-in Dart↔SQLite type converters.
void registerBuiltInTypes(TypeRegistry registry) {
  // bool → INTEGER (0/1)
  registry.register<bool>(
    encode: (value) => value ? 1 : 0,
    decode: (value) {
      if (value is int) return value != 0;
      if (value is bool) return value;
      throw ArgumentError('Cannot decode $value to bool');
    },
  );

  // DateTime → INTEGER (milliseconds since epoch)
  registry.register<DateTime>(
    encode: (value) => value.millisecondsSinceEpoch,
    decode: (value) {
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.parse(value);
      throw ArgumentError('Cannot decode $value to DateTime');
    },
  );

  // Uint8List → BLOB (passthrough, SQLite native)
  registry.register<Uint8List>(
    encode: (value) => value,
    decode: (value) {
      if (value is Uint8List) return value;
      if (value is List<int>) return Uint8List.fromList(value);
      throw ArgumentError('Cannot decode $value to Uint8List');
    },
  );

  // List<dynamic> → TEXT (JSON encoded)
  registry.register<List<dynamic>>(
    encode: (value) => jsonEncode(value),
    decode: (value) {
      if (value is String) return jsonDecode(value) as List<dynamic>;
      if (value is List) return value;
      throw ArgumentError('Cannot decode $value to List');
    },
  );

  // Map<String, dynamic> → TEXT (JSON encoded)
  registry.register<Map<String, dynamic>>(
    encode: (value) => jsonEncode(value),
    decode: (value) {
      if (value is String) {
        return jsonDecode(value) as Map<String, dynamic>;
      }
      if (value is Map) return Map<String, dynamic>.from(value);
      throw ArgumentError('Cannot decode $value to Map');
    },
  );
}
