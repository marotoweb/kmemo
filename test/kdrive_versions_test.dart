// test/kdrive_versions_test.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<KDriveStorage> configuredStorage(http.Client client) async {
    final storage = KDriveStorage(client: client);
    await storage.configure(
      token: 'token',
      driveId: 3318607,
      driveName: 'drive',
      folderId: '57',
      remoteFolder: 'kmemo/notes',
    );
    return storage;
  }

  test('clearing versions deletes the history of a note', () async {
    final requests = <http.Request>[];
    final storage = await configuredStorage(
      MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'result': 'success'}), 200);
      }),
    );

    expect(await storage.clearVersions('365'), isTrue);

    // Versioning stays on: uploads still use conflict=version, so old content
    // is kept until the user explicitly clears it with the v2 versions API.
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.path, '/2/drive/3318607/files/365/versions');
  });

  test('a missing remote note is not treated as a fatal error', () async {
    final storage = await configuredStorage(
      MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': 'error',
            'error': {'code': 'object_not_found', 'description': 'Not found'},
          }),
          404,
        );
      }),
    );

    expect(await storage.clearVersions('999'), isFalse);
  });
}
