// lib/services/kdrive_storage.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database.dart';
import 'encryption_service.dart';
import 'storage_repository.dart';

const String _apiBase = 'https://api.infomaniak.com';

const String _prefsToken = 'infomaniak_token';
const String _prefsDriveId = 'infomaniak_drive_id';
const String _prefsRemoteFolder = 'infomaniak_remote_folder';
const String _prefsEncryptionEnabled = 'infomaniak_encryption_enabled';
const String _prefsEncryptionPassphrase = 'infomaniak_encryption_passphrase';
const String _prefsLastSync = 'infomaniak_last_sync';

/// Pasta padrão dentro do kDrive onde as notas do kMemo são guardadas.
const String _defaultRemoteFolder = 'kmemo/notes';

/// Tempo mínimo entre sincronizações automáticas (respeita o rate limit de 60 req/min).
const Duration _minSyncInterval = Duration(seconds: 5);

class KDriveStorage extends StorageRepository {
  KDriveStorage({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  String? _token;
  int? _driveId;
  String _remoteFolder = _defaultRemoteFolder;
  bool _encryptionEnabled = false;
  DateTime? _lastSync;

  @override
  bool get isConfigured => _token != null && _driveId != null;

  @override
  String get storageName => 'kDrive';

  /// Drive ID selecionado (null se não configurado).
  int? get driveId => _driveId;

  /// Pasta remota configurada.
  String get remoteFolder => _remoteFolder;

  /// Indica se a encriptação está ativa.
  bool get encryptionEnabled => _encryptionEnabled;

  /// Última data/hora de sincronização completa.
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = await _secureStorage.read(key: _prefsToken);
    _driveId = prefs.getInt(_prefsDriveId);
    _remoteFolder = prefs.getString(_prefsRemoteFolder) ?? _defaultRemoteFolder;
    _encryptionEnabled = prefs.getBool(_prefsEncryptionEnabled) ?? false;

    final lastSyncMs = prefs.getInt(_prefsLastSync);
    if (lastSyncMs != null) {
      _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }

    if (_encryptionEnabled) {
      final passphrase = await _secureStorage.read(
        key: _prefsEncryptionPassphrase,
      );
      if (passphrase != null && passphrase.isNotEmpty) {
        EncryptionService.instance.enable(passphrase);
      }
    }
  }

  /// Define o token OAuth temporariamente para permitir a descoberta de contas
  /// e drives antes da configuração completa.
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _prefsToken, value: token);
  }

  // ------------------------------------------------------------------------
  // Configuração
  // ------------------------------------------------------------------------

  Future<void> configure({
    required String token,
    required int driveId,
    required String driveName,
    String remoteFolder = _defaultRemoteFolder,
    bool encryptionEnabled = false,
    String? encryptionPassphrase,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _token = token;
    _driveId = driveId;
    _remoteFolder = remoteFolder.isEmpty ? _defaultRemoteFolder : remoteFolder;
    _encryptionEnabled = encryptionEnabled;

    await _secureStorage.write(key: _prefsToken, value: token);
    await prefs.setInt(_prefsDriveId, driveId);
    await prefs.setString(_prefsRemoteFolder, _remoteFolder);
    await prefs.setBool(_prefsEncryptionEnabled, encryptionEnabled);

    if (encryptionEnabled && encryptionPassphrase != null) {
      EncryptionService.instance.enable(encryptionPassphrase);
      await _secureStorage.write(
        key: _prefsEncryptionPassphrase,
        value: encryptionPassphrase,
      );
    } else {
      EncryptionService.instance.disable();
      await _secureStorage.delete(key: _prefsEncryptionPassphrase);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _driveId = null;
    _remoteFolder = _defaultRemoteFolder;
    _encryptionEnabled = false;
    _lastSync = null;

    await _secureStorage.delete(key: _prefsToken);
    await _secureStorage.delete(key: _prefsEncryptionPassphrase);
    await prefs.remove(_prefsDriveId);
    await prefs.remove(_prefsRemoteFolder);
    await prefs.remove(_prefsEncryptionEnabled);
    await prefs.remove(_prefsLastSync);
  }

  // ------------------------------------------------------------------------
  // Descoberta de drives (para a página de configuração)
  // ------------------------------------------------------------------------

  /// Lista as contas do utilizador na Infomaniak (necessário para obter o account_id).
  Future<List<Map<String, dynamic>>> listAccounts() async {
    if (_token == null) throw StateError('Token não configurado');
    return await _request<List<Map<String, dynamic>>>(
      uri: Uri.parse('$_apiBase/1/accounts'),
      method: 'GET',
      parser: (data) => (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  /// Lista os drives acessíveis para uma conta.
  Future<List<Map<String, dynamic>>> listDrives(int accountId) async {
    if (_token == null) throw StateError('Token não configurado');
    return await _request<List<Map<String, dynamic>>>(
      uri: Uri.parse('$_apiBase/2/drive?account_id=$accountId'),
      method: 'GET',
      parser: (data) => (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  // ------------------------------------------------------------------------
  // Helpers de requisição com retry e rate limit
  // ------------------------------------------------------------------------

  Map<String, String> _authHeaders() {
    if (_token == null) throw StateError('Token não configurado');
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  Future<T> _request<T>({
    required Uri uri,
    required String method,
    T Function(Map<String, dynamic> data)? parser,
    Map<String, String>? extraHeaders,
    dynamic body,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;
      final headers = <String, String>{..._authHeaders(), if (extraHeaders != null) ...extraHeaders};

      http.StreamedResponse response;
      if (method == 'GET') {
        response = await _client.send(http.Request('GET', uri)..headers.addAll(headers));
      } else if (method == 'POST') {
        final request = http.Request('POST', uri)
          ..headers.addAll(headers);
        if (body is String) {
          request.body = body;
        } else if (body is Map) {
          request.body = jsonEncode(body);
        } else if (body is List<int>) {
          request.bodyBytes = body;
        }
        response = await _client.send(request);
      } else if (method == 'DELETE') {
        response = await _client.send(http.Request('DELETE', uri)..headers.addAll(headers));
      } else {
        throw UnsupportedError('Método HTTP não suportado: $method');
      }

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 429) {
        // Rate limit atingido: aguardar e retry
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (parser != null) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          if (data['result'] == 'error') {
            throw Exception(data['error']?['description'] ?? 'Erro da API');
          }
          return parser(data);
        }
        return parser!(jsonDecode(responseBody) as Map<String, dynamic>);
      }

      if (response.statusCode == 302) {
        // Redirect para download
        final location = response.headers['location'];
        if (location != null) {
          return await _request<T>(
            uri: Uri.parse(location),
            method: 'GET',
            parser: parser,
            extraHeaders: extraHeaders,
          );
        }
      }

      throw Exception('Falha na requisição ${method} ${uri.path}: ${response.statusCode} $responseBody');
    }

    throw Exception('Rate limit excedido após $maxAttempts tentativas');
  }

  // ------------------------------------------------------------------------
  // Resolução de pasta remota
  // ------------------------------------------------------------------------

  /// ID da pasta raiz do kDrive (o MCP oficial da Infomaniak confirma root=1).
  static const String _rootFolderId = '1';

  /// Encontra o ID de uma pasta pelo nome dentro de um parentId dado.
  /// Retorna null se não encontrar.
  Future<String?> _findFolderByName(String parentId, String folderName) async {
    try {
      final contents = await _listFolderContentsV3(parentId);
      for (var item in contents) {
        if ((item['type'] as String?) == 'directory' &&
            (item['name'] as String?) == folderName) {
          return item['id']?.toString();
        }
      }
    } catch (_) {
      // Pasta não listável ou não existe
    }
    return null;
  }

  /// Resolve o ID da pasta remota (ex: kmemo/notes) navegando a partir da raiz.
  /// Retorna null se não conseguir encontrar a pasta completa.
  Future<String?> _resolveOrCreateKMemoFolderId() async {
    if (_driveId == null) return null;

    final segments = _remoteFolder.split('/').where((s) => s.isNotEmpty).toList();
    var parentId = _rootFolderId;

    for (final segment in segments) {
      final found = await _findFolderByName(parentId, segment);
      if (found == null) {
        // Pasta não existe; tentar criar
        final created = await _createDirectory(parentId, segment);
        if (created == null) return null;
        parentId = created;
      } else {
        parentId = found;
      }
    }

    return parentId;
  }

  /// Lista o conteúdo de uma pasta no kDrive (v3).
  Future<List<Map<String, dynamic>>> _listFolderContentsV3(String folderId) async {
    final response = await _client.get(
      Uri.parse('$_apiBase/3/drive/${_drive_id}/files/$folderId/files'),
      headers: _authHeaders(),
    );

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] == 'error') {
      return [];
    }

    final files = (data['data'] as List<dynamic>?) ?? [];
    return files.cast<Map<String, dynamic>>();
  }

  /// Cria um diretório no kDrive.
  /// parentId: ID da pasta pai (ou "root")
  /// name: nome da pasta a criar
  Future<String?> _createDirectory(String parentId, String name) async {
    final response = await _client.post(
      Uri.parse('$_apiBase/3/drive/${_drive_id}/files/$parentId/directory'),
      headers: _authHeaders(),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      return null;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['result'] == 'success') {
        final dirData = data['data'] as Map<String, dynamic>?;
        if (dirData != null && dirData['id'] != null) {
          return dirData['id'].toString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  // Getter helper para drive_id (não-null quando configurado)
  int get _drive_id => _driveId!;

  // ------------------------------------------------------------------------
  // Upload / Download de notas
  // ------------------------------------------------------------------------

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    if (!isConfigured) return null;

    final payload = {
      'memo': {
        'uuid': memo.uuid,
        'title': memo.title,
        'createdAt': memo.createdAt.toIso8601String(),
        'updatedAt': memo.updatedAt.toIso8601String(),
        'colorIndex': memo.colorIndex,
        'bgImageIndex': memo.bgImageIndex,
        'isArchived': memo.isArchived,
        'isDeleted': memo.isDeleted,
        'remoteFileId': memo.remoteFileId,
        'isSynced': memo.isSynced,
      },
      'blocks': blocks.map((b) {
        return {
          'uuid': b.uuid,
          'type': b.type.name,
          'content': b.content,
          'sortOrder': b.sortOrder,
          'isDeleted': b.isDeleted,
        };
      }).toList(),
      'syncedAt': DateTime.now().toIso8601String(),
    };

    final content = EncryptionService.instance.encrypt(jsonEncode(payload));
    final bytes = utf8.encode(content);

    // Upload direto com directory_path (o kDrive cria pastas automaticamente)
    final params = <String, String>{
      'total_size': bytes.length.toString(),
      'file_name': '${memo.uuid}.json',
      'conflict': 'version', // substitui conteúdo do ficheiro existente
      'directory_path': _remoteFolder, // ex: kmemo/notes
    };

    final uri = Uri.parse('$_apiBase/3/drive/${_drive_id}/upload')
        .replace(queryParameters: params);

    final response = await _client.post(
      uri,
      headers: _authHeaders(),
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao enviar nota: ${response.statusCode} ${response.body}');
    }

    // Extrai o ID do ficheiro criado para associação remota
    return _extractFileIdFromUploadResponse(response.body);
  }

  /// Extrai o ID do ficheiro criado a partir da resposta de upload.
  String? _extractFileIdFromUploadResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['result'] == 'success') {
        final dataField = data['data'];
        if (dataField is Map<String, dynamic> && dataField['id'] != null) {
          return dataField['id'].toString();
        }
      }
    } catch (_) {
      // Resposta não-JSON ou sem id: ignora
    }
    return null;
  }

  @override
  Future<void> deleteMemo(String remoteFileId) async {
    if (!isConfigured) return;

    try {
      await _request(
        uri: Uri.parse('$_apiBase/2/drive/${_drive_id}/files/$remoteFileId'),
        method: 'DELETE',
      );
    } catch (e) {
      print('[KDriveStorage] Erro ao deletar remoto $remoteFileId: $e');
    }
  }

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async {
    if (!isConfigured) return [];

    final folderId = await _resolveOrCreateKMemoFolderId();
    if (folderId == null) return [];

    final files = await _listFolderContentsV3(folderId);

    final result = <RemoteMemoInfo>[];
    for (var file in files) {
      final name = file['name'] as String? ?? '';
      if (!name.endsWith('.json')) continue;
      final id = file['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final updatedAtMs = file['updated_at'] as int? ?? 0;
      result.add(
        RemoteMemoInfo(
          remoteFileId: id,
          name: name,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
        ),
      );
    }
    return result;
  }

  @override
  Future<RemoteMemo> downloadMemo(String remoteFileId) async {
    if (!isConfigured) throw StateError('Storage não configurado');

    // Tenta download direto (pode responder 302)
    final response = await _client.get(
      Uri.parse('$_apiBase/2/drive/${_drive_id}/files/$remoteFileId/download'),
      headers: _authHeaders(),
    );

    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        final downloadResponse = await _client.get(
          Uri.parse(location),
          headers: _authHeaders(),
        );
        return _parseDownloadedMemo(downloadResponse.bodyBytes);
      }
      throw Exception('Falha ao seguir redirecionamento de download');
    }

    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar nota: ${response.statusCode}');
    }

    return _parseDownloadedMemo(response.bodyBytes);
  }

  RemoteMemo _parseDownloadedMemo(List<int> bytes) {
    final content = utf8.decode(bytes);
    final decrypted = EncryptionService.instance.decrypt(content);
    final payload = jsonDecode(decrypted) as Map<String, dynamic>;

    final memoMap = payload['memo'] as Map<String, dynamic>;
    final memo = Memo(
      uuid: memoMap['uuid'] as String,
      title: memoMap['title'] as String? ?? '',
      createdAt: DateTime.parse(memoMap['createdAt'] as String),
      updatedAt: DateTime.parse(memoMap['updatedAt'] as String),
      isSynced: memoMap['isSynced'] as bool? ?? false,
      colorIndex: memoMap['colorIndex'] as int? ?? 0,
      bgImageIndex: memoMap['bgImageIndex'] as int? ?? -1,
      isArchived: memoMap['isArchived'] as bool? ?? false,
      isDeleted: memoMap['isDeleted'] as bool? ?? false,
      remoteFileId: memoMap['remoteFileId'] as String?,
      imageAttachments: memoMap['imageAttachments'] as String? ?? '[]',
      audioAttachments: memoMap['audioAttachments'] as String? ?? '[]',
      linkAttachments: memoMap['linkAttachments'] as String? ?? '[]',
    );

    final blocksList = (payload['blocks'] as List<dynamic>?) ?? [];
    final blocks = blocksList.map((b) {
      final bm = b as Map<String, dynamic>;
      return Block(
        id: 0,
        uuid: bm['uuid'] as String,
        memoUuid: memo.uuid,
        type: _blockTypeFromString(bm['type'] as String? ?? 'text'),
        content: Map<String, dynamic>.from(bm['content'] as Map? ?? {}),
        sortOrder: bm['sortOrder'] as int? ?? 0,
        isDeleted: bm['isDeleted'] as bool? ?? false,
      );
    }).toList();

    return RemoteMemo(memo: memo, blocks: blocks);
  }

  BlockType _blockTypeFromString(String type) {
    switch (type) {
      case 'checklist':
        return BlockType.checklist;
      case 'text':
      default:
        return BlockType.text;
    }
  }

  // ------------------------------------------------------------------------
  // Sincronização: guardas de rate-limit para o MemoProvider
  // ------------------------------------------------------------------------

  /// Indica se já passou o intervalo mínimo desde a última sincronização
  /// (respeita o limite de 60 pedidos/minuto da API Infomaniak).
  @override
  bool get syncAllowed {
    final last = _lastSync;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minSyncInterval;
  }

  /// Regista o fim de um ciclo de sincronização (persistido).
  @override
  void markSyncedNow() {
    _lastSync = DateTime.now();
    _persistLastSync();
  }

  Future<void> _persistLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsLastSync, _lastSync!.millisecondsSinceEpoch);
  }

  /// Orchestrated by MemoProvider (push + pull per memo). Kept to satisfy
  /// the StorageRepository contract; performs a no-op.
  @override
  Future<void> sync() async {
    // O MemoProvider coordena push/pull por nota para poder associar
    // remoteFileId e isSynced individualmente.
  }
}
