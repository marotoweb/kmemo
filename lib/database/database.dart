// lib/database/database.dart

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

part 'database.g.dart';

// O Enum original do projeto para os tipos de blocos
enum BlockType { text, checklist, kanban, database, calendar, custom }

// Conversor para serializar o enum na base de dados SQLite como String
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

// Conversor para serializar o Map de conteúdo dinâmico como String JSON
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

// Definição da tabela Memos (Notas)
class Memos extends Table {
  TextColumn get uuid => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteFileId => text().nullable()();

  @override
  Set<Column> get primaryKey => {uuid}; // UUID como Chave Primária nativa
}

// Definição da tabela Blocks (Blocos compostos)
class Blocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();

  // Chave estrangeira ligada ao Memo com eliminação em cascata automática
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
  int get schemaVersion => 1;

  // -------------------------------------------------------------------------
  // Consultas e Operações Reativas para o MemoProvider
  // -------------------------------------------------------------------------

  // Stream reativo de Memos ordenados por atualização para a HomeScreen
  Stream<List<Memo>> watchAllMemos() {
    return (select(memos)..orderBy([
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  // Obter a lista de blocos ativos de uma nota específica ordenados por posição
  Future<List<Block>> getBlocksForMemo(String memoUuid) {
    return (select(blocks)
          ..where(
            (t) => t.memoUuid.equals(memoUuid) & t.isDeleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  // Inserção ou atualização atómica (Transação) de uma nota e os seus blocos
  Future<void> saveMemoWithBlocks(Memo memo, List<Block> memoBlocks) async {
    await transaction(() async {
      await into(memos).insert(memo, mode: InsertMode.insertOrReplace);
      for (var block in memoBlocks) {
        await into(blocks).insert(block, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // Eliminar uma nota (a restrição da FK encarrega-se dos blocos no SQLite)
  Future<void> deleteMemoCascading(String memoUuid) async {
    await (delete(memos)..where((t) => t.uuid.equals(memoUuid))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kmemo.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
