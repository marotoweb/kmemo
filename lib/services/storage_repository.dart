// lib/services/storage_repository.dart

import '../database/database.dart';

/// Resultado de listagem remota de notas.
class RemoteMemoInfo {
  final String remoteFileId;
  final String name;
  final DateTime updatedAt;

  RemoteMemoInfo({
    required this.remoteFileId,
    required this.name,
    required this.updatedAt,
  });
}

/// Nota completa baixada do armazenamento remoto.
class RemoteMemo {
  final Memo memo;
  final List<Block> blocks;

  RemoteMemo({
    required this.memo,
    required this.blocks,
  });
}

/// Abstração do armazenamento remoto de notas.
///
/// O kMemo permanece offline-first: o SQLite local é a única fonte de verdade.
/// Esta camada apenas espelha as alterações para um destino remoto (kDrive,
/// WebDAV, etc.) de forma assíncrona, sem bloquear a UI.
abstract class StorageRepository {
  /// Inicializa o repositório (carrega configuração guardada, etc.).
  Future<void> init();

  /// Indica se o repositório está configurado e pronto para sincronizar.
  bool get isConfigured;

  /// Nome legível do tipo de armazenamento (ex. "kDrive", "WebDAV").
  String get storageName;

  /// Guards used by the caller (MemoProvider) to throttle sync frequency.
  bool get syncAllowed => true;

  /// Marks a completed sync cycle (used for rate-limit throttling).
  void markSyncedNow() {}

  /// Envia uma nota para o armazenamento remoto e retorna o ID remoto
  /// criado (ou null se não disponível).
  Future<String?> uploadMemo(Memo memo, List<Block> blocks);

  /// Remove uma nota do armazenamento remoto.
  Future<void> deleteMemo(String remoteFileId);

  /// Lista as notas disponíveis remotamente.
  Future<List<RemoteMemoInfo>> listRemoteMemos();

  /// Baixa uma nota completa do armazenamento remoto.
  /// Retorna null se a nota não puder ser desencriptada (passphrase errada ou dados corrompidos).
  Future<RemoteMemo?> downloadMemo(String remoteFileId);

  /// Executes full sync (push + pull). Subclasses may override or ignore.
  Future<void> sync();
}
