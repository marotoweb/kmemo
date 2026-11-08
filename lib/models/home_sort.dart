// lib/models/home_sort.dart

import '../database/database.dart';

/// Sort modes available on the home screen.
enum HomeSortMode {
  /// Most recently updated first (default, historical behavior).
  updated,

  /// Most recently created first.
  created,

  /// Manual order defined by the user (drag & drop).
  custom,
}

/// SharedPreferences keys (also read by [WidgetService]).
const String kHomeSortModeKey = 'home_sort_mode';
const String kHomeSortAscendingKey = 'home_sort_ascending';
const String kHomeCustomOrderInitializedKey = 'home_custom_order_initialized';

/// Parses the persisted sort mode name, falling back to [HomeSortMode.updated].
HomeSortMode homeSortModeFromName(String? name) {
  return HomeSortMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => HomeSortMode.updated,
  );
}

/// Single ordering rule shared by the home screen, the provider and the
/// native widget: pinned notes first, then the selected sort mode.
///
/// [ascending] only applies to the date modes; the custom order is always
/// stored ascending by [Memo.sortIndex].
int compareMemosForSort(Memo a, Memo b, HomeSortMode mode, bool ascending) {
  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

  final int byMode = switch (mode) {
    HomeSortMode.custom => a.sortIndex.compareTo(b.sortIndex),
    HomeSortMode.updated =>
      ascending
          ? a.updatedAt.compareTo(b.updatedAt)
          : b.updatedAt.compareTo(a.updatedAt),
    HomeSortMode.created =>
      ascending
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt),
  };
  if (byMode != 0) return byMode;

  // Stable tie-breaker: most recently updated first.
  return b.updatedAt.compareTo(a.updatedAt);
}
