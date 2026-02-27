import 'dart:io';

/// Resolves platform-specific database configuration.
class PlatformResolver {
  /// Returns the current platform type.
  static PlatformType get current {
    if (Platform.isAndroid) return PlatformType.android;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isLinux) return PlatformType.linux;
    return PlatformType.unknown;
  }

  /// Returns true if the current platform is a mobile platform.
  static bool get isMobile =>
      Platform.isAndroid || Platform.isIOS;

  /// Returns true if the current platform is a desktop platform.
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  /// Returns the platform-specific SQLite library name.
  static String get sqliteLibraryName {
    if (Platform.isAndroid) return 'libsqlite3.so';
    if (Platform.isIOS || Platform.isMacOS) return 'sqlite3';
    if (Platform.isWindows) return 'sqlite3.dll';
    if (Platform.isLinux) return 'libsqlite3.so';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}

/// Supported platform types.
enum PlatformType {
  android,
  ios,
  macos,
  windows,
  linux,
  unknown,
}
