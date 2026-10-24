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

/// Default folder inside kDrive where kMemo notes are stored.
const String _defaultRemoteFolder = 'kmemo/notes';

/// Minimum interval between automatic syncs (respects the 60 req/min rate limit).
const Duration _minSyncInterval = Duration(seconds: 5);

class KDriveStorage extends StorageRepository {
  KDriveStorage({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
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

  /// Selected drive id (null if not configured).
  int? get driveId => _driveId;

  /// Selected destination folder id (null if not configured).
  String? get folderId => _folderId;

  /// Selected destination folder name (for display to the user).
  String? get folderName => _folderName;

  /// Breadcrumb path of the selected destination folder.
  List<Map<String, String>> get folderPath => _folderPath;

  /// Configured remote folder (path or numeric id).
  String get remoteFolder => _remoteFolder;

  /// Destination folder name (for display to the user).
  String get folderDisplayName => _folderName ?? _remoteFolder;

  /// Indicates whether encryption is active.
  bool get encryptionEnabled => _encryptionEnabled;

  /// Last full sync date/time.
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = await _secureStorage.read(key: _prefsToken);

    // Read driveId: may be stored as int (old version) or String (new version)
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
    debugPrint(
      '[KDriveStorage] init(): token_raw=$_token, driveId_raw=$driveIdRaw (${driveIdRaw.runtimeType}), folderId_raw=$_folderId, remoteFolder_raw=$_remoteFolder, encryptionEnabled_raw=$_encryptionEnabled, lastSync_raw=$_lastSync',
    );
    debugPrint(
      '[KDriveStorage] init(): token=${_token != null ? 'present' : 'null'}, '
      'driveId=$_driveId, remoteFolder=$_remoteFolder, '
      'encryptionEnabled=$_encryptionEnabled, lastSync=$_lastSync',
    );

    if (_encryptionEnabled) {
      final passphrase = await _secureStorage.read(
        key: _prefsEncryptionPassphrase,
      );
      if (passphrase != null && passphrase.isNotEmpty) {
        EncryptionService.instance.enable(passphrase);
        debugPrint(
          '[KDriveStorage] init(): passphrase loaded from secure storage',
        );
      } else {
        debugPrint(
          '[KDriveStorage] init(): encryption enabled but no passphrase found',
        );
      }
    }
  }

  /// Temporarily sets the OAuth token to allow account
  /// and drive discovery before full configuration.
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _prefsToken, value: token);
    debugPrint('[KDriveStorage] setToken(): token saved to secure storage');
  }

  /// Reads the token stored in secure storage.
  Future<String?> getStoredToken() async {
    final token = await _secureStorage.read(key: _prefsToken);
    debugPrint(
      '[KDriveStorage] getStoredToken(): token=${token != null ? 'present (length=${token.length})' : 'null'}',
    );
    return token;
  }

  /// Reads the stored encryption passphrase (if any).
  Future<String?> getEncryptionPassphrase() async {
    return await _secureStorage.read(key: _prefsEncryptionPassphrase);
  }

  /// Sets only the driveId (without token) to allow listing root folders.
  /// Used when the user selects a drive but has not entered the token yet.
  Future<void> setDriveId(int driveId) async {
    final prefs = await SharedPreferences.getInstance();
    _driveId = driveId;
    await prefs.setString(_prefsDriveId, driveId.toString());
    debugPrint('[KDriveStorage] setDriveId(): driveId=$driveId saved to prefs');
  }

  /// Stores the breadcrumb path of the selected destination folder.
  Future<void> setFolderPath(List<Map<String, dynamic>> path) async {
    final prefs = await SharedPreferences.getInstance();
    _folderPath = path
        .map(
          (e) => {
            'id': e['id']?.toString() ?? '',
            'name': e['name']?.toString() ?? '',
          },
        )
        .toList();
    await prefs.setString(_prefsFolderPath, jsonEncode(_folderPath));
  }

  // ------------------------------------------------------------------------
  // Configuration of storage (token, drive, folder, encryption)
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

    debugPrint(
      '[KDriveStorage] configure() INPUT: remoteFolder="$remoteFolder" (empty=${remoteFolder.isEmpty}), folderId=$folderId, folderName=$folderName',
    );

    _token = token;
    _driveId = driveId;
    _folderId = folderId;
    _folderName = folderName;
    _remoteFolder = remoteFolder.isEmpty ? _defaultRemoteFolder : remoteFolder;
    _encryptionEnabled = encryptionEnabled;

    debugPrint(
      '[KDriveStorage] configure() BEFORE SAVE: _remoteFolder=$_remoteFolder, _folderId=$_folderId, _folderName=$_folderName',
    );

    await _secureStorage.write(key: _prefsToken, value: token);
    await prefs.setString(_prefsDriveId, driveId.toString());
    await prefs.setString(_prefsFolderId, _folderId ?? '');
    await prefs.setString(_prefsFolderName, _folderName ?? '');
    await prefs.setString(_prefsRemoteFolder, _remoteFolder);
    await prefs.setBool(_prefsEncryptionEnabled, encryptionEnabled);

    debugPrint(
      '[KDriveStorage] configure() AFTER SAVE: wrote remoteFolder=$_remoteFolder to prefs',
    );

    debugPrint(
      '[KDriveStorage] configure() Verifying: reading back from prefs...',
    );
    final verifyDriveId = prefs.getString(_prefsDriveId);
    final verifyRemoteFolder = prefs.getString(_prefsRemoteFolder);
    final verifyEncryption = prefs.getBool(_prefsEncryptionEnabled);
    debugPrint(
      '[KDriveStorage] configure() Verified: driveId=$verifyDriveId, remoteFolder=$verifyRemoteFolder, encryptionEnabled=$verifyEncryption',
    );

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

    debugPrint(
      '[KDriveStorage] configure(): driveId=$driveId, driveName=$driveName, '
      'remoteFolder=$_remoteFolder, encryptionEnabled=$encryptionEnabled',
    );
    debugPrint(
      '[KDriveStorage] configure(): saved to SharedPreferences and secure storage',
    );
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
  // Discovery of accounts, drives, folders, and files
  // ------------------------------------------------------------------------

  /// Lists the user's Infomaniak accounts (needed to obtain account_id).
  Future<List<Map<String, dynamic>>> listAccounts() async {
    if (_token == null) throw StateError('Token not configured');
    debugPrint('[KDriveStorage] listAccounts(): calling GET /1/accounts');
    return await _request<List<Map<String, dynamic>>>(
      uri: Uri.parse('$_apiBase/1/accounts'),
      method: 'GET',
      parser: (data) =>
          (data['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  /// Lists the contents of any kDrive folder (files and subfolders).
  /// Useful for hierarchical navigation.
  /// [folderId] is the folder id (use '1' for root).
  Future<List<Map<String, dynamic>>> listFolderContents(String folderId) async {
    if (_driveId == null) throw StateError('Drive not configured');
    debugPrint(
      '[KDriveStorage] listFolderContents($folderId): calling GET /3/drive/$_driveIdValue/files/$folderId/files',
    );
    final files = await _listFolderContentsV3(folderId);
    debugPrint(
      '[KDriveStorage] listFolderContents($folderId): ${files.length} items',
    );
    for (var f in files) {
      debugPrint(
        '[KDriveStorage] listFolderContents($folderId): item id=${f['id']}, name=${f['name']}, type=${f['type']}',
      );
    }
    return files;
  }

  /// Lists only the folders inside the given parent folder.
  Future<List<Map<String, dynamic>>> listFolders(String folderId) async {
    final all = await listFolderContents(folderId);
    final folders = all
        .where((f) {
          final t = f['type']?.toString().toLowerCase();
          return t == 'directory' || t == 'dir' || t == 'folder';
        })
        .cast<Map<String, dynamic>>()
        .toList();
    debugPrint(
      '[KDriveStorage] listFolders($folderId): ${folders.length} folders encontradas',
    );
    for (var f in folders) {
      debugPrint(
        '[KDriveStorage] listFolders($folderId): folder id=${f['id']}, name=${f['name']}',
      );
    }
    return folders;
  }

  /// Creates a new directory inside an existing folder.
  /// [parentId] is the parent folder id (use '1' for root).
  /// [name] is the name of the new folder.
  /// Returns the id of the newly created folder.
  Future<String?> createDirectory(String parentId, String name) async {
    if (_driveId == null) throw StateError('Drive not configured');
    debugPrint(
      '[KDriveStorage] createDirectory($parentId, $name): creating folder...',
    );
    final response = await _client.post(
      Uri.parse('$_apiBase/3/drive/$_driveIdValue/files/$parentId/directory'),
      headers: _authHeaders(),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint(
        '[KDriveStorage] createDirectory($parentId, $name): status=${response.statusCode} body=${response.body}',
      );
      throw Exception(
        'Failed to create folder: ${response.statusCode} ${response.body}',
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['result'] == 'success') {
        final dirData = data['data'] as Map<String, dynamic>?;
        if (dirData != null && dirData['id'] != null) {
          debugPrint(
            '[KDriveStorage] createDirectory($parentId, $name): created id=${dirData['id']}',
          );
          return dirData['id'].toString();
        }
      }
      throw Exception(
        'Failed to create folder: invalid API response (${response.body})',
      );
    } catch (e) {
      debugPrint(
        '[KDriveStorage] createDirectory($parentId, $name): error: $e',
      );
      rethrow;
    }
  }

  /// Lists the folders at the drive root (id=1).
  /// Useful to let the user choose where to store notes.
  Future<List<Map<String, dynamic>>> listRootFolders() async {
    return listFolders('1');
  }

  /// Lists the drives accessible to the account, with pagination support.
  /// The Infomaniak API may return paginated results with total/pages/items_per_page fields.
  Future<List<Map<String, dynamic>>> listDrives(int accountId) async {
    if (_token == null) throw StateError('Token not configured');

    final allDrives = <Map<String, dynamic>>[];
    int page = 1;
    int? totalPages;

    while (true) {
      final uri = Uri.parse(
        '$_apiBase/2/drive?account_id=$accountId&page=$page&per_page=100',
      );
      debugPrint(
        '[KDriveStorage] listDrives(account_id=$accountId): calling GET /2/drive page=$page',
      );

      final data = await _request<Map<String, dynamic>>(
        uri: uri,
        method: 'GET',
        parser: (d) => d,
      );

      debugPrint(
        '[KDriveStorage] listDrives(account_id=$accountId): page=$page response keys=${data.keys.toList()}',
      );

      final drivesPage =
          (data['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      debugPrint(
        '[KDriveStorage] listDrives(account_id=$accountId): page=$page drives=${drivesPage.length}',
      );
      allDrives.addAll(drivesPage);

      // Check pagination info
      totalPages = data['pages'] as int?;
      final itemsPerPage = data['items_per_page'] as int?;
      final total = data['total'] as int?;

      debugPrint(
        '[KDriveStorage] listDrives(account_id=$accountId): total=$total, items_per_page=$itemsPerPage, pages=$totalPages, accumulated=${allDrives.length}',
      );

      if (totalPages != null && page >= totalPages) break;
      if (drivesPage.isEmpty) break;
      if (itemsPerPage != null && drivesPage.length < itemsPerPage) break;

      page++;
      if (page > 10) {
        debugPrint(
          '[KDriveStorage] listDrives(account_id=$accountId): safety limit reached (10 pages)',
        );
        break;
      }
    }

    debugPrint(
      '[KDriveStorage] listDrives(account_id=$accountId): total drives found=${allDrives.length}',
    );
    for (var d in allDrives) {
      debugPrint(
        '[KDriveStorage] listDrives(account_id=$accountId): drive id=${d['id']}, name=${d['name']}',
      );
    }

    return allDrives;
  }

  // ------------------------------------------------------------------------
  // Helpers for HTTP requests with authentication and error handling
  // ------------------------------------------------------------------------

  Map<String, String> _authHeaders() {
    if (_token == null) throw StateError('Token not configured');
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
      final headers = <String, String>{
        ..._authHeaders(),
        if (extraHeaders != null) ...extraHeaders,
      };

      http.StreamedResponse response;
      if (method == 'GET') {
        response = await _client.send(
          http.Request('GET', uri)..headers.addAll(headers),
        );
      } else if (method == 'POST') {
        final request = http.Request('POST', uri)..headers.addAll(headers);
        if (body is String) {
          request.body = body;
        } else if (body is Map) {
          request.body = jsonEncode(body);
        } else if (body is List<int>) {
          request.bodyBytes = body;
        }
        response = await _client.send(request);
      } else if (method == 'DELETE') {
        response = await _client.send(
          http.Request('DELETE', uri)..headers.addAll(headers),
        );
      } else {
        throw UnsupportedError('HTTP method not supported: $method');
      }

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 429) {
        // Rate limit exceeded, wait and retry
        continue;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (parser != null) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          if (data['result'] == 'error') {
            throw Exception(data['error']?['description'] ?? 'API error');
          }
          return parser(data);
        }
        // No parser: success with no body expected (e.g. DELETE).
        return null as T;
      }

      if (response.statusCode == 302) {
        // Redirect for download
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

      throw Exception(
        'Request failed $method ${uri.path}: ${response.statusCode} $responseBody',
      );
    }

    throw Exception('Rate limit exceeded after $maxAttempts attempts');
  }

  // ------------------------------------------------------------------------
  // Remote file/folder management
  // ------------------------------------------------------------------------

  static const String _rootFolderId = '1';

  /// Lists the folder contents in kDrive (v3).
  /// If typeFilter is provided, adds the type[] parameter to filter (e.g. 'directory').
  Future<List<Map<String, dynamic>>> _listFolderContentsV3(
    String folderId, {
    String? typeFilter,
  }) async {
    final params = <String, String>{};
    if (typeFilter != null) {
      params['type[]'] = typeFilter;
    }
    final uri = Uri.parse(
      '$_apiBase/3/drive/$_driveIdValue/files/$folderId/files',
    ).replace(queryParameters: params);
    final response = await _client.get(uri, headers: _authHeaders());

    if (response.statusCode != 200) {
      debugPrint(
        '[KDriveStorage] _listFolderContentsV3($folderId): status=${response.statusCode}',
      );
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] == 'error') {
      debugPrint('[KDriveStorage] _listFolderContentsV3($folderId): API error');
      return [];
    }

    final files = (data['data'] as List<dynamic>?) ?? [];
    debugPrint(
      '[KDriveStorage] _listFolderContentsV3($folderId): ${files.length} items',
    );
    return files.cast<Map<String, dynamic>>();
  }

  // Getter helper for the drive id (non-null when configured)
  int get _driveIdValue => _driveId!;

  // ------------------------------------------------------------------------
  // Upload / Download notes (memos) and their blocks
  // ------------------------------------------------------------------------

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    if (!isConfigured) {
      debugPrint('[KDriveStorage] uploadMemo(${memo.uuid}): NOT CONFIGURED');
      return null;
    }

    // Retry logic with exponential backoff
    int maxRetries = 3;
    Duration backoff = const Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): attempt $attempt/$maxRetries',
        );
        return await _uploadMemoInternal(memo, blocks);
      } catch (e) {
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): attempt $attempt failed: $e',
        );
        if (attempt < maxRetries) {
          debugPrint(
            '[KDriveStorage] uploadMemo(${memo.uuid}): waiting ${backoff.inSeconds}s before trying again',
          );
          await Future.delayed(backoff);
          backoff = backoff * 2; // Exponential backoff
        } else {
          debugPrint(
            '[KDriveStorage] uploadMemo(${memo.uuid}): all attempts failed',
          );
          rethrow;
        }
      }
    }
    return null;
  }

  Future<String?> _uploadMemoInternal(Memo memo, List<Block> blocks) async {
    debugPrint(
      '[KDriveStorage] uploadMemo(${memo.uuid}): starting upload to $_remoteFolder (remoteFileId=${memo.remoteFileId})',
    );

    if (blocks.isEmpty) {
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): no blocks, skip upload',
      );
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
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): empty payload, skip upload',
      );
      return null;
    }

    final content = EncryptionService.instance.encrypt(jsonContent);
    final bytes = utf8.encode(content);

    if (bytes.isEmpty) {
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): empty bytes after encryption, skip upload',
      );
      return null;
    }

    debugPrint(
      '[KDriveStorage] uploadMemo(${memo.uuid}): payload size=${bytes.length} bytes, encrypted=${EncryptionService.instance.isEnabled}',
    );
    debugPrint(
      '[KDriveStorage] uploadMemo(${memo.uuid}): colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}, imageAttachments=${memo.imageAttachments}',
    );

    // If the memo already has a remoteFileId, try to update the existing file first.
    if (memo.remoteFileId != null && memo.remoteFileId!.isNotEmpty) {
      final params = <String, String>{
        'total_size': bytes.length.toString(),
        'file_name': '${memo.uuid}.json',
        'conflict': 'version',
        'file_id': memo.remoteFileId!,
      };
      final uri = Uri.parse(
        '$_apiBase/3/drive/$_driveIdValue/upload',
      ).replace(queryParameters: params);
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): POST update file_id=${memo.remoteFileId} to $uri',
      );
      var response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): update status=${response.statusCode} body=${response.body}',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final remoteId =
            _extractFileIdFromUploadResponse(response.body) ??
            memo.remoteFileId;
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): updated remoteId=$remoteId',
        );
        return remoteId;
      }
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): update failed, trying to create new file instead',
      );
    }

    // Create new file in the selected folder.
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
        final uri = Uri.parse(
          '$_apiBase/3/drive/$_driveIdValue/upload',
        ).replace(queryParameters: paramsBase);
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): POST without directory_id to $uri',
        );
        var response = await _client.post(
          uri,
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): status=${response.statusCode} body=${response.body}',
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final remoteId = _extractFileIdFromUploadResponse(response.body);
          debugPrint(
            '[KDriveStorage] uploadMemo(${memo.uuid}): remoteId=$remoteId',
          );
          return remoteId;
        }
        lastError =
            'Failed to upload note (without directory_id): ${response.statusCode} ${response.body}';
        continue;
      }

      final params = <String, String>{...paramsBase, 'directory_id': dirId};
      final uri = Uri.parse(
        '$_apiBase/3/drive/$_driveIdValue/upload',
      ).replace(queryParameters: params);
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): POST directory_id=$dirId to $uri',
      );
      var response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      debugPrint(
        '[KDriveStorage] uploadMemo(${memo.uuid}): status=${response.statusCode} body=${response.body}',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final remoteId = _extractFileIdFromUploadResponse(response.body);
        debugPrint(
          '[KDriveStorage] uploadMemo(${memo.uuid}): remoteId=$remoteId',
        );
        return remoteId;
      }
      lastError =
          'Failed to upload note: ${response.statusCode} ${response.body}';
    }

    throw Exception(lastError ?? 'Failed to upload note');
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
      // Non JSON response or missing id: ignore
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
      debugPrint('[KDriveStorage] error deleting remote $remoteFileId: $e');
    }
  }

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async {
    if (!isConfigured) return [];

    // List selected destination folder for .json files
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
    debugPrint(
      '[KDriveStorage] listRemoteMemos(): ${result.length} notes found in folder $folderId',
    );
    return result;
  }

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async {
    if (!isConfigured) throw StateError('Storage not configured');

    // Try to download the file directly (may respond with 302 redirect)
    final response = await _client.get(
      Uri.parse(
        '$_apiBase/2/drive/$_driveIdValue/files/$remoteFileId/download',
      ),
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
          debugPrint(
            '[KDriveStorage] downloadMemo($remoteFileId): decrypt fail (wrong passphrase or corrupted file)',
          );
        }
        return result;
      }
      throw Exception('Failed to follow download redirect');
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to download note: ${response.statusCode}');
    }

    final result = _parseDownloadedMemo(response.bodyBytes);
    if (result == null) {
      debugPrint(
        '[KDriveStorage] downloadMemo($remoteFileId): decrypt fail (wrong passphrase or corrupted file)',
      );
    }
    return result;
  }

  RemoteMemo? _parseDownloadedMemo(List<int> bytes) {
    if (bytes.isEmpty) {
      debugPrint('[KDriveStorage] _parseDownloadedMemo: empty file content');
      return null;
    }
    final content = utf8.decode(bytes);
    final decrypted = EncryptionService.instance.tryDecrypt(content);
    if (decrypted == null) {
      debugPrint(
        '[KDriveStorage] _parseDownloadedMemo: decrypt fail (wrong passphrase or corrupted file)',
      );
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

      debugPrint(
        '[KDriveStorage] _parseDownloadedMemo: uuid=${memo.uuid}, colorIndex=${memo.colorIndex}, bgImageIndex=${memo.bgImageIndex}, imageAttachments=${memo.imageAttachments}',
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
    } catch (e) {
      debugPrint(
        '[KDriveStorage] _parseDownloadedMemo: error parsing JSON: $e',
      );
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
  // Sync: rate-limit guards for MemoProvider
  // ------------------------------------------------------------------------

  /// Indicates whether the minimum interval since the last sync has passed
  /// (respects the 60 requests/minute limit of the Infomaniak API).
  @override
  bool get syncAllowed {
    final last = _lastSync;
    if (last == null) return true;
    return DateTime.now().difference(last) >= _minSyncInterval;
  }

  /// Records the end of the sync cycle (persisted).
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
    // MemoProvider coordinates push/pull per note to associate
    // remoteFileId and isSynced individually.
  }
}
