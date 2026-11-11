// lib/services/widget_debug_log.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Small debug-only log shared by the Dart and Kotlin widget code.
///
/// The native widget runs in the launcher, so its logs are not visible without
/// ADB. This file lets the Settings screen read/copy the recent widget events
/// when the device has no wireless debugging connection.
class WidgetDebugLog {
  static const String fileName = 'widget_debug.log';
  static const int _maxBytes = 512 * 1024;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<void> log(String message) async {
    if (!kDebugMode) return;
    try {
      final file = await _file();
      if (await file.exists() && await file.length() > _maxBytes) {
        await file.delete();
      }
      final line =
          '${DateTime.now().toIso8601String()} [dart] $message\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break the widget update path.
    }
  }

  static Future<String> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Ignore.
    }
  }
}
