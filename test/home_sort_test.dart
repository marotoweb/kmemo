// test/home_sort_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/models/home_sort.dart';

Memo _memo({
  required String uuid,
  required DateTime createdAt,
  required DateTime updatedAt,
  bool isPinned = false,
  int sortIndex = 0,
}) {
  return Memo(
    uuid: uuid,
    title: uuid,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isSynced: true,
    colorIndex: 0,
    bgImageIndex: -1,
    imageAttachments: '[]',
    audioAttachments: '[]',
    linkAttachments: '[]',
    isArchived: false,
    isDeleted: false,
    isPinned: isPinned,
    sortIndex: sortIndex,
  );
}

void main() {
  final base = DateTime.utc(2026, 1, 1);

  final older = _memo(
    uuid: 'older',
    createdAt: base,
    updatedAt: base,
    sortIndex: 2,
  );
  final newer = _memo(
    uuid: 'newer',
    createdAt: base.add(const Duration(days: 1)),
    updatedAt: base.add(const Duration(days: 1)),
    sortIndex: 0,
  );
  final pinnedOld = _memo(
    uuid: 'pinnedOld',
    createdAt: base,
    updatedAt: base,
    isPinned: true,
    sortIndex: 1,
  );
  final pinnedNew = _memo(
    uuid: 'pinnedNew',
    createdAt: base.add(const Duration(days: 2)),
    updatedAt: base.add(const Duration(days: 2)),
    isPinned: true,
    sortIndex: 3,
  );

  List<String> sortedIds(List<Memo> memos, HomeSortMode mode, bool asc) {
    final list = List<Memo>.from(memos)
      ..sort((a, b) => compareMemosForSort(a, b, mode, asc));
    return list.map((m) => m.uuid).toList();
  }

  group('compareMemosForSort', () {
    test('pinned notes always come first', () {
      final result = sortedIds(
        [older, newer, pinnedOld, pinnedNew],
        HomeSortMode.updated,
        false,
      );
      expect(result.sublist(0, 2), ['pinnedNew', 'pinnedOld']);
      expect(result.sublist(2), ['newer', 'older']);
    });

    test('updated mode sorts by last modification', () {
      expect(
        sortedIds([older, newer], HomeSortMode.updated, false),
        ['newer', 'older'],
      );
      expect(
        sortedIds([older, newer], HomeSortMode.updated, true),
        ['older', 'newer'],
      );
    });

    test('created mode sorts by creation date', () {
      expect(
        sortedIds([older, newer], HomeSortMode.created, false),
        ['newer', 'older'],
      );
      expect(
        sortedIds([older, newer], HomeSortMode.created, true),
        ['older', 'newer'],
      );
    });

    test('custom mode uses sortIndex ascending', () {
      expect(
        sortedIds([older, newer, pinnedOld, pinnedNew], HomeSortMode.custom, false),
        ['pinnedOld', 'pinnedNew', 'newer', 'older'],
      );
    });

    test('equal sortIndex falls back to most recently updated', () {
      final a = _memo(
        uuid: 'a',
        createdAt: base,
        updatedAt: base,
        sortIndex: 5,
      );
      final b = _memo(
        uuid: 'b',
        createdAt: base,
        updatedAt: base.add(const Duration(hours: 1)),
        sortIndex: 5,
      );
      expect(
        sortedIds([a, b], HomeSortMode.custom, false),
        ['b', 'a'],
      );
    });
  });
}
