// lib/ui/sync_date_format.dart

import 'package:flutter/widgets.dart';
import 'package:kmemo/l10n/app_localizations.dart';

/// Absolute date and time of a sync, for the places where the exact moment
/// matters (the home card shown while pulling the list).
///
/// Day/month/year in every language, like the settings screen already does for
/// syncs older than a day.
String formatSyncAbsolute(DateTime last) =>
    '${last.day}/${last.month}/${last.year} '
    '${last.hour.toString().padLeft(2, '0')}:'
    '${last.minute.toString().padLeft(2, '0')}';

/// Last sync in the form the settings screen uses: relative under a day and
/// absolute after that, so the same note shows the same text in both places.
String formatSyncDate(BuildContext context, DateTime? last) {
  if (last == null) return AppLocalizations.of(context)!.lastSyncNever;
  final diff = DateTime.now().difference(last);
  final l10n = AppLocalizations.of(context)!;
  if (diff.inMinutes < 1) return l10n.lastSyncJustNow;
  if (diff.inHours < 1) return l10n.lastSyncMinutesAgo('${diff.inMinutes}');
  if (diff.inDays < 1) return l10n.lastSyncHoursAgo('${diff.inHours}');
  return formatSyncAbsolute(last);
}
