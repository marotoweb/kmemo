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

  // Customização visual e anexos locais
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get bgImageIndex => integer().withDefault(const Constant(-1))();
  TextColumn get imageAttachments => text().withDefault(const Constant('[]'))();
  TextColumn get audioAttachments => text().withDefault(const Constant('[]'))();
  TextColumn get linkAttachments => text().withDefault(const Constant('[]'))();

  // Controlo de Arquivo e Eliminação lógica
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

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

@DriftDatabase(tables: [Memos, Blocks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4; // Incrementado para acomodar isDeleted

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
    },
  );

  // Listagem com ordenação decrescente
  Stream<List<Memo>> watchActiveMemos() {
    return (select(memos)
          ..where((t) => t.isArchived.equals(false) & t.isDeleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

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

  Future<void> saveMemoWithBlocks(Memo memo, List<Block> memoBlocks) async {
    await transaction(() async {
      await into(memos).insert(memo, mode: InsertMode.insertOrReplace);
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

  Future<void> updateMemoArchiveStatus(String memoUuid, bool archived) async {
    await (update(memos)..where((t) => t.uuid.equals(memoUuid))).write(
      MemosCompanion(isArchived: Value(archived)),
    );
  }

  Future<void> updateMemoDeleteStatus(String memoUuid, bool deleted) async {
    await (update(memos)..where((t) => t.uuid.equals(memoUuid))).write(
      MemosCompanion(isDeleted: Value(deleted)),
    );
  }

  Future<void> deleteMemoCascading(String memoUuid) async {
    await transaction(() async {
      await (delete(blocks)..where((t) => t.memoUuid.equals(memoUuid))).go();
      await (delete(memos)..where((t) => t.uuid.equals(memoUuid))).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kmemo.sqlite'));
    return NativeDatabase(file);
  });
}
