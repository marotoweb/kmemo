// test/kdrive_upload_test.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('uploading an existing note sends one create request', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'result': 'success',
          'data': {'id': 42},
        }),
        200,
      );
    });
    final storage = KDriveStorage(client: client);
    await storage.configure(
      token: 'token',
      driveId: 3318607,
      driveName: 'drive',
      folderId: '57',
      remoteFolder: 'kmemo/notes',
    );

    final now = DateTime.utc(2026, 11, 13);
    final memo = Memo(
      uuid: 'memo-uuid',
      title: 'Note',
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      remoteFileId: '365',
      colorIndex: 0,
      bgImageIndex: -1,
      imageAttachments: '[]',
      audioAttachments: '[]',
      linkAttachments: '[]',
      isArchived: false,
      isDeleted: false,
      isPinned: false,
      sortIndex: 0,
    );
    final blocks = [
      Block(
        id: 0,
        uuid: 'block-uuid',
        memoUuid: 'memo-uuid',
        type: BlockType.text,
        content: {'text': 'hello'},
        sortOrder: 0,
        isDeleted: false,
      ),
    ];

    final remoteId = await storage.uploadMemo(memo, blocks);

    expect(remoteId, '42');
    // The kDrive API rejects `file_id` combined with `file_name`/`conflict`
    // (HTTP 422), which used to trigger a second "create" request and leave
    // the previous remote file orphaned. A note with a remoteFileId must be
    // overwritten by name in a single upload.
    expect(requests, hasLength(1));
    final url = requests.single.url;
    expect(url.path, endsWith('/3/drive/3318607/upload'));
    expect(url.queryParameters['file_id'], isNull);
    expect(url.queryParameters['file_name'], 'memo-uuid.json');
    expect(url.queryParameters['conflict'], 'version');
    expect(url.queryParameters['directory_id'], '57');
    expect(url.queryParameters['total_size'], isNotNull);
  });
}
