// test/secret_store_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/services/secret_store.dart';

/// The channel the flutter_secure_storage plugin talks to. Replacing its
/// handler is how the failure of a desktop keyring is reproduced: libsecret
/// answers `KeyringLocked` and every call throws a PlatformException.
const MethodChannel _channel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('a locked keyring', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            throw PlatformException(code: 'KeyringLocked');
          });
    });

    test('a read returns null instead of throwing', () async {
      final store = SecretStore();

      expect(await store.read(key: 'kdrive_token'), isNull);
      expect(store.isUnavailable, isTrue);
    });

    test('a write reports failure', () async {
      final store = SecretStore();

      expect(await store.write(key: 'webdav_password', value: 'x'), isFalse);
      expect(store.isUnavailable, isTrue);
    });

    test('a delete does not throw', () async {
      final store = SecretStore();

      await store.delete(key: 'webdav_password');
      expect(store.isUnavailable, isTrue);
    });
  });

  test('a missing plugin is handled like a locked keyring', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          throw MissingPluginException();
        });

    final store = SecretStore();

    expect(await store.read(key: 'kdrive_token'), isNull);
    expect(await store.write(key: 'kdrive_token', value: 'x'), isFalse);
    expect(store.isUnavailable, isTrue);
  });

  test('a working keyring is reported as available', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'read':
              return null;
            case 'write':
            case 'delete':
              return null;
            case 'readAll':
              return <String, String>{};
            case 'deleteAll':
              return null;
            case 'containsKey':
              return false;
          }
          return null;
        });

    final store = SecretStore();
    expect(await store.read(key: 'kdrive_token'), isNull);
    expect(await store.write(key: 'kdrive_token', value: 'abc'), isTrue);
    expect(store.isUnavailable, isFalse);
  });
}
