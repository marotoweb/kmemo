// Tests for kDrive folder listing pagination.
//
// The v3 "get files in directory" endpoint uses cursor-based pagination
// (`cursor` + `has_more`). Sending `page`/`per_page` makes the API answer
// with HTTP 422, which used to surface as an empty folder in the app.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> files,
  String? cursor,
  bool? hasMore,
}) {
  final page = <String, dynamic>{'result': 'success', 'data': files};
  if (cursor != null) page['cursor'] = cursor;
  if (hasMore != null) page['has_more'] = hasMore;
  return page;
}

List<Map<String, dynamic>> _files(int start, int count) {
  return List.generate(
    count,
    (i) => {'id': start + i, 'name': 'note_${start + i}.json', 'type': 'file'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<KDriveStorage> configuredStorage(http.Client client) async {
    final storage = KDriveStorage(client: client);
    await storage.configure(
      token: 'test-token',
      driveId: 123,
      driveName: 'Test drive',
      folderId: '5',
      folderName: 'Private',
    );
    return storage;
  }

  test('listFolderContents follows the cursor until has_more is false',
      () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      final cursor = request.url.queryParameters['cursor'];
      if (cursor == null) {
        return http.Response(
          jsonEncode(_page(files: _files(0, 10), cursor: 'c2', hasMore: true)),
          200,
        );
      }
      if (cursor == 'c2') {
        return http.Response(
          jsonEncode(_page(files: _files(10, 10), cursor: 'c3', hasMore: true)),
          200,
        );
      }
      return http.Response(
        jsonEncode(_page(files: _files(20, 1), hasMore: false)),
        200,
      );
    });

    final storage = await configuredStorage(client);
    final files = await storage.listFolderContents('5');

    expect(files, hasLength(21));
    expect(requestedUris, hasLength(3));
    expect(requestedUris[0].queryParameters.containsKey('page'), isFalse);
    expect(requestedUris[0].queryParameters.containsKey('per_page'), isFalse);
    expect(requestedUris[0].queryParameters.containsKey('cursor'), isFalse);
    expect(requestedUris[1].queryParameters['cursor'], 'c2');
    expect(requestedUris[2].queryParameters['cursor'], 'c3');
  });

  test('listFolderContents keeps going when has_more is missing', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      if (request.url.queryParameters['cursor'] == null) {
        return http.Response(
          jsonEncode(_page(files: _files(0, 10), cursor: 'c2')),
          200,
        );
      }
      return http.Response(jsonEncode(_page(files: _files(10, 5))), 200);
    });

    final storage = await configuredStorage(client);
    final files = await storage.listFolderContents('5');

    expect(files, hasLength(15));
    expect(requestedUris, hasLength(2));
  });

  test('listFolderContents stops when the cursor does not advance', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      return http.Response(
        jsonEncode(_page(files: _files(0, 10), cursor: 'same', hasMore: true)),
        200,
      );
    });

    final storage = await configuredStorage(client);
    final files = await storage.listFolderContents('5');

    // First page is kept; the repeated cursor must not duplicate it.
    expect(files, hasLength(10));
    expect(requestedUris, hasLength(2));
  });

  test('listFolderContents returns an empty list on HTTP errors', () async {
    final client = MockClient((request) async {
      return http.Response('{"result":"error"}', 422);
    });

    final storage = await configuredStorage(client);
    final files = await storage.listFolderContents('5');

    expect(files, isEmpty);
  });
}
