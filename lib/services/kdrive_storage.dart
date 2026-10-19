// lib/services/kdrive_storage.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
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
const String _prefsFolderId = 'infomaniak_folder_id';
const String _prefsFolderName = 'infomaniak_folder_name';
const String _prefsFolderPath = 'infomaniak_folder_path';
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
  String? _folderId;
  String? _folderName;
  List<Map<String, String>> _folderPath = [];
  String _remoteFolder = _defaultRemoteFolder;
  bool _encryptionEnabled = false;
  DateTime? _lastSync;

  @override
  bool get isConfigured => _token != null && _driveId != null;

  @override
  String get storageName => 'kDrive';

  /// Drive ID selecionado (null se não configurado).
  int? get driveId => _driveId;

  /// ID da pasta de destino selecionada (null se não configurado).
  String? get folderId => _folderId;

  /// Nome da pasta de destino selecionada (para exibição ao utilizador).
  String? get folderName => _folderName;

  /// Caminho (breadcrumb) da pasta de destino selecionada.
  List<Map<String, String>> get folderPath => _folderPath;

  /// Pasta remota configurada (caminho ou ID numérico).
  String get remoteFolder => _remoteFolder;

  /// Nome da pasta de destino (para exibição ao utilizador).
  String get folderDisplayName => _folderName ?? _remoteFolder;

  /// Indica se a encriptação está ativa.
  bool get encryptionEnabled => _encryptionEnabled;

  /// Última data/hora de sincronização completa.
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = await _secureStorage.read(key: _prefsToken);

    // Ler driveId: pode estar guardado como int (versão antiga) ou String (versão nova)
    final driveIdRaw = prefs.get(_prefsDriveId);
    if (driveIdRaw is int) {
      _driveId = driveIdRaw;
    } else if (driveIdRaw is String) {
      _driveId = int.tryParse(driveIdRaw);
    } else {
      _driveId = null;
    }

    _folderId = prefs.getString(_prefsFolderId);
    _folderName = prefs.getString(_prefsFolderName);
    final folderPathRaw = prefs.getString(_prefsFolderPath);
    if (folderPathRaw != null && folderPathRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(folderPathRaw) as List<dynamic>;
        _folderPath = decoded
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
      } catch (_) {
        _folderPath = [];
      }
    }
    if (_folderId == null || _folderId!.isEmpty) {
      _folderId = '5';
      _folderName = _folderName ?? 'Private';
      await prefs.setString(_prefsFolderId, _folderId!);
      await prefs.setString(_prefsFolderName, _folderName!);
    }
    _remoteFolder = prefs.getString(_prefsRemoteFolder) ?? _defaultRemoteFolder;
    _encryptionEnabled = prefs.getBool(_prefsEncryptionEnabled) ?? false;

    final lastSyncMs = prefs.getInt(_prefsLastSync);
    if (lastSyncMs != null) {
      _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }

    debugPrint('[KDriveStorage] init(): READING from prefs...');
    debugPrint('[KDriveStorage] init(): token_raw=$_token, driveId_raw=$driveIdRaw (${driveIdRaw.runtimeType}), folderId_raw=$_folderId, remoteFolder_raw=$_remoteFolder, encryptionEnabled_raw=$_encryptionEnabled, lastSync_raw=$_lastSync');
    debugPrint('[KDriveStorage] init(): token=${_token != null ? 'present' : 'null'}, '
        'driveId=$_driveId, remoteFolder=$_remoteFolder, '
        'encryptionEnabled=$_encryptionEnabled, lastSync=$_lastSync');

    if (_encryptionEnabled) {
      final passphrase = await _secureStorage.read(
        key: _prefsEncryptionPassphrase,
      );
      if (passphrase != null && passphrase.isNotEmpty) {
        EncryptionService.instance.enable(passphrase);
        debugPrint('[KDriveStorage] init(): passphrase loaded from secure storage');
      } else {
        debugPrint('[KDriveStorage] init(): encryption enabled but no passphrase found');
      }
    }
  }

  /// Define o token OAuth temporariamente para permitir a descoberta de contas
  /// e drives antes da configuração completa.
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _prefsToken, value: token);
    debugPrint('[KDriveStorage] setToken(): token saved to secure storage');
  }

  /// Lê o token guardado no secure storage.
  Future<String?> getStoredToken() async {
    final token = await _secureStorage.read(key: _prefsToken);
    debugPrint('[KDriveStorage] getStoredToken(): token=${token != null ? 'present (length=${token.length})' : 'null'}');
    return token;
  }

  /// Lê a passphrase de encriptação guardada (se existir).
  Future<String?> getEncryptionPassphrase() async {
    return await _secureStorage.read(key: _prefsEncryptionPassphrase);
  }

  /// Define apenas o driveId (sem token) para permitir listar pastas da raiz.
  /// Usado quando o utilizador seleciona um drive mas ainda não colocou o token.
  Future<void> setDriveId(int driveId) async {
    final prefs = await SharedPreferences.getInstance();
    _driveId = driveId;
    await prefs.setString(_prefsDriveId, driveId.toString());
    debugPrint('[KDriveStorage] setDriveId(): driveId=$driveId saved to prefs');
  }

  /// Guarda o caminho (breadcrumb) da pasta de destino selecionada.
  Future<void> setFolderPath(List<Map<String, dynamic>> path) async {
    final prefs = await SharedPreferences.getInstance();
    _folderPath = path
        .map((e) => {'id': e['id']?.toString() ?? '', 'name': e['name']?.toString() ?? ''})
        .toList();
    await prefs.setString(_prefsFolderPath, jsonEncode(_folderPath));
  }

  // ------------------------------------------------------------------------
  // Configuração
  // ------------------------------------------------------------------------

  Future<void> configure({
    required String token,
    required int driveId,
    required String driveName,
    String remoteFolder = _defaultRemoteFolder,
    String? folderId,
    String? folderName,
    bool encryptionEnabled = false,
    String? encryptionPassphrase,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    debugPrint('[KDriveStorage] configure() INPUT: remoteFolder="$remoteFolder" (empty=${remoteFolder.isEmpty}), folderId=$folderId, folderName=$folderName');

    _token = token;
    _driveId = driveId;
    _folderId = folderId;
    _folderName = folderName;
    _remoteFolder = remoteFolder.isEmpty ? _defaultRemoteFolder : remoteFolder;
    _encryptionEnabled = encryptionEnabled;

    debugPrint('[KDriveStorage] configure() BEFORE SAVE: _remoteFolder=$_remoteFolder, _folderId=$_folderId, _folderName=$_folderName');

    await _secureStorage.write(key: _prefsToken, value: token);
    await prefs.setString(_prefsDriveId, driveId.toString());
    await prefs.setString(_prefsFolderId, _folderId ?? '');
    await prefs.setString(_prefsFolderName, _folderName ?? '');
    await prefs.setString(_prefsRemoteFolder, _remoteFolder);
    await prefs.setBool(_prefsEncryptionEnabled, encryptionEnabled);

    debugPrint('[KDriveStorage] configure() AFTER SAVE: wrote remoteFolder=$_remoteFolder to prefs');

    debugPrint('[KDriveStorage] configure() Verifying: reading back from prefs...');
    final verifyDriveId = prefs.getString(_prefsDriveId);
    final verifyRemoteFolder = prefs.getString(_prefsRemoteFolder);
    final verifyEncryption = prefs.getBool(_prefsEncryptionEnabled);
    debugPrint('[KDriveStorage] configure() Verified: driveId=$verifyDriveId, remoteFolder=$verifyRemoteFolder, encryptionEnabled=$verifyEncryption');

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

    debugPrint('[KDriveStorage] configure(): driveId=$driveId, driveName=$driveName, '
        'remoteFolder=$_remoteFolder, encryptionEnabled=$encryptionEnabled');
    debugPrint('[KDriveStorage] configure(): saved to SharedPreferences and secure storage');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _driveId = null;
    _folderId = null;
    _folderPath = [];
    _remoteFolder = _defaultRemoteFolder;
    _encryptionEnabled = false;
    _lastSync = null;

    await _secureStorage.delete(key: _prefsToken);
    await _secureStorage.delete(key: _prefsEncryptionPassphrase);
    await prefs.remove(_prefsDriveId);
    await prefs.remove(_prefsFolderId);
    await prefs.remove(_prefsFolderPath);
    await prefs.remove(_prefsRemoteFolder);
    await prefs.remove(_prefsEncryptionEnabled);
    await prefs.remove(_prefsLastSync);

    debugPrint('[KDriveStorage] logout(): all config cleared');
  }

  // ------------------------------------------------------------------------
  // Descoberta de drives (para a página de configuração)
  // ------------------------------------------------------------------------

  /// Lista as contas do utilizador na Infomaniak (necessário para obter o account_id).
  Future<List<Map<String, dynamic>>> listAccounts() async {
    if (_token == null) throw StateError('Token não configurado');
    debugPrint('[KDriveStorage] listAccounts(): calling GET /1/accounts');
    return await _request<List<Map<String, dynamic>>>(
      uri: Uri.parse('$_apiBase/1/accounts'),
      method: 'GET',
      parser: (data) => (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  /// Lista o conteúdo de qualquer pasta do kDrive (ficheiros e subpastas).
  /// Útil para navegação hierárquica.
  /// [folderId] é o ID da pasta (use '1' para a raiz).
  Future<List<Map<String, dynamic>>> listFolderContents(String folderId) async {
    if (_driveId == null) throw StateError('Drive não configurado');
    debugPrint('[KDriveStorage] listFolderContents($folderId): calling GET /3/drive/$_driveIdValue/files/$folderId/files');
    final files = await _listFolderContentsV3(folderId);
    debugPrint('[KDriveStorage] listFolderContents($folderId): ${files.length} itens');
    for (var f in files) {
      debugPrint('[KDriveStorage] listFolderContents($folderId): item id=${f['id']}, name=${f['name']}, type=${f['type']}');
    }
    return files;
  }

  /// Lista apenas as pastas de uma dada pasta pai.
  Future<List<Map<String, dynamic>>> listFolders(String folderId) async {
    final all = await listFolderContents(folderId);
    final folders = all.where((f) {
      final t = f['type']?.toString().toLowerCase();
      return t == 'directory' || t == 'dir' || t == 'folder';
    }).cast<Map<String, dynamic>>().toList();
    debugPrint('[KDriveStorage] listFolders($folderId): ${folders.length} pastas encontradas');
    for (var f in folders) {
      debugPrint('[KDriveStorage] listFolders($folderId): pasta id=${f['id']}, name=${f['name']}');
    }
    return folders;
  }

  /// Cria um novo diretório dentro de uma pasta existente.
  /// [parentId] é o ID da pasta pai (use '1' para a raiz).
  /// [name] é o nome da nova pasta.
  /// Retorna o ID da nova pasta criada.
  Future<String?> createDirectory(String parentId, String name) async {
    if (_driveId == null) throw StateError('Drive não configurado');
    debugPrint('[KDriveStorage] createDirectory($parentId, $name): creating folder...');
    final response = await _client.post(
      Uri.parse('$_apiBase/3/drive/$_driveIdValue/files/$parentId/directory'),
      headers: _authHeaders(),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('[KDriveStorage] createDirectory($parentId, $name): status=${response.statusCode} body=${response.body}');
      throw Exception('Falha ao criar pasta: ${response.statusCode} ${response.body}');
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['result'] == 'success') {
        final dirData = data['data'] as Map<String, dynamic>?;
        if (dirData != null && dirData['id'] != null) {
          debugPrint('[KDriveStorage] createDirectory($parentId, $name): created id=${dirData['id']}');
          return dirData['id'].toString();
        }
      }
      throw Exception('Falha ao criar pasta: resposta inválida da API (${response.body})');
    } catch (e) {
      debugPrint('[KDriveStorage] createDirectory($parentId, $name): erro: $e');
      rethrow;
    }
  }

  /// Lista as pastas da raiz do drive (id=1).
  /// Útil para deixar o utilizador escolher onde guardar as notas.
  Future<List<Map<String, dynamic>>> listRootFolders() async {
    return listFolders('1');
  }

  /// Lista os drives acessíveis para uma conta, com suporte a paginação.
  /// A API Infomaniak pode retornar resultados paginados com campos total/pages/items_per_page.
  Future<List<Map<String, dynamic>>> listDrives(int accountId) async {
    if (_token == null) throw StateError('Token não configurado');

    final allDrives = <Map<String, dynamic>>[];
    int page = 1;
    int? totalPages;

    while (true) {
      final uri = Uri.parse(
        '$_apiBase/2/drive?account_id=$accountId&page=$page&per_page=100',
      );
      debugPrint('[KDriveStorage] listDrives(account_id=$accountId): calling GET /2/drive page=$page');

      final data = await _request<Map<String, dynamic>>(
        uri: uri,
        method: 'GET',
        parser: (d) => d,
      );

      debugPrint('[KDriveStorage] listDrives(account_id=$accountId): page=$page response keys=${data.keys.toList()}');

      final drivesPage = (data['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint('[KDriveStorage] listDrives(account_id=$accountId): page=$page drives=${drivesPage.length}');
      allDrives.addAll(drivesPage);

      // Verificar se há mais páginas
      totalPages = data['pages'] as int?;
      final itemsPerPage = data['items_per_page'] as int?;
      final total = data['total'] as int?;

      debugPrint('[KDriveStorage] listDrives(account_id=$accountId): total=$total, items_per_page=$itemsPerPage, pages=$totalPages, accumulated=${allDrives.length}');

      if (totalPages != null && page >= totalPages) break;
      if (drivesPage.isEmpty) break;
      if (itemsPerPage != null && drivesPage.length < itemsPerPage) break;

      page++;
      if (page > 10) {
        debugPrint('[KDriveStorage] listDrives(account_id=$accountId): safety limit reached (10 pages)');
        break;
      }
    }

    debugPrint('[KDriveStorage] listDrives(account_id=$accountId): total drives found=${allDrives.length}');
    for (var d in allDrives) {
      debugPrint('[KDriveStorage] listDrives(account_id=$accountId): drive id=${d['id']}, name=${d['name']}');
    }

    return allDrives;
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

      throw Exception('Falha na requisição $method ${uri.path}: ${response.statusCode} $responseBody');
    }

    throw Exception('Rate limit excedido após $maxAttempts tentativas');
  }

  // ------------------------------------------------------------------------
  // Resolução de pasta remota
  // ------------------------------------------------------------------------

  /// ID da pasta raiz do kDrive (o MCP oficial da Infomaniak confirma root=1).
  static const String _rootFolderId = '1';



  /// Lista o conteúdo de uma pasta no kDrive (v3).
  /// Se typeFilter for fornecido, adiciona o parâmetro type[] para filtrar (ex: 'directory').
  Future<List<Map<String, dynamic>>> _listFolderContentsV3(String folderId, {String? typeFilter}) async {
    final params = <String, String>{};
    if (typeFilter != null) {
      params['type[]'] = typeFilter;
    }
    final uri = Uri.parse('$_apiBase/3/drive/$_driveIdValue/files/$folderId/files')
        .replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: _authHeaders(),
    );

    if (response.statusCode != 200) {
      debugPrint('[KDriveStorage] _listFolderContentsV3($folderId): status=${response.statusCode}');
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] == 'error') {
      debugPrint('[KDriveStorage] _listFolderContentsV3($folderId): API error');
      return [];
    }

    final files = (data['data'] as List<dynamic>?) ?? [];
    debugPrint('[KDriveStorage] _listFolderContentsV3($folderId): ${files.length} items');
    return files.cast<Map<String, dynamic>>();
  }


  // Getter helper para drive_id (não-null quando configurado)
  int get _driveIdValue => _driveId!;

  // ------------------------------------------------------------------------
  // Upload / Download de notas
  // ------------------------------------------------------------------------

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    if (!isConfigured) {
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): NOT CONFIGURED');
      return null;
    }

    // Retry automático com backoff exponencial
    int maxRetries = 3;
    Duration backoff = const Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): tentativa $attempt/$maxRetries');
        return await _uploadMemoInternal(memo, blocks);
      } catch (e) {
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): tentativa $attempt falhou: $e');
        if (attempt < maxRetries) {
          debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): aguardando ${backoff.inSeconds}s antes de tentar novamente');
          await Future.delayed(backoff);
          backoff = backoff * 2; // backoff exponencial
        } else {
          debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): todas as tentativas falharam');
          rethrow;
        }
      }
    }
    return null;
  }

  Future<String?> _uploadMemoInternal(Memo memo, List<Block> blocks) async {

    debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): starting upload to $_remoteFolder (remoteFileId=${memo.remoteFileId})');

    // Se não há blocos ou conteúdo vazio, não fazer upload
    if (blocks.isEmpty) {
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): sem blocos, skip upload');
      return null;
    }

    final payload = {
      'memo': {
        'uuid': memo.uuid,
        'title': memo.title,
        'createdAt': memo.createdAt.toIso8601String(),
        'updatedAt': memo.updatedAt.toIso8601String(),
        'colorIndex': memo.colorIndex,
        'bgImageIndex': memo.bgImageIndex,
        'imageAttachments': memo.imageAttachments,
        'audioAttachments': memo.audioAttachments,
        'linkAttachments': memo.linkAttachments,
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

    final jsonContent = jsonEncode(payload);
    if (jsonContent.isEmpty || jsonContent == '{}') {
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): payload vazio, skip upload');
      return null;
    }

    final content = EncryptionService.instance.encrypt(jsonContent);
    final bytes = utf8.encode(content);

    if (bytes.isEmpty) {
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): bytes vazios após encriptação, skip upload');
      return null;
    }

    debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): payload size=${bytes.length} bytes, encrypted=${EncryptionService.instance.isEnabled}');
    debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}, imageAttachments=${memo.imageAttachments}');

    // Se já existe remoteFileId, tentar atualizar o ficheiro existente via file_id.
    if (memo.remoteFileId != null && memo.remoteFileId!.isNotEmpty) {
      final params = <String, String>{
        'total_size': bytes.length.toString(),
        'file_name': '${memo.uuid}.json',
        'conflict': 'version',
        'file_id': memo.remoteFileId!,
      };
      final uri = Uri.parse('$_apiBase/3/drive/$_driveIdValue/upload')
          .replace(queryParameters: params);
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): POST update file_id=${memo.remoteFileId} to $uri');
      var response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): update status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final remoteId = _extractFileIdFromUploadResponse(response.body) ?? memo.remoteFileId;
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): updated remoteId=$remoteId');
        return remoteId;
      }
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): update falhou, tentando recriar');
    }

    // Criar novo ficheiro na pasta selecionada.
    final paramsBase = <String, String>{
      'total_size': bytes.length.toString(),
      'file_name': '${memo.uuid}.json',
      'conflict': 'version',
    };

    final dirIdsToTry = <String>[];
    if (_folderId != null && _folderId!.isNotEmpty) {
      final dirIdInt = int.tryParse(_folderId!);
      if (dirIdInt != null) dirIdsToTry.add(_folderId!);
    }
    if (_remoteFolder.isNotEmpty && _remoteFolder != _defaultRemoteFolder) {
      final dirIdInt = int.tryParse(_remoteFolder);
      if (dirIdInt != null && !dirIdsToTry.contains(_remoteFolder)) {
        dirIdsToTry.add(_remoteFolder);
      }
    }
    dirIdsToTry.add('none');
    dirIdsToTry.add(_rootFolderId);

    String? lastError;
    for (final dirId in dirIdsToTry) {
      if (dirId == 'none') {
        final uri = Uri.parse('$_apiBase/3/drive/$_driveIdValue/upload')
            .replace(queryParameters: paramsBase);
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): POST sem directory_id to $uri');
        var response = await _client.post(
          uri,
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): status=${response.statusCode} body=${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final remoteId = _extractFileIdFromUploadResponse(response.body);
          debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): remoteId=$remoteId');
          return remoteId;
        }
        lastError = 'Falha ao enviar nota (sem directory_id): ${response.statusCode} ${response.body}';
        continue;
      }

      final params = <String, String>{
        ...paramsBase,
        'directory_id': dirId,
      };
      final uri = Uri.parse('$_apiBase/3/drive/$_driveIdValue/upload')
          .replace(queryParameters: params);
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): POST directory_id=$dirId to $uri');
      var response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final remoteId = _extractFileIdFromUploadResponse(response.body);
        debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): remoteId=$remoteId');
        return remoteId;
      }
      lastError = 'Falha ao enviar nota: ${response.statusCode} ${response.body}';
    }

    throw Exception(lastError ?? 'Falha ao enviar nota');
  }

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
        uri: Uri.parse('$_apiBase/2/drive/$_driveIdValue/files/$remoteFileId'),
        method: 'DELETE',
      );
    } catch (e) {
      debugPrint('[KDriveStorage] Erro ao deletar remoto $remoteFileId: $e');
    }
  }

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async {
    if (!isConfigured) return [];

    // Listar a pasta de destino selecionada (ou a raiz se nenhuma selecionada) para encontrar notas JSON
    final folderId = _folderId ?? _rootFolderId;
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
    debugPrint('[KDriveStorage] listRemoteMemos(): ${result.length} notes found in folder $folderId');
    return result;
  }

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async {
    if (!isConfigured) throw StateError('Storage não configurado');

    // Tenta download direto (pode responder 302)
    final response = await _client.get(
      Uri.parse('$_apiBase/2/drive/$_driveIdValue/files/$remoteFileId/download'),
      headers: _authHeaders(),
    );

    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        final downloadResponse = await _client.get(
          Uri.parse(location),
          headers: _authHeaders(),
        );
        final result = _parseDownloadedMemo(downloadResponse.bodyBytes);
        if (result == null) {
          debugPrint('[KDriveStorage] downloadMemo($remoteFileId): falha ao desencriptar (passphrase errada ou dados corrompidos)');
        }
        return result;
      }
      throw Exception('Falha ao seguir redirecionamento de download');
    }

    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar nota: ${response.statusCode}');
    }

    final result = _parseDownloadedMemo(response.bodyBytes);
    if (result == null) {
      debugPrint('[KDriveStorage] downloadMemo($remoteFileId): falha ao desencriptar (passphrase errada ou dados corrompidos)');
    }
    return result;
  }

  RemoteMemo? _parseDownloadedMemo(List<int> bytes) {
    final content = utf8.decode(bytes);
    final decrypted = EncryptionService.instance.tryDecrypt(content);
    if (decrypted == null) {
      debugPrint('[KDriveStorage] _parseDownloadedMemo: falha ao desencriptar (passphrase errada ou dados corrompidos)');
      return null;
    }

    try {
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

      debugPrint('[KDriveStorage] _parseDownloadedMemo: uuid=${memo.uuid}, colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}, imageAttachments=${memo.imageAttachments}');

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
    } catch (e) {
      debugPrint('[KDriveStorage] _parseDownloadedMemo: erro ao parsear JSON: $e');
      return null;
    }
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
    debugPrint('[KDriveStorage] markSyncedNow(): lastSync=$_lastSync');
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
