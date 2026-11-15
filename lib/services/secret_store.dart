// lib/services/secret_store.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when the platform keychain refuses to store a secret.
///
/// The caller can keep working with the value it already has in memory, but it
/// must tell the user that it will be lost when the app closes.
class SecretStoreUnavailable implements Exception {
  const SecretStoreUnavailable();

  @override
  String toString() => 'SecretStoreUnavailable';
}

/// Wrapper around [FlutterSecureStorage] that never crashes the app.
///
/// The plugin backs onto the platform keychain: Keystore on Android and the
/// desktop keyring (libsecret, i.e. gnome-keyring or KWallet) on Linux. A
/// headless session, a locked keyring or a missing keyring daemon makes every
/// call throw `PlatformException`; before this wrapper the first read in
/// `main()` killed the app before the notes screen was built.
///
/// Failures are therefore swallowed here: [read] returns null and [write]
/// returns false, so the caller decides what to do. Nothing about the secret
/// is logged, only the failure code.
class SecretStore {
  SecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  bool _unavailable = false;

  /// True once the platform keychain refused an operation in this session.
  bool get isUnavailable => _unavailable;

  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (error) {
      _fail('read', error.code);
      return null;
    } on MissingPluginException {
      // A desktop build without libsecret cannot load the plugin at all.
      _fail('read', 'MissingPluginException');
      return null;
    }
  }

  /// Saves [value]; returns false when the keychain refused it.
  Future<bool> write({required String key, required String? value}) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } on PlatformException catch (error) {
      _fail('write', error.code);
      return false;
    } on MissingPluginException {
      _fail('write', 'MissingPluginException');
      return false;
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } on PlatformException catch (error) {
      _fail('delete', error.code);
    } on MissingPluginException {
      _fail('delete', 'MissingPluginException');
    }
  }

  void _fail(String operation, String reason) {
    _unavailable = true;
    // Never log the value or the key's content, only what failed and why.
    debugPrint('[SecretStore] $operation failed: $reason');
  }
}
