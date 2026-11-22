// test/kdrive_listing_revision_test.dart
//
// The kDrive listing used `updated_at` as the revision of a note file. That
// timestamp follows the file metadata: a new version uploaded by another
// device does not change it, so every device kept the revision it had
// recorded, planned no inspection and never downloaded the edit. This is the
// "synchronization is not working between two Android devices" report: the
// note was uploaded by device B and device A answered "0 upload, 0 inspect".

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kmemo/services/kdrive_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _page(List<Map<String, dynamic>> files) => {
  'result': 'success',
  'data': files,
  'has_more': false,
};

Future<KDriveStorage> _storageFor(http.Client client) async {
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

DateTime _fromSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a new version changes the revision even when updated_at does not',
      () async {
    // Two versions of the same note, one minute apart. `updated_at` is the
    // file metadata timestamp and does not move when the content changes.
    const metadataAt = 1763000000;
    var revisedAt = 1763715600;

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          _page([
            {
              'id': 7,
              'name': 'note.json',
              'type': 'file',
              'revised_at': revisedAt,
              'updated_at': metadataAt,
              'last_modified_at': metadataAt,
              'added_at': metadataAt,
            },
          ]),
        ),
        200,
      );
    });

    final storage = await _storageFor(client);

    final before = (await storage.listRemoteMemos()).single.updatedAt;
    expect(before, _fromSeconds(1763715600));

    revisedAt += 60;
    final after = (await storage.listRemoteMemos()).single.updatedAt;

    expect(after, _fromSeconds(1763715660));
    expect(
      after.isAfter(before),
      isTrue,
      reason: 'an upload by another device must move the revision',
    );
  });

  test('the revision is read in seconds, not milliseconds', () async {
    const revisedAt = 1763715600;
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          _page([
            {'id': 7, 'name': 'note.json', 'type': 'file', 'revised_at': revisedAt},
          ]),
        ),
        200,
      );
    });

    final storage = await _storageFor(client);
    final revision = (await storage.listRemoteMemos()).single.updatedAt;

    expect(revision.year, 2025);
    expect(revision, _fromSeconds(revisedAt));
  });

  test('a missing revised_at falls back to the other timestamps', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          _page([
            {
              'id': 7,
              'name': 'note.json',
              'type': 'file',
              'updated_at': 1763715000,
              'last_modified_at': 1763000000,
            },
            {
              'id': 8,
              'name': 'other.json',
              'type': 'file',
              'last_modified_at': 1763000000,
            },
          ]),
        ),
        200,
      );
    });

    final storage = await _storageFor(client);
    final notes = await storage.listRemoteMemos();

    expect(notes.firstWhere((n) => n.name == 'note.json').updatedAt,
        _fromSeconds(1763715000));
    expect(notes.firstWhere((n) => n.name == 'other.json').updatedAt,
        _fromSeconds(1763000000));
  });

  test('string and millisecond timestamps are accepted', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          _page([
            {'id': 7, 'name': 'a.json', 'type': 'file', 'revised_at': '1763715600'},
            {
              'id': 8,
              'name': 'b.json',
              'type': 'file',
              'revised_at': 1763715600000,
            },
          ]),
        ),
        200,
      );
    });

    final storage = await _storageFor(client);
    final notes = await storage.listRemoteMemos();

    expect(notes.firstWhere((n) => n.name == 'a.json').updatedAt,
        _fromSeconds(1763715600));
    expect(notes.firstWhere((n) => n.name == 'b.json').updatedAt,
        _fromSeconds(1763715600));
  });
}
