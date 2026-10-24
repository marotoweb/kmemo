// lib/services/encryption_service.dart

import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show debugPrint;

/// Optional encryption service for notes before sending to the cloud.
///
/// When the user sets a passphrase, each note's content is
/// encrypted on the client before upload and decrypted after download.
/// Without a passphrase, notes are stored in plain text (JSON).
class EncryptionService {
  EncryptionService._();

  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();

  enc.Encrypter? _encrypter;
  bool _enabled = false;

  /// Enables encryption with the provided passphrase.
  void enable(String passphrase) {
    final key = enc.Key.fromUtf8(passphrase.padRight(32).substring(0, 32));
    _encrypter = enc.Encrypter(enc.AES(key));
    _enabled = true;
  }

  /// Disables encryption.
  void disable() {
    _encrypter = null;
    _enabled = false;
  }

  bool get isEnabled => _enabled && _encrypter != null;

  /// Encrypts a string. Returns the original string if encryption is disabled.
  String encrypt(String plaintext) {
    if (!_enabled || _encrypter == null) {
      return plaintext;
    }
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    return '${base64UrlEncode(iv.bytes)}:${base64UrlEncode(encrypted.bytes)}';
  }

  /// Decrypts a string. Returns the original string if encryption is disabled.
  /// Returns null if decryption fails (wrong passphrase or corrupted data).
  String? tryDecrypt(String ciphertext) {
    if (!_enabled || _encrypter == null) {
      return ciphertext;
    }
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) {
        return ciphertext; // may be non-encrypted text
      }
      final iv = enc.IV(base64Url.decode(parts[0]));
      final encrypted = enc.Encrypted(base64Url.decode(parts[1]));
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('[EncryptionService] Failed to decrypt: $e');
      return null;
    }
  }

  /// Decrypts a string. Returns the original string if encryption is disabled or if decryption fails (wrong passphrase or corrupted data).
  String decrypt(String ciphertext) {
    final result = tryDecrypt(ciphertext);
    return result ?? ciphertext;
  }
}
