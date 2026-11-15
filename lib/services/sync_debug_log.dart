// lib/services/sync_debug_log.dart

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Small log of what the sync decided, written to the app data folder.
///
/// `debugPrint` is silenced in release builds (a logcat is readable by other
/// tools), so a user with only the AppImage or the APK had no way to tell why a
/// note did not leave the device. This file keeps the sync decisions — counts,
/// which note was uploaded/downloaded/refused and why — and nothing else: no
/// note content, no title, no credential.
///
/// The file is capped: it is deleted before it grows past [_maxBytes], so a
/// long-running install cannot fill the disk.
class SyncDebugLog {
  static const String fileName = 'sync.log';
  static const int _maxBytes = 512 * 1024;

  /// Serialises the writes.
  ///
  /// The sync logs from several places without awaiting, and every line used to
  /// open, append and close the file on its own: concurrent appends lost lines
  /// and glued two messages together (`...90371104 downloaded from WebDAV`),
  /// which made the log hide the very decision being investigated.
  static Future<void> _queue = Future<void>.value();

  /// Never logs a note's content or any credential.
  static Future<void> log(String message) {
    final line = '${DateTime.now().toUtc().toIso8601String()} $message\n';
    final next = _queue.then((_) => _writeLine(line));
    _queue = next;
    return next;
  }

  static Future<void> _writeLine(String line) async {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      if (await file.exists() && await file.length() > _maxBytes) {
        await file.delete();
      }
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break the sync.
    }
  }

  static Future<String> read() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, fileName));
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<String> path() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, fileName);
  }
}
