// lib/models/block.dart

import '../../database/database.dart';

extension BlockExtension on Block {
  Block copyWith({
    int? id,
    String? uuid,
    String? memoUuid,
    BlockType? type,
    Map<String, dynamic>? content,
    int? sortOrder,
    bool? isDeleted,
  }) {
    return Block(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      memoUuid: memoUuid ?? this.memoUuid,
      type: type ?? this.type,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
