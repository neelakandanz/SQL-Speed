/// Configuration for database encryption.
///
/// When encryption is enabled, SQLCipher is used instead of standard SQLite.
/// All data is encrypted at rest using AES-256.
class EncryptionConfig {
  /// Creates a new [EncryptionConfig].
  const EncryptionConfig({
    required this.key,
    this.pageSize = 4096,
    this.kdfIterations = 256000,
  });

  /// The encryption key (passphrase).
  final String key;

  /// SQLCipher page size. Defaults to 4096.
  final int pageSize;

  /// Number of PBKDF2 iterations for key derivation. Defaults to 256000.
  final int kdfIterations;

  /// Returns the PRAGMA statements to configure encryption.
  List<String> get pragmas => [
        "PRAGMA key = '$key'",
        'PRAGMA cipher_page_size = $pageSize',
        'PRAGMA kdf_iter = $kdfIterations',
      ];
}
