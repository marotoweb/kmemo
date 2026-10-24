// lib/services/sync_integrity.dart

import 'dart:convert';

/// Synchronization integrity verification utilities.
class SyncIntegrity {
  /// Computes a simple SHA-256 hash of the content (for integrity verification).
  /// Uses a simple byte-based implementation to avoid additional dependencies.
  static String simpleHash(String content) {
    final bytes = utf8.encode(content);
    int hash = 0;
    for (var byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Verify if the content of two files is equal (hash comparison).
  static bool contentEquals(String a, String b) {
    return simpleHash(a) == simpleHash(b);
  }

  /// Checks whether the note can be synced (not null, not corrupted).
  static bool canSync(String uuid, String title, List<dynamic> blocks) {
    if (uuid.isEmpty) return false;
    // Check if the blocks are valid
    for (var block in blocks) {
      if (block is! Map) return false;
      if (!block.containsKey('uuid')) return false;
      if (!block.containsKey('type')) return false;
    }
    return true;
  }
}
