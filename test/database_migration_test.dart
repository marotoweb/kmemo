// test/database_migration_test.dart

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Creates a database file with the schema shipped in 0.2.1 (v5), which has no
/// remote sync bookkeeping columns.
void _createV5Database(
  File file,
  List<({String uuid, DateTime updatedAt, bool isSynced})> memos,
) {
  final raw = sqlite3.open(file.path);
  raw.execute('''
    CREATE TABLE memos (
      uuid TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 0,
      remote_file_id TEXT,
      color_index INTEGER NOT NULL DEFAULT 0,
      bg_image_index INTEGER NOT NULL DEFAULT -1,
      image_attachments TEXT NOT NULL DEFAULT '[]',
      audio_attachments TEXT NOT NULL DEFAULT '[]',
      link_attachments TEXT NOT NULL DEFAULT '[]',
      is_archived INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      sort_index INTEGER NOT NULL DEFAULT 0
    );
  ''');
  raw.execute('''
    CREATE TABLE blocks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL,
      memo_uuid TEXT NOT NULL REFERENCES memos (uuid) ON DELETE CASCADE,
      type TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '{}',
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0
    );
  ''');
  for (final memo in memos) {
    final seconds = memo.updatedAt.millisecondsSinceEpoch ~/ 1000;
    raw.execute(
      'INSERT INTO memos (uuid, title, created_at, updated_at, is_synced) '
      'VALUES (?, ?, ?, ?, ?)',
      [memo.uuid, memo.uuid, seconds, seconds, memo.isSynced ? 1 : 0],
    );
  }
  raw.execute('PRAGMA user_version = 5');
  raw.close();
}

void main() {
  test(
    'upgrading from v5 adds the sync columns and seeds synced notes',
    () async {
      final dir = await Directory.systemTemp.createTemp('kmemo_migration');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'kmemo.sqlite'));

      final syncedAt = DateTime.utc(2026, 11, 1, 12);
      final dirtyAt = DateTime.utc(2026, 11, 2, 8);
      _createV5Database(file, [
        (uuid: 'synced', updatedAt: syncedAt, isSynced: true),
        (uuid: 'dirty', updatedAt: dirtyAt, isSynced: false),
      ]);

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final rows = await db.select(db.memos).get();
      final synced = rows.firstWhere((m) => m.uuid == 'synced');
      final dirty = rows.firstWhere((m) => m.uuid == 'dirty');

      // A synced note matches the remote copy it was uploaded with, so the
      // remote timestamp starts from the local one. The revision stays unknown
      // and is adopted from the next listing.
      expect(synced.remoteUpdatedAt, isNotNull);
      expect(synced.remoteUpdatedAt!.isAtSameMomentAs(syncedAt), isTrue);
      expect(synced.remoteRevision, isNull);

      // A note with local changes never agreed with the remote: nothing to seed.
      expect(dirty.remoteUpdatedAt, isNull);
      expect(dirty.remoteRevision, isNull);
    },
  );
}
