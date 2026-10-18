// lib/services/encryption_service.dart

import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;

/// Serviço de encriptação opcional para notas antes de enviar para a nuvem.
///
/// Quando o utilizador define uma passphrase, o conteúdo de cada nota é
/// encriptado no cliente antes do upload e decriptado após o download.
/// Sem passphrase, as notas são armazenadas em texto claro (JSON).
class EncryptionService {
  EncryptionService._();

  static EncryptionService? _instance;
  static EncryptionService get instance => _instance ??= EncryptionService._();

  enc.Encrypter? _encrypter;
  bool _enabled = false;

  /// Ativa a encriptação com a passphrase fornecida.
  void enable(String passphrase) {
    final key = enc.Key.fromUtf8(passphrase.padRight(32).substring(0, 32));
    _encrypter = enc.Encrypter(enc.AES(key));
    _enabled = true;
  }

  /// Desativa a encriptação.
  void disable() {
    _encrypter = null;
    _enabled = false;
  }

  bool get isEnabled => _enabled && _encrypter != null;

  /// Encripta uma string. Retorna a string original se a encriptação estiver desativada.
  String encrypt(String plaintext) {
    if (!_enabled || _encrypter == null) {
      return plaintext;
    }
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    return base64UrlEncode(iv.bytes) + ':' + base64UrlEncode(encrypted.bytes);
  }

  /// Decripta uma string. Retorna a string original se a encriptação estiver desativada.
  String decrypt(String ciphertext) {
    if (!_enabled || _encrypter == null) {
      return ciphertext;
    }
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) {
        return ciphertext;
      }
      final iv = enc.IV(base64Url.decode(parts[0]));
      final encrypted = enc.Encrypted(base64Url.decode(parts[1]));
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (_) {
      return ciphertext;
    }
  }
}
