// lib/models/memo.dart
import 'package:drift/drift.dart';

class Memos extends Table {
  TextColumn get uuid => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get remoteFileId => text().nullable()();

  @override
  Set<Column> get primaryKey => {uuid}; // UUID como chave primária real
}
