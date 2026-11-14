// test/webdav_storage_test.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/services/encryption_service.dart';
import 'package:kmemo/services/webdav_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory WebDAV server: MKCOL, PUT, GET, DELETE and PROPFIND.
class _FakeServer {
  final Map<String, List<int>> files = {};
  final Set<String> collections = {};
  final List<String> requests = [];
  bool requireAuth = true;
  String user = 'maria';
  String password = 'secret';

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');

    if (requireAuth) {
      final auth = request.headers['Authorization'] ?? '';
      final expected = 'Basic ${base64Encode(utf8.encode('$user:$password'))}';
      if (auth != expected) return http.Response('unauthorized', 401);
    }

    final path = request.url.path;
    switch (request.method) {
      case 'MKCOL':
        collections.add(path);
        return http.Response('', 201);
      case 'PUT':
        files[path] = request.bodyBytes;
        return http.Response('', 201);
      case 'GET':
        final body = files[path];
        if (body == null) return http.Response('not found', 404);
        return http.Response.bytes(body, 200);
      case 'DELETE':
        if (files.remove(path) == null) return http.Response('', 404);
        return http.Response('', 204);
      case 'PROPFIND':
        final depth = request.headers['Depth'] ?? '1';
        final folder = path.endsWith('/') ? path : '$path/';
        final entries = <String>[];
        entries.add('''<d:response>
  <d:href>$folder</d:href>
  <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''');
        if (depth != '0') {
          for (final file in files.keys) {
            if (!file.startsWith(folder) || file == folder) continue;
            final name = file.substring(folder.length);
            if (name.contains('/')) continue;
            entries.add('''<d:response>
  <d:href>$file</d:href>
  <d:propstat><d:prop><d:resourcetype/>
  <d:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</d:getlastmodified></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''');
          }
        }
        return http.Response(
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<d:multistatus xmlns:d="DAV:">${entries.join()}</d:multistatus>',
          207,
        );
      default:
        return http.Response('method not allowed', 405);
    }
  }
}

Memo _memo({String uuid = '11111111-1111-1111-1111-111111111111'}) {
  return Memo(
    uuid: uuid,
    title: 'Shopping list',
    createdAt: DateTime.utc(2026, 1, 2, 10),
    updatedAt: DateTime.utc(2026, 1, 3, 11),
    isSynced: false,
    colorIndex: 4,
    bgImageIndex: -1,
    imageAttachments: '[]',
    audioAttachments: '[]',
    linkAttachments: '[]',
    isArchived: false,
    isDeleted: false,
    isPinned: true,
    sortIndex: 0,
  );
}

List<Block> _blocks() => [
  Block(
    id: 0,
    uuid: 'block-1',
    memoUuid: '11111111-1111-1111-1111-111111111111',
    type: BlockType.checklist,
    content: const {'text': 'Coffee', 'checked': false},
    sortOrder: 0,
    isDeleted: false,
  ),
];

Future<WebDAVStorage> _configured(
  _FakeServer server, {
  bool encryption = false,
  String? passphrase,
}) async {
  final storage = WebDAVStorage(
    client: MockClient(server.handle),
  );
  await storage.configure(
    baseUrl: 'https://cloud.example.com/dav/',
    username: server.user,
    password: server.password,
    folder: 'kmemo/notes',
    encryptionEnabled: encryption,
    passphrase: passphrase,
  );
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    EncryptionService.instance.disable();
  });

  group('normalizeWebdavUrl', () {
    test('assumes https when the scheme is missing', () {
      expect(
        normalizeWebdavUrl('cloud.example.com/dav'),
        'https://cloud.example.com/dav/',
      );
      expect(
        normalizeWebdavUrl('  nas.local:5006  '),
        'https://nas.local:5006/',
      );
    });

    test('keeps an explicit scheme (http included)', () {
      expect(
        normalizeWebdavUrl('http://192.168.1.10:5005'),
        'http://192.168.1.10:5005/',
      );
      expect(
        normalizeWebdavUrl('https://cloud.example.com/dav'),
        'https://cloud.example.com/dav/',
      );
    });

    test('an empty value stays empty', () {
      expect(normalizeWebdavUrl('   '), '');
    });
  });

  test('configure accepts a URL without scheme and normalises it', () async {
    final server = _FakeServer();
    final storage = WebDAVStorage(client: MockClient(server.handle));
    await storage.configure(
      baseUrl: 'cloud.example.com/dav',
      username: server.user,
      password: server.password,
      folder: 'kmemo/notes',
      encryptionEnabled: false,
    );

    expect(storage.baseUrl, 'https://cloud.example.com/dav/');

    await storage.uploadMemo(_memo(), _blocks());
    expect(
      server.requests,
      contains(
        'PUT /dav/kmemo/notes/11111111-1111-1111-1111-111111111111.json',
      ),
    );
  });

  test('configure marks the storage as ready and keeps the password', () async {
    final server = _FakeServer();
    final storage = await _configured(server);

    expect(storage.isConfigured, isTrue);
    expect(storage.baseUrl, 'https://cloud.example.com/dav/');
    expect(storage.username, 'maria');
    expect(storage.hasPassword, isTrue);
    expect(storage.folder, 'kmemo/notes');
    expect(storage.supportsVersionHistory, isFalse);
  });

  test('upload creates the folders and PUTs the note payload', () async {
    final server = _FakeServer();
    final storage = await _configured(server);

    final id = await storage.uploadMemo(_memo(), _blocks());

    expect(id, 'kmemo/notes/11111111-1111-1111-1111-111111111111.json');
    expect(
      server.requests,
      containsAllInOrder([
        'MKCOL /dav/kmemo/',
        'MKCOL /dav/kmemo/notes/',
        'PUT /dav/kmemo/notes/11111111-1111-1111-1111-111111111111.json',
      ]),
    );

    final body = utf8.decode(
      server.files['/dav/kmemo/notes/11111111-1111-1111-1111-111111111111.json']!,
    );
    final payload = jsonDecode(body) as Map<String, dynamic>;
    expect((payload['memo'] as Map)['title'], 'Shopping list');
    expect((payload['memo'] as Map)['isPinned'], isTrue);
    expect((payload['blocks'] as List).first['type'], 'checklist');
  });

  test('listRemoteMemos parses PROPFIND and ignores folders and other files',
      () async {
    final server = _FakeServer();
    final storage = await _configured(server);
    await storage.uploadMemo(_memo(), _blocks());
    server.files['/dav/kmemo/notes/readme.txt'] = utf8.encode('not a note');

    final notes = await storage.listRemoteMemos();

    expect(notes, hasLength(1));
    expect(notes.single.name, '11111111-1111-1111-1111-111111111111.json');
    expect(
      notes.single.remoteFileId,
      'kmemo/notes/11111111-1111-1111-1111-111111111111.json',
    );
    expect(notes.single.updatedAt.year, 2015);
  });

  test('download returns the note and its blocks', () async {
    final server = _FakeServer();
    final storage = await _configured(server);
    final id = await storage.uploadMemo(_memo(), _blocks());

    final downloaded = await storage.downloadMemo(id!);

    expect(downloaded, isNotNull);
    expect(downloaded!.memo.title, 'Shopping list');
    expect(downloaded.memo.colorIndex, 4);
    expect(downloaded.blocks.single.type, BlockType.checklist);
    expect(downloaded.blocks.single.content['text'], 'Coffee');
  });

  test('delete removes the remote file', () async {
    final server = _FakeServer();
    final storage = await _configured(server);
    final id = await storage.uploadMemo(_memo(), _blocks());

    await storage.deleteMemo(id!);

    expect(server.files, isEmpty);
    expect(server.requests.last, startsWith('DELETE /dav/kmemo/notes/'));
  });

  test('upload refuses to write plain text when encryption is on', () async {
    final server = _FakeServer();
    final storage = await _configured(server, encryption: true);

    expect(storage.encryptionEnabled, isTrue);
    expect(EncryptionService.instance.isEnabled, isFalse);

    await expectLater(
      storage.uploadMemo(_memo(), _blocks()),
      throwsA(isA<StateError>()),
    );
    expect(server.files, isEmpty);
  });

  test('encrypted notes round-trip and are unreadable on the server', () async {
    final server = _FakeServer();
    final storage = await _configured(
      server,
      encryption: true,
      passphrase: 'correct horse battery staple',
    );

    final id = await storage.uploadMemo(_memo(), _blocks());
    final raw = utf8.decode(
      server.files['/dav/kmemo/notes/11111111-1111-1111-1111-111111111111.json']!,
    );

    expect(raw, isNot(contains('Shopping list')));
    expect(raw, contains(':')); // iv:ciphertext

    final downloaded = await storage.downloadMemo(id!);
    expect(downloaded!.memo.title, 'Shopping list');
  });

  test('wrong passphrase fails to decrypt instead of returning garbage',
      () async {
    final server = _FakeServer();
    final writer = await _configured(
      server,
      encryption: true,
      passphrase: 'first passphrase',
    );
    final id = await writer.uploadMemo(_memo(), _blocks());

    final read = WebDAVStorage(client: MockClient(server.handle));
    await read.configure(
      baseUrl: 'https://cloud.example.com/dav/',
      username: server.user,
      password: server.password,
      folder: 'kmemo/notes',
      encryptionEnabled: true,
    );
    // The configuration loaded the right passphrase; force a wrong one, as a
    // user typing a different passphrase would.
    EncryptionService.instance.enable('another passphrase');

    expect(await read.downloadMemo(id!), isNull);
  });

  test('testConnectionWith reports bad credentials without saving', () async {
    final server = _FakeServer();
    final storage = await _configured(server);

    await expectLater(
      storage.testConnectionWith(
        baseUrl: 'https://cloud.example.com/dav/',
        username: server.user,
        password: 'wrong',
      ),
      throwsA(isA<Exception>()),
    );

    await storage.testConnectionWith(
      baseUrl: 'https://cloud.example.com/dav/',
      username: server.user,
      password: server.password,
    );
  });
}
