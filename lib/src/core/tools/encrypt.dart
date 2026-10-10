import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as cry;

class Password {
  String hash(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class Encrypt {
  // 🔒 Pre-key defined in the code (NOT THE FINAL KEY)
  static const String _preKey = 'u9DGA1p4xFVn2RBURFQa2DaaaouST8NOGjGXuBqztLrKoklEQfJ4hUjOmV4Ai00S1kw29DFITUzMQRMuSZapaRGDXUwq6ogPoMmT!';
  static const String _salt = 'cfUJSPJpSFXm81InzHDPmteqRIZfbW3V';

  /// Generates a 32-byte encryption key from [_preKey] and [_salt].
  ///
  /// The key is generated using the HMAC-SHA256 algorithm, which combines the [_preKey]
  /// with [_salt] and applies the resulting hash function. The result is a key
  /// of 256 bits (32 bytes) that is used to encrypt the information.
  static cry.Key _generateKey() {
    final keyBytes = utf8.encode(_preKey);
    final salt = utf8.encode(_salt);
    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(salt).bytes;
    return cry.Key(Uint8List.fromList(digest.sublist(0, 32)));
  }

  /// Creates an instance of cryptography using a Fernet encryption scheme.
  ///
  /// This method generates a cryptographic key using the `_GenerateKey()` method
  /// and initializes a Fernet instance with it. The Fernet instance is then used
  /// To create and return a new CRYPTER object.
  ///
  /// @return An encryption configured with Fernet encryption.
  static cry.Encrypter cryEncripter() {
    final key = _generateKey();
    final fernet = cry.Fernet(key);
    return cry.Encrypter(fernet);
  }

  /// Generates an encryption key of a specified size in bits from an input string (seed).
  ///
  /// This method is useful for generating encryption keys from any input string.
  /// The method uses the SHA-256 algorithm to generate a hash of the input string and then
  /// adjusts the size of the hash to the desired size. If the desired size is smaller than the hash,
  /// the first bytes of the hash are returned. If the desired size is greater than the hash,
  /// the hash is repeated until it reaches the desired size.
  /// ```
  /// @param seed The input string used to generate the key.
  /// @param keySizeInBits The desired key size in bits.
  ///
  /// 128 bits (16 bytes)
  /// 256 bits (32 bytes)
  /// 512 bits (64 bytes)
  /// 768 bits (96 bytes)
  ///
  /// @return An encryption key of specified size in bytes.
  /// ```
  static Uint8List generateKeyFromSeed({required String seed, required int keySizeInBits}) {
    if (keySizeInBits % 8 != 0) {
      throw ArgumentError('O tamanho da chave em bits deve ser um múltiplo de 8.');
    }
    final keySizeInBytes = keySizeInBits ~/ 8;

    // Use SHA-256 to generate a hash of the input string.
    // SHA-256 produces a 256-bit (32 byte) hash.
    final bytes = utf8.encode(seed);
    final digest = sha256.convert(bytes);

    // If the desired key size is equal to the SHA-256 hash size,
    // we can return the hash directly.
    if (keySizeInBytes == digest.bytes.length) {
      return Uint8List.fromList(digest.bytes);
    }

    // If the desired key size is smaller than the SHA-256 hash,
    // we get the first 'keySizeInBytes' bytes of the hash.
    if (keySizeInBytes < digest.bytes.length) {
      return Uint8List.fromList(digest.bytes.sublist(0, keySizeInBytes));
    }
    // If the desired key size is greater than the SHA-256 hash,
    // we can repeat the hash or use a key derivation algorithm (KDF)
    // to safely generate more bytes. For this simple example,
    // we will repeat the hash until we reach the desired size.
    final key = Uint8List(keySizeInBytes);
    for (var i = 0; i < keySizeInBytes; i++) {
      key[i] = digest.bytes[i % digest.bytes.length];
    }
    return key;
  }
}

/// Decrypts the current string, which was previously encrypted with the Fernet algorithm,
/// using the same Fernet encryptor derived from the same secure key.
///
/// This method just decrypts the string in base 64, which must have been previously
/// encrypted with the method `encrypt()`.
///
/// @return The decrypted string.
String decrypt(String encrypted) {
  final encrypter = Encrypt.cryEncripter();
  return encrypter.decrypt64(encrypted);
}

/// Encrypts the current string using the Fernet algorithm.
///
/// This method converts the string into a base-64 encrypted representation.
/// Uses a Fernet encryptor derived from a secure key to perform encryption.
///
/// @return The base 64 encrypted string.
String encrypt(String text) {
  final encrypter = Encrypt.cryEncripter();
  final encrypted = encrypter.encrypt(text);
  return encrypted.base64;
}
