// test/memo_serialization_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/services/encryption_service.dart';
import 'package:kmemo/services/memo_serialization.dart';

Memo _memo({required DateTime createdAt, required DateTime updatedAt}) => Memo(
  uuid: '11111111-1111-1111-1111-111111111111',
  title: 'Nota',
  createdAt: createdAt,
  updatedAt: updatedAt,
  isSynced: false,
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

void main() {
  setUp(EncryptionService.instance.disable);
  tearDown(EncryptionService.instance.disable);

  test('timestamps are written as UTC instants', () {
    // A local DateTime in any timezone must serialise with the offset applied,
    // so another device (or a server) reads the same instant.
    final local = DateTime(2026, 11, 15, 10, 30);
    final payload = buildRemoteMemoPayload(
      _memo(createdAt: local, updatedAt: local),
      const [],
    );

    final memo = payload['memo'] as Map<String, dynamic>;
    expect(memo['updatedAt'], endsWith('Z'));
    expect(memo['createdAt'], endsWith('Z'));
    expect(DateTime.parse(memo['updatedAt'] as String), local.toUtc());
  });

  test('a note round-trips through the payload without losing the instant', () {
    final updatedAt = DateTime.utc(2026, 11, 15, 10, 30, 45, 123);
    final memo = _memo(
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: updatedAt,
    );

    final bytes = encodeRemoteMemo(memo, const [], encryptionRequired: false);
    final decoded = decodeRemoteMemo(bytes)!;

    expect(decoded.memo.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
    expect(decoded.memo.updatedAt.isUtc, isTrue);
    // The payload timestamp is the remote revision this device now knows.
    expect(decoded.memo.remoteUpdatedAt, isNotNull);
    expect(decoded.memo.remoteUpdatedAt!.isAtSameMomentAs(updatedAt), isTrue);
  });

  test('legacy payloads without an offset are still accepted', () {
    // Notes written before 0.2.2 serialised a local DateTime without `Z`.
    final legacy = jsonEncode({
      'memo': {
        'uuid': '11111111-1111-1111-1111-111111111111',
        'title': 'Antiga',
        'createdAt': '2026-01-02T03:04:05.000',
        'updatedAt': '2026-01-02T03:04:06.000',
        'colorIndex': 0,
        'bgImageIndex': -1,
      },
      'blocks': const [],
    });

    final decoded = decodeRemoteMemo(utf8.encode(legacy));

    expect(decoded, isNotNull);
    expect(decoded!.memo.title, 'Antiga');
    expect(decoded.memo.updatedAt.isUtc, isTrue);
  });
}
