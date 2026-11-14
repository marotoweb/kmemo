// lib/services/webdav_storage.dart

import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../database/database.dart';
import 'encryption_service.dart';
import 'memo_serialization.dart';
import 'storage_repository.dart';

const String _prefsUrl = 'webdav_url';
const String _prefsUsername = 'webdav_username';
const String _prefsFolder = 'webdav_folder';
const String _prefsEncryptionEnabled = 'webdav_encryption_enabled';
const String _prefsLastSync = 'webdav_last_sync';
const String _prefsPassword = 'webdav_password';
const String _prefsEncryptionPassphrase = 'webdav_encryption_passphrase';

/// Default folder inside the WebDAV account where kMemo notes are stored.
const String _defaultFolder = 'kmemo/notes';

/// Normalises the server URL typed by the user.
///
/// The scheme is optional: a bare host (or host + path) assumes HTTPS, which
/// is what every WebDAV provider expects. An explicit `http://` is kept for
/// local servers. The result always ends with a slash, so it can be used as a
/// prefix for the folder and the file paths.
String normalizeWebdavUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return '';
  final lower = value.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    value = 'https://$value';
  }
  if (!value.endsWith('/')) value = '$value/';
  return value;
}

/// WebDAV backend for remote sync.
///
/// Notes are stored as `<uuid>.json` inside a folder of the user's WebDAV
/// account, using the same payload as kDrive (see `memo_serialization.dart`),
/// so a note can be moved between backends. Writes always overwrite the file:
/// WebDAV has no version history, so there is nothing to clear afterwards.
class WebDAVStorage extends StorageRepository {
  WebDAVStorage({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  String? _baseUrl;
  String? _username;
  String? _password;
  String _folder = _defaultFolder;
  bool _encryptionEnabled = false;
  DateTime? _lastSync;
  bool _folderReady = false;

  @override
  bool get isConfigured =>
      _baseUrl != null && _username != null && _password != null;

  @override
  String get storageName => 'WebDAV';

  @override
  bool get encryptionEnabled => _encryptionEnabled;

  @override
  bool get supportsVersionHistory => false;

  /// Server URL configured by the user (with a trailing slash).
  String get baseUrl => _baseUrl ?? '';

  /// User name configured by the user.
  String get username => _username ?? '';

  /// Destination folder, relative to the server URL.
  String get folder => _folder;

  /// Whether a password is stored (never expose the password itself).
  bool get hasPassword => _password != null && _password!.isNotEmpty;

  /// Last completed sync.
  DateTime? get lastSync => _lastSync;

  // ---------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------

  /// Loads the saved configuration.
  ///
  /// [applyEncryption] is false when this is not the active backend (see
  /// KDriveStorage.init).
  @override
  Future<void> init({bool applyEncryption = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefsUrl);
    _username = prefs.getString(_prefsUsername);
    _folder = prefs.getString(_prefsFolder) ?? _defaultFolder;
    _encryptionEnabled = prefs.getBool(_prefsEncryptionEnabled) ?? false;

    final lastSyncMs = prefs.getInt(_prefsLastSync);
    if (lastSyncMs != null) {
      _lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
    }

    _password = await _secureStorage.read(key: _prefsPassword);

    if (_encryptionEnabled && applyEncryption) {
      final passphrase = await _secureStorage.read(
        key: _prefsEncryptionPassphrase,
      );
      if (passphrase != null && passphrase.isNotEmpty) {
        EncryptionService.instance.enable(passphrase);
        debugPrint('[WebDAVStorage] init(): passphrase loaded from secure storage');
      } else {
        // The upload guard refuses to write plain text until the passphrase
        // is provided again in the sync settings.
        debugPrint(
          '[WebDAVStorage] init(): encryption enabled but no passphrase found',
        );
      }
    } else if (applyEncryption) {
      EncryptionService.instance.disable();
    }

    debugPrint(
      '[WebDAVStorage] init(): url=${_baseUrl == null ? 'empty' : 'set'}, '
      'username=${_username == null ? 'empty' : 'set'}, '
      'password=${_password == null || _password!.isEmpty ? 'empty' : 'present'}, '
      'folder=$_folder, encryptionEnabled=$_encryptionEnabled',
    );
  }

  /// Saves the WebDAV configuration.
  ///
  /// An empty [password] keeps the stored one (the normal case when only the
  /// URL or the folder changes). Turning encryption off removes the stored
  /// passphrase.
  Future<void> configure({
    required String baseUrl,
    required String username,
    String? password,
    String? folder,
    required bool encryptionEnabled,
    String? passphrase,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedUrl = normalizeWebdavUrl(baseUrl);
    final normalizedFolder = (folder ?? _folder)
        .trim()
        .replaceAll(RegExp(r'^/+|/+$'), '');

    _baseUrl = normalizedUrl;
    _username = username.trim();
    _folder = normalizedFolder.isEmpty ? _defaultFolder : normalizedFolder;
    _folderReady = false;

    if (password != null && password.isNotEmpty) {
      _password = password;
      await _secureStorage.write(key: _prefsPassword, value: password);
    }

    final previousEncryption = _encryptionEnabled;
    _encryptionEnabled = encryptionEnabled;
    if (encryptionEnabled) {
      final pass = passphrase?.trim() ?? '';
      if (pass.isNotEmpty) {
        await _secureStorage.write(
          key: _prefsEncryptionPassphrase,
          value: pass,
        );
        EncryptionService.instance.enable(pass);
      } else {
        final stored = await _secureStorage.read(
          key: _prefsEncryptionPassphrase,
        );
        if (stored != null && stored.isNotEmpty) {
          EncryptionService.instance.enable(stored);
        }
      }
    } else {
      EncryptionService.instance.disable();
      await _secureStorage.delete(key: _prefsEncryptionPassphrase);
    }

    await prefs.setString(_prefsUrl, _baseUrl!);
    await prefs.setString(_prefsUsername, _username!);
    await prefs.setString(_prefsFolder, _folder);
    await prefs.setBool(_prefsEncryptionEnabled, _encryptionEnabled);

    debugPrint(
      '[WebDAVStorage] configure(): folder=$_folder, '
      'encryption=$previousEncryption -> $_encryptionEnabled, '
      'password=${hasPassword ? 'present' : 'empty'}',
    );
  }

  /// Removes the WebDAV configuration and the stored secrets.
  Future<void> clearConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsUrl);
    await prefs.remove(_prefsUsername);
    await prefs.remove(_prefsFolder);
    await prefs.remove(_prefsEncryptionEnabled);
    await prefs.remove(_prefsLastSync);
    await _secureStorage.delete(key: _prefsPassword);
    await _secureStorage.delete(key: _prefsEncryptionPassphrase);
    _baseUrl = null;
    _username = null;
    _password = null;
    _folder = _defaultFolder;
    _encryptionEnabled = false;
    _folderReady = false;
    _lastSync = null;
    // EncryptionService is intentionally left alone: the caller may have just
    // enabled the passphrase of the backend replacing this one.
  }

  @override
  Future<String?> getEncryptionPassphrase() async {
    return _secureStorage.read(key: _prefsEncryptionPassphrase);
  }

  @override
  void markSyncedNow() {
    _lastSync = DateTime.now();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(
        _prefsLastSync,
        _lastSync!.millisecondsSinceEpoch,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // URLs and authentication
  // ---------------------------------------------------------------------

  String get _baseWithSlash =>
      (_baseUrl ?? '').endsWith('/') ? _baseUrl! : '${_baseUrl!}/';

  /// Folder path without leading/trailing slashes (may be empty = server root).
  String get _folderPath => _folder.replaceAll(RegExp(r'^/+|/+$'), '');

  Uri _folderUri() => Uri.parse(
    _folderPath.isEmpty ? _baseWithSlash : '$_baseWithSlash$_folderPath/',
  );

  Uri _remoteUri(String relativePath) =>
      Uri.parse('$_baseWithSlash${relativePath.replaceAll(RegExp(r'^/+'), '')}');

  Map<String, String> _authHeaders() {
    final credentials = base64Encode(utf8.encode('$_username:$_password'));
    return {'Authorization': 'Basic $credentials'};
  }

  /// Sends a WebDAV method that `http.Client` does not expose directly.
  Future<http.Response> _davRequest(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = body;
    return http.Response.fromStream(await _client.send(request));
  }

  // ---------------------------------------------------------------------
  // Remote operations
  // ---------------------------------------------------------------------

  /// Checks that the server accepts the credentials.
  Future<void> testConnection() async {
    if (!isConfigured) {
      throw StateError('WebDAV is not configured');
    }
    final response = await _davRequest(
      'PROPFIND',
      _folderPath.isEmpty ? Uri.parse(_baseWithSlash) : _folderUri(),
      headers: {..._authHeaders(), 'Depth': '0'},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Authentication failed (${response.statusCode})');
    }
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw Exception('Server replied with ${response.statusCode}');
    }
  }

  /// Checks a server/credentials pair without saving anything, so the user can
  /// test the form before it becomes the active configuration.
  ///
  /// A null/empty [password] means "use the stored one".
  Future<void> testConnectionWith({
    required String baseUrl,
    required String username,
    String? password,
    String? folder,
  }) async {
    final pw = (password != null && password.isNotEmpty) ? password : _password;
    if (pw == null || pw.isEmpty) {
      throw StateError('No password configured');
    }
    final base = normalizeWebdavUrl(baseUrl);
    final folderPath = (folder ?? _folder)
        .trim()
        .replaceAll(RegExp(r'^/+|/+$'), '');
    final uri = Uri.parse(folderPath.isEmpty ? base : '$base$folderPath/');
    final credentials = base64Encode(utf8.encode('$username:$pw'));

    final response = await _davRequest(
      'PROPFIND',
      uri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Depth': '0',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Authentication failed (${response.statusCode})');
    }
    // 404 is fine: the folder is created by the first upload.
    if (response.statusCode != 207 &&
        response.statusCode != 200 &&
        response.statusCode != 404) {
      throw Exception('Server replied with ${response.statusCode}');
    }
  }

  /// Creates every missing folder of the destination path (MKCOL is not
  /// recursive). Existing collections answer 405, which is not an error.
  Future<void> _ensureFolders() async {
    if (_folderReady || _folderPath.isEmpty) return;
    final segments = _folderPath.split('/').where((s) => s.isNotEmpty);
    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      final response = await _davRequest(
        'MKCOL',
        Uri.parse('$_baseWithSlash$current/'),
        headers: _authHeaders(),
      );
      if (response.statusCode == 201 ||
          response.statusCode == 405 || // already exists
          response.statusCode == 301) {
        continue;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed (${response.statusCode})');
      }
      if (response.statusCode == 409) {
        throw Exception(
          'Cannot create folder "$current": a parent collection is missing',
        );
      }
      throw Exception(
        'Cannot create folder "$current" (${response.statusCode})',
      );
    }
    _folderReady = true;
  }

  @override
  Future<String?> uploadMemo(Memo memo, List<Block> blocks) async {
    if (!isConfigured) {
      debugPrint('[WebDAVStorage] uploadMemo(${memo.uuid}): NOT CONFIGURED');
      return null;
    }
    if (blocks.isEmpty) {
      debugPrint('[WebDAVStorage] uploadMemo(${memo.uuid}): no blocks, skip');
      return null;
    }

    final bytes = encodeRemoteMemo(
      memo,
      blocks,
      encryptionRequired: _encryptionEnabled,
    );
    final relativePath = _folderPath.isEmpty
        ? '${memo.uuid}.json'
        : '$_folderPath/${memo.uuid}.json';

    var attempt = 0;
    var backoff = const Duration(seconds: 2);
    while (true) {
      attempt++;
      try {
        await _ensureFolders();
        final response = await _client.put(
          _remoteUri(relativePath),
          headers: {
            ..._authHeaders(),
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );
        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 204) {
          debugPrint(
            '[WebDAVStorage] uploadMemo(${memo.uuid}): ${response.statusCode}, '
            'size=${bytes.length}, encrypted=${EncryptionService.instance.isEnabled}',
          );
          return relativePath;
        }
        throw Exception(
          'PUT ${response.statusCode}: ${response.body}',
        );
      } catch (e) {
        debugPrint(
          '[WebDAVStorage] uploadMemo(${memo.uuid}): attempt $attempt failed: $e',
        );
        if (attempt >= 3) rethrow;
        await Future.delayed(backoff);
        backoff *= 2;
      }
    }
  }

  @override
  Future<void> deleteMemo(String remoteFileId) async {
    if (!isConfigured) return;
    try {
      final response = await _client.delete(
        _remoteUri(remoteFileId),
        headers: _authHeaders(),
      );
      // 404 means it was already removed, which is the desired end state.
      if (response.statusCode != 204 &&
          response.statusCode != 200 &&
          response.statusCode != 404) {
        debugPrint(
          '[WebDAVStorage] deleteMemo($remoteFileId): ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[WebDAVStorage] error deleting $remoteFileId: $e');
    }
  }

  @override
  Future<List<RemoteMemoInfo>> listRemoteMemos() async {
    if (!isConfigured) return [];

    final response = await _davRequest(
      'PROPFIND',
      _folderUri(),
      headers: {..._authHeaders(), 'Depth': '1'},
    );

    // 404: the folder does not exist yet (first sync).
    if (response.statusCode == 404) return [];
    if (response.statusCode != 207 && response.statusCode != 200) {
      throw Exception(
        'Failed to list remote notes (${response.statusCode}): ${response.body}',
      );
    }

    final document = XmlDocument.parse(response.body);
    final notes = <RemoteMemoInfo>[];
    for (final element in document.findAllElements('response', namespace: '*')) {
      if (element.findAllElements('collection', namespace: '*').isNotEmpty) {
        continue; // the folder itself or a subfolder
      }
      final hrefs = element.findAllElements('href', namespace: '*');
      if (hrefs.isEmpty) continue;
      final name = _fileNameFromHref(hrefs.first.innerText.trim());
      if (name == null || !name.endsWith('.json')) continue;

      final modifiedElements = element.findAllElements(
        'getlastmodified',
        namespace: '*',
      );
      final modified = modifiedElements.isEmpty
          ? ''
          : modifiedElements.first.innerText.trim();
      DateTime updatedAt;
      try {
        updatedAt = modified.isEmpty ? DateTime.now() : HttpDate.parse(modified);
      } catch (_) {
        updatedAt = DateTime.now();
      }

      final remoteId = _folderPath.isEmpty ? name : '$_folderPath/$name';
      notes.add(
        RemoteMemoInfo(
          remoteFileId: remoteId,
          name: name,
          updatedAt: updatedAt,
        ),
      );
    }
    return notes;
  }

  /// Extracts the decoded file name from a PROPFIND `href`.
  String? _fileNameFromHref(String href) {
    String path;
    try {
      path = Uri.decodeFull(href);
    } catch (_) {
      path = href;
    }
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    return segments.last;
  }

  @override
  Future<RemoteMemo?> downloadMemo(String remoteFileId) async {
    if (!isConfigured) throw StateError('WebDAV is not configured');
    final response = await _client.get(
      _remoteUri(remoteFileId),
      headers: _authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to download note: ${response.statusCode}');
    }
    final result = decodeRemoteMemo(response.bodyBytes);
    if (result == null) {
      debugPrint(
        '[WebDAVStorage] downloadMemo($remoteFileId): decrypt/parse fail',
      );
    }
    return result;
  }
}
