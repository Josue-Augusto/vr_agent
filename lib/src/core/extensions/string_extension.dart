import 'dart:convert';
import 'dart:math';

import 'package:compute/compute.dart';
import 'package:vr_agent/src/core/tools/encrypt.dart';

extension StringExtension on String {
  /// Generates a random string of the specified length.
  ///
  /// @param {int} [length] - the length of the random string. If not provided, the default length is 20.
  /// @return {string} The randomly generated string.
  /// Example output: "5GKjbLZrJOTBNGA"
  String random({int? length}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    if (length != null) {
      return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    } else {
      return String.fromCharCodes(Iterable.generate(20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    }
  }

  /// Returns the hashed value of a password
  ///
  /// @description Takes a raw password string and uses the Password class to generate its hash.
  /// The hash is then returned as a String.
  ///
  ///   @example "mySecurePassword123"
  ///
  ///   @example → "$2a$10$dGhlIHNhbXBsZSBub25jZQ=="
  String hash() => Password().hash(this);

  /// Encrypts data using an isolate
  ///
  /// @description Uses the `compute` function to run the `encrypt` method in a separate isolate,
  /// allowing for background processing of potentially resource-intensive encryption tasks.
  /// Returns the encrypted string once completed.
  ///
  ///   @example → "encryptedData"
  Future<String> encryptIsolate() {
    return compute(encrypt, this);
  }

  /// Decrypts data using an isolate for background processing
  ///
  /// @description Uses the `compute` function to offload the decryption process
  /// to a separate isolate. This allows the main UI thread to remain responsive.
  /// The `decrypt` function is called with the current instance as its argument.
  ///
  ///   @example → "decrypted text"
  Future<String> decryptIsolate() {
    return compute(decrypt, this);
  }

  /// Executes the `jsonDecode` method in an Isolate ( Compute Isolate ),
  /// which means it will be run in a separate isolate,
  /// releasing the main thread. This is useful when you need
  /// process large amounts of data in JSON and do not want
  /// block the main thread. The method returns a Future that
  /// be resolved when processing is complete.
  ///
  /// @return A Future that resolves to the JSON parse result.
  dynamic jsonDecodeIsolate() => compute(jsonDecode, this);
}
