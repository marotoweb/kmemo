// lib/models/block.dart
import 'package:drift/drift.dart';
import 'package:kmemo/database/database.dart'; // Importa o enum BlockType do ficheiro central

class Blocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();

  // Chave estrangeira explícita ligando ao Memo correspondente
  TextColumn get memoUuid =>
      text().references(Memos, #uuid, onDelete: KeyAction.cascade)();

  TextColumn get type => text().map(const BlockTypeConverter())();
  TextColumn get content =>
      text().map(const MapConverter()).withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}
