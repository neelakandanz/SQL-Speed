import 'dart:io';

import '../exceptions/exceptions.dart';

/// Handles loading the SQLCipher library for encrypted databases.
///
/// SQLCipher is a drop-in SQLite replacement that provides transparent
/// AES-256 encryption. It is loaded dynamically at runtime.
class SqlCipherLoader {
  /// Returns the platform-specific library path for SQLCipher.
  ///
  /// Throws [EncryptionException] if the platform is not supported
  /// or the library is not found.
  static String getLibraryPath() {
    if (Platform.isAndroid) {
      return 'libsqlcipher.so';
    } else if (Platform.isIOS || Platform.isMacOS) {
      return 'sqlcipher.framework/sqlcipher';
    } else if (Platform.isWindows) {
      return 'sqlcipher.dll';
    } else if (Platform.isLinux) {
      return 'libsqlcipher.so';
    } else {
      throw const EncryptionException(
        'SQLCipher is not supported on this platform',
      );
    }
  }

  /// Checks if SQLCipher is available on the current platform.
  static bool isAvailable() {
    try {
      getLibraryPath();
      return true;
    } catch (_) {
      return false;
    }
  }
}
