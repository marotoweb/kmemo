// lib/database/database.dart

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Memos extends Table {
  TextColumn get uuid => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteFileId => text().nullable()();

  // Sync bookkeeping: the remote copy this device last agreed with.
  //
  // `remoteUpdatedAt` is the `memo.updatedAt` of the payload that was last
  // uploaded or downloaded, so a remote edit can be told apart from a
  // re-upload of the same content. `remoteRevision` is the remote file's
  // modified time from the last listing, which detects a remote change
  // without downloading the note. Both are local-only and never serialised.
  DateTimeColumn get remoteUpdatedAt => dateTime().nullable()();
  DateTimeColumn get remoteRevision => dateTime().nullable()();

  // Visual customization and local attachments
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get bgImageIndex => integer().withDefault(const Constant(-1))();
  TextColumn get imageAttachments => text().withDefault(const Constant('[]'))();
  TextColumn get audioAttachments => text().withDefault(const Constant('[]'))();
  TextColumn get linkAttachments => text().withDefault(const Constant('[]'))();

  // Archive control and logical deletion
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  // Home ordering: pinned notes always come first; sortIndex is the manual
  // position used by the "custom order" sort mode (local to the device).
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {uuid};
}

enum BlockType { text, checklist }

class BlockTypeConverter extends TypeConverter<BlockType, String> {
  const BlockTypeConverter();

  @override
  BlockType fromSql(String fromDb) {
    return BlockType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => BlockType.text,
    );
  }

  @override
  String toSql(BlockType value) => value.name;
}

class MapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const MapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    try {
      return jsonDecode(fromDb) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

class Blocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get memoUuid =>
      text().references(Memos, #uuid, onDelete: KeyAction.cascade)();
  TextColumn get type => text().map(const BlockTypeConverter())();
  TextColumn get content =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// Notes that were permanently deleted on this device.
///
/// The remote storage is a folder of JSON files, so removing a file is an
/// invisible event for any device that still holds that note: the other device
/// sees "no remote copy", uploads its own version and the note comes back. The
/// deletion is therefore published as a tombstone payload under the same file
/// name, and this table is what keeps it published. The row outlives the note
/// (the memo is deleted), so every later sync still knows the uuid was deleted
/// on purpose and never downloads it again.
class SyncTombstones extends Table {
  TextColumn get uuid => text()();

  /// When the note was permanently deleted (UTC).
  DateTimeColumn get deletedAt => dateTime()();

  /// Remote path of the file that must carry the tombstone. Local-only.
  TextColumn get remoteFileId => text().nullable()();

  /// Remote modified time of the tombstone file after it was published. A
  /// different value means another device wrote to that path again (an old
  /// client re-uploading the note), so the tombstone is published once more.
  DateTimeColumn get remoteRevision => dateTime().nullable()();

  /// Whether the backend already accepted the tombstone.
  BoolColumn get isUploaded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DriftDatabase(tables: [Memos, Blocks, SyncTombstones])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Database backed by the given executor, used by tests (for example an
  /// in-memory `NativeDatabase.memory()`).
  AppDatabase.forTesting(super.e);

  @override
  // v6 adds the remote sync bookkeeping columns; v7 adds the tombstones that
  // make a permanent deletion propagate to the other devices.
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(memos, memos.colorIndex);
        await m.addColumn(memos, memos.bgImageIndex);
        await m.addColumn(memos, memos.imageAttachments);
        await m.addColumn(memos, memos.audioAttachments);
        await m.addColumn(memos, memos.linkAttachments);
      }
      if (from < 3) {
        await m.addColumn(memos, memos.isArchived);
      }
      if (from < 4) {
        await m.addColumn(memos, memos.isDeleted);
      }
      if (from < 5) {
        await m.addColumn(memos, memos.isPinned);
        await m.addColumn(memos, memos.sortIndex);
      }
      if (from < 7) {
        await m.createTable(syncTombstones);
      }
      if (from < 6) {
        await m.addColumn(memos, memos.remoteUpdatedAt);
        await m.addColumn(memos, memos.remoteRevision);
        // A note already marked as synced matches the remote copy it was
        // uploaded with, so seed its remote timestamp from the local one.
        // This keeps a remote edit detectable after the upgrade. The revision
        // stays unknown and is adopted from the next listing without
        // downloading the note.
        await customStatement(
          'UPDATE memos SET remote_updated_at = updated_at WHERE is_synced = 1',
        );
      }
    },
  );

  // Listing with descending order
  Stream<List<Memo>> watchAllMemos() {
    return (select(memos)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<List<Block>> getBlocksForMemo(String memoUuid) {
    return (select(blocks)
          ..where(
            (t) => t.memoUuid.equals(memoUuid) & t.isDeleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// Loads every non-deleted block in one query. Used to warm the preview
  /// cache so the home cards never query SQLite while scrolling.
  Future<List<Block>> getAllBlocks() {
    return (select(blocks)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// Saves a note and its blocks.
  ///
  /// [replaceBlocks] must be set when [memoBlocks] comes from a remote payload:
  /// those blocks carry their uuid but no local id, and the primary key is the
  /// autoincrement `id`, so inserting them next to the stored rows duplicates
  /// every block (the note text appeared twice after a download). The payload
  /// is the whole note, so the stored block set is replaced instead.
  Future<void> saveMemoWithBlocks(
    Memo memo,
    List<Block> memoBlocks, {
    bool replaceBlocks = false,
  }) async {
    await transaction(() async {
      await into(memos).insert(memo, mode: InsertMode.insertOrReplace);
      if (replaceBlocks) {
        await (delete(blocks)..where((t) => t.memoUuid.equals(memo.uuid))).go();
      }
      for (var block in memoBlocks) {
        if (block.id == 0) {
          await into(blocks).insert(
            BlocksCompanion.insert(
              uuid: block.uuid,
              memoUuid: block.memoUuid,
              type: block.type,
              content: Value(block.content),
              sortOrder: Value(block.sortOrder),
              isDeleted: Value(block.isDeleted),
            ),
            mode: InsertMode.insertOrReplace,
          );
        } else {
          await into(blocks).insert(block, mode: InsertMode.insertOrReplace);
        }
      }
    });
  }

  /// Archives or unarchives a note.
  ///
  /// The archive flag is part of the remote payload, so the note is marked as
  /// not synced and `updatedAt` is refreshed. The timestamp is what tells the
  /// other device that this payload changed: without it the note would be
  /// uploaded with the old timestamp, the other side would compare it with the
  /// one it recorded, answer "nothing to do" and keep the note where it was.
  Future<void> updateMemoArchiveStatus(String memoUuid, bool archived) async {
    await (update(memos)..where((t) => t.uuid.equals(memoUuid))).write(
      MemosCompanion(
        isArchived: Value(archived),
        isSynced: const Value(false),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> deleteMemoCascading(String memoUuid) async {
    await transaction(() async {
      await (delete(blocks)..where((t) => t.memoUuid.equals(memoUuid))).go();
      await (delete(memos)..where((t) => t.uuid.equals(memoUuid))).go();
    });
  }

  /// Every permanent deletion this device still has to publish.
  Future<List<SyncTombstone>> getTombstones() => select(syncTombstones).get();

  /// Records that [uuid] was permanently deleted, replacing any previous row.
  Future<void> recordTombstone({
    required String uuid,
    required DateTime deletedAt,
    String? remoteFileId,
    DateTime? remoteRevision,
    bool isUploaded = false,
  }) {
    return into(syncTombstones).insertOnConflictUpdate(
      SyncTombstonesCompanion.insert(
        uuid: uuid,
        deletedAt: deletedAt,
        remoteFileId: Value(remoteFileId),
        remoteRevision: Value(remoteRevision),
        isUploaded: Value(isUploaded),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // On the desktop the documents folder is the user's home directory
    // ($XDG_DOCUMENTS_DIR is usually unset on Linux), which would leave a
    // kmemo.sqlite next to their files. The app support folder
    // ($XDG_DATA_HOME) is the right place there.
    //
    // Android keeps the documents folder: it is already app-private storage,
    // so changing it would move every existing note.
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      final support = await getApplicationSupportDirectory();
      final file = File(p.join(support.path, 'kmemo.sqlite'));
      if (!await file.exists()) {
        // One-time move from the older location.
        final legacy = File(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'kmemo.sqlite',
          ),
        );
        if (await legacy.exists()) {
          await support.create(recursive: true);
          await legacy.copy(file.path);
          // Keep the old file under a name the app will not open again: a
          // silent copy left behind would look like live data after a rollback.
          try {
            await legacy.rename('${legacy.path}.migrated');
          } catch (_) {
            // A read-only home is not worth failing the start for.
          }
        }
      }
      return NativeDatabase(file);
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kmemo.sqlite'));
    return NativeDatabase(file);
  });
}
