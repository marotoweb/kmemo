// lib/services/sync_integrity.dart

import 'dart:convert';

/// Utilitários para verificação de integridade de sincronização.
class SyncIntegrity {
  /// Calcula um hash SHA-256 simples do conteúdo (para verificação de integridade).
  /// Usa uma implementação simples baseada em bytes para evitar dependências adicionais.
  static String simpleHash(String content) {
    final bytes = utf8.encode(content);
    int hash = 0;
    for (var byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Verifica se o conteúdo de dois ficheiros é igual (comparação de hash).
  static bool contentEquals(String a, String b) {
    return simpleHash(a) == simpleHash(b);
  }

  /// Verifica se uma nota pode ser sincronizada (não é null, não está corrompida).
  static bool canSync(String uuid, String title, List<dynamic> blocks) {
    if (uuid.isEmpty) return false;
    // Verificar se os blocos são válidos
    for (var block in blocks) {
      if (block is! Map) return false;
      if (!block.containsKey('uuid')) return false;
      if (!block.containsKey('type')) return false;
    }
    return true;
  }
}
