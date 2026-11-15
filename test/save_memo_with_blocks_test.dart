// test/save_memo_with_blocks_test.dart

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';

Memo _memo(String uuid) => Memo(
  uuid: uuid,
  title: 'Nota',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  isSynced: true,
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

/// A block as it arrives from a remote payload: uuid preserved, no local id.
Block _payloadBlock(String memoUuid, String text) => Block(
  id: 0,
  uuid: '$memoUuid-block-0',
  memoUuid: memoUuid,
  type: BlockType.text,
  content: {'text': text},
  sortOrder: 0,
  isDeleted: false,
);

void main() {
  test(
    'a downloaded note replaces its blocks instead of duplicating them',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      const uuid = 'memo-1';

      await db.saveMemoWithBlocks(_memo(uuid), [_payloadBlock(uuid, 'local')]);
      expect((await db.getBlocksForMemo(uuid)).length, 1);

      // The pull downloads the note again after the remote changed.
      await db.saveMemoWithBlocks(_memo(uuid), [
        _payloadBlock(uuid, 'remoto'),
      ], replaceBlocks: true);

      final blocks = await db.getBlocksForMemo(uuid);
      expect(blocks.length, 1);
      expect(blocks.single.content['text'], 'remoto');

      // A remote deletion of a block must remove it locally too.
      await db.saveMemoWithBlocks(_memo(uuid), const [], replaceBlocks: true);
      expect(await db.getBlocksForMemo(uuid), isEmpty);
    },
  );
}
