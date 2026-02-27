/// A converter that encodes a Dart value to a SQLite-compatible value.
typedef TypeEncoder<T> = Object? Function(T value);

/// A converter that decodes a SQLite value to a Dart type.
typedef TypeDecoder<T> = T Function(Object? value);

/// A registered type converter pair.
class TypeConverter<T> {
  /// Creates a new [TypeConverter].
  const TypeConverter({required this.encode, required this.decode});

  /// Encodes a Dart value to a SQLite-compatible value.
  final TypeEncoder<T> encode;

  /// Decodes a SQLite value to a Dart type.
  final TypeDecoder<T> decode;
}

/// Registry that manages type converters for Dart↔SQLite type mapping.
class TypeRegistry {
  final Map<Type, TypeConverter<dynamic>> _converters = {};

  /// Registers a type converter for type [T].
  ///
  /// ```dart
  /// registry.register<Money>(
  ///   encode: (money) => money.cents,
  ///   decode: (value) => Money(value as int),
  /// );
  /// ```
  void register<T>({
    required TypeEncoder<T> encode,
    required TypeDecoder<T> decode,
  }) {
    _converters[T] = TypeConverter<T>(encode: encode, decode: decode);
  }

  /// Returns true if a converter is registered for type [T].
  bool hasConverter<T>() => _converters.containsKey(T);

  /// Returns true if a converter is registered for the given [type].
  bool hasConverterForType(Type type) => _converters.containsKey(type);

  /// Encodes a Dart value of type [T] to a SQLite-compatible value.
  Object? encode<T>(T value) {
    final converter = _converters[T];
    if (converter == null) return value;
    return (converter as TypeConverter<T>).encode(value);
  }

  /// Decodes a SQLite value to a Dart value of type [T].
  T decode<T>(Object? value) {
    final converter = _converters[T];
    if (converter == null) return value as T;
    return (converter as TypeConverter<T>).decode(value);
  }

  /// Removes the converter for type [T].
  void unregister<T>() {
    _converters.remove(T);
  }

  /// Removes all registered converters.
  void clear() {
    _converters.clear();
  }
}
