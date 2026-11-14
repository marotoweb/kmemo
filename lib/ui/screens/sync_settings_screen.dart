// lib/ui/screens/sync_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../../services/encryption_service.dart';
import '../../services/kdrive_storage.dart';
import '../../services/storage_repository.dart';
import '../../services/webdav_storage.dart';
import '../widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  // Uses the same instance registered in main.dart (shared with MemoProvider)
  late final KDriveStorage _storage;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isClearingVersions = false;
  int _syncDone = 0;
  int _syncTotal = 0;

  // Configuration form state
  final _tokenController = TextEditingController();
  final _passphraseController = TextEditingController();
  String _selectedDriveId = '';
  String _selectedDriveName = '';
  String _selectedFolderId = '';
  String _selectedFolderName = '';
  String _remoteFolder = 'kmemo/notes';
  bool _encryptionEnabled = false;

  // Selected sync protocol: 'kdrive' or 'webdav'
  String _selectedProtocol = 'kdrive';

  // WebDAV form state
  late final WebDAVStorage _webdav;
  final _webdavUrlController = TextEditingController();
  final _webdavUserController = TextEditingController();
  final _webdavPasswordController = TextEditingController();
  final _webdavFolderController = TextEditingController();
  final _webdavPassphraseController = TextEditingController();
  bool _webdavEncryption = false;
  bool _webdavConfigured = false;
  bool _webdavBusy = false;

  // Discovered drives list
  List<Map<String, dynamic>> _drives = [];
  bool _isLoadingDrives = false;

  // Hierarchical folder navigation
  List<Map<String, dynamic>> _currentFolderContents = [];
  List<Map<String, dynamic>> _breadcrumb = [];
  String _currentFolderId =
      '5'; // '5' = Private folder (effective root where folders can be created)
  String _currentFolderName = 'Private';
  bool _isLoadingFolderContents = false;

  // Selected account (for listing drives)
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _storage = Provider.of<KDriveStorage>(context, listen: false);
    _webdav = Provider.of<WebDAVStorage>(context, listen: false);
    _loadWebdavValues();
    final active = Provider.of<MemoProvider>(context, listen: false).storage;
    _selectedProtocol =
        active?.storageName == 'WebDAV' ? kSyncBackendWebDav : kSyncBackendKDrive;
    debugPrint(
      '[SyncSettings] initState(): storage.isConfigured=${_storage.isConfigured}, '
      'driveId=${_storage.driveId}, remoteFolder=${_storage.remoteFolder}, '
      'encryptionEnabled=${_storage.encryptionEnabled}',
    );
    _loadPersistedValues();
    _isLoading = false;
    debugPrint(
      '[SyncSettings] initState() complete: _selectedDriveId=$_selectedDriveId, '
      '_remoteFolder=$_remoteFolder, _encryptionEnabled=$_encryptionEnabled, '
      '_drives.length=${_drives.length}',
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passphraseController.dispose();
    _webdavUrlController.dispose();
    _webdavUserController.dispose();
    _webdavPasswordController.dispose();
    _webdavFolderController.dispose();
    _webdavPassphraseController.dispose();
    // Do not close _storage: it is shared with MemoProvider
    super.dispose();
  }

  /// Loads persisted values from storage into the screen's local state.
  Future<void> _loadPersistedValues() async {
    debugPrint(
      '[SyncSettings] _loadPersistedValues(): storage.driveId=${_storage.driveId}, storage.remoteFolder="${_storage.remoteFolder}", storage.folderId="${_storage.folderId}", storage.folderName="${_storage.folderName}", storage.encryptionEnabled=${_storage.encryptionEnabled}',
    );
    if (_storage.driveId != null) {
      _selectedDriveId = _storage.driveId.toString();
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): set _selectedDriveId=$_selectedDriveId',
      );
    }
    _selectedFolderId = _storage.folderId ?? '';
    _selectedFolderName = _storage.folderName ?? '';
    if (_selectedFolderId.isEmpty) {
      _selectedFolderId = '5';
      _selectedFolderName = 'Private';
    }
    // Restore the persisted breadcrumb path
    _breadcrumb = _storage.folderPath
        .map((e) => <String, dynamic>{'id': e['id'], 'name': e['name']})
        .toList();
    _remoteFolder = _storage.remoteFolder;
    _encryptionEnabled = _storage.encryptionEnabled;
    debugPrint(
      '[SyncSettings] _loadPersistedValues(): set _remoteFolder="$_remoteFolder", _selectedFolderId=$_selectedFolderId, _selectedFolderName=$_selectedFolderName, _encryptionEnabled=$_encryptionEnabled',
    );

    // Read the token from secure storage to display in the field
    final token = await _storage.getStoredToken();
    if (token != null && token.isNotEmpty) {
      _tokenController.text = token;
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): token loaded from secure storage (length=${token.length})',
      );
    } else {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): no token saved',
      );
    }

    // If a drive is already selected, load drives and root folders
    if (_selectedDriveId.isNotEmpty) {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): drive already selected, discovering drives and loading root folders',
      );
      _selectedDriveId = _storage.driveId.toString();
      // Load drives to show the correct name in the UI
      if (_drives.isEmpty) {
        await _discoverAccountsAndDrives();
      }
      if (!mounted) return;
      // Show the persisted destination folder (or the Private root by default)
      if (_selectedFolderId.isNotEmpty && _selectedFolderId != '5') {
        await _loadFolderById(
          _selectedFolderId,
          _selectedFolderName.isNotEmpty
              ? _selectedFolderName
              : AppLocalizations.of(context)!.folderWord,
        );
      } else {
        await _loadRootFolders();
      }
    } else {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): no drive selected',
      );
    }
  }

  /// Saves the current configuration to storage (called after each user change).
  /// If [sync] is true, also performs an immediate sync.
  Future<void> _saveCurrentConfig({bool sync = false}) async {
    if (_tokenController.text.trim().isEmpty) {
      debugPrint('[SyncSettings] _saveCurrentConfig(): token empty, skipping');
      return;
    }
    if (_selectedDriveId.isEmpty) {
      debugPrint(
        '[SyncSettings] _saveCurrentConfig(): driveId empty, skipping',
      );
      return;
    }

    final drive = _drives.firstWhere(
      (d) => d['id'].toString() == _selectedDriveId,
      orElse: () => <String, dynamic>{},
    );

    debugPrint(
      '[SyncSettings] _saveCurrentConfig(): token=${_tokenController.text.trim().isEmpty ? 'empty' : 'set'}, driveId=$_selectedDriveId, folderId=$_selectedFolderId, remoteFolder="$_remoteFolder", encryptionEnabled=$_encryptionEnabled, passphrase=${_passphraseController.text.trim().isEmpty ? 'empty' : 'set'}',
    );
    try {
      // Check if encryption changed (enabled or disabled)
      final wasEncryptionEnabled = _storage.encryptionEnabled;
      final encryptionChanged = wasEncryptionEnabled != _encryptionEnabled;
      final wasServiceEnabled = EncryptionService.instance.isEnabled;
      final db = Provider.of<AppDatabase>(context, listen: false);

      await _storage.configure(
        token: _tokenController.text.trim(),
        driveId: int.parse(_selectedDriveId),
        driveName: drive['name'] as String? ?? 'kDrive',
        remoteFolder: _remoteFolder.isEmpty ? 'kmemo/notes' : _remoteFolder,
        folderId: _selectedFolderId.isNotEmpty ? _selectedFolderId : null,
        folderName: _selectedFolderName.isNotEmpty ? _selectedFolderName : null,
        encryptionEnabled: _encryptionEnabled,
        encryptionPassphrase: _encryptionEnabled
            ? _passphraseController.text.trim()
            : null,
      );

      // Re-upload every note when encryption changed, and also when the
      // passphrase was just restored (it was missing at start, so the notes
      // uploaded during that time are plain text on the remote storage).
      final passphraseRestored =
          _encryptionEnabled &&
          !wasServiceEnabled &&
          EncryptionService.instance.isEnabled;
      if (encryptionChanged || passphraseRestored) {
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): re-upload all notes '
          '(encryptionChanged=$encryptionChanged, '
          'passphraseRestored=$passphraseRestored)',
        );
        await db.customStatement(
          'UPDATE memos SET is_synced = 0, remote_file_id = NULL',
        );
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): all notes marked as not synced and remoteFileId cleared',
        );
      }
      // Only one backend may be configured at a time: activating kDrive
      // removes the WebDAV URL, credentials and passphrase.
      await _webdav.clearConfiguration();
      _resetWebdavForm();
      await _switchBackend(_storage);
      debugPrint(
        '[SyncSettings] _saveCurrentConfig(): configure() completed successfully',
      );

      // Optional immediate sync (uploads local notes and pulls remote ones)
      if (sync) {
        try {
          if (!mounted) return;
          setState(() {
            _isSyncing = true;
            _syncDone = 0;
            _syncTotal = 0;
          });
          final decryptionFailures = await _runSyncWithPrompts(force: true);
          if (decryptionFailures > 0 && mounted) {
            _showError(
              AppLocalizations.of(context)!.decryptionFailuresCount('$decryptionFailures'),
            );
          }
        } catch (e) {
          // Configuration is saved; sync failure does not block continuation
          debugPrint(
            '[SyncSettings] _saveCurrentConfig(): initial sync failed: $e',
          );
        } finally {
          if (mounted) {
            setState(() => _isSyncing = false);
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncSettings] _saveCurrentConfig(): error: $e');
      if (mounted) {
        _showError(AppLocalizations.of(context)!.configSaveError('$e'));
      }
    } finally {
      // _isConfiguring removed
    }
  }

  /// Formats the last sync date for display.
  String _formatLastSync() => _formatSyncDate(_storage.lastSync);

  String _formatWebdavLastSync() => _formatSyncDate(_webdav.lastSync);

  String _formatSyncDate(DateTime? last) {
    if (last == null) return AppLocalizations.of(context)!.lastSyncNever;
    final now = DateTime.now();
    final diff = now.difference(last);
    if (diff.inMinutes < 1) {
      return AppLocalizations.of(context)!.lastSyncJustNow;
    } else if (diff.inHours < 1) {
      return AppLocalizations.of(context)!.lastSyncMinutesAgo('${diff.inMinutes}');
    } else if (diff.inDays < 1) {
      return AppLocalizations.of(context)!.lastSyncHoursAgo('${diff.inHours}');
    } else {
      return '${last.day}/${last.month}/${last.year} ${last.hour}:${last.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Manual sync (push + pull) triggered by the user.
  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncDone = 0;
      _syncTotal = 0;
    });
    try {
      if (!mounted) return;
      // Ensure the current configuration is saved before syncing
      await _saveCurrentConfig(sync: false);
      if (!mounted) return;
      final decryptionFailures = await _runSyncWithPrompts(force: true);
      if (mounted) {
        setState(() => _isSyncing = false);
        if (decryptionFailures > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            buildAppSnackBar(
              context,
              message: AppLocalizations.of(context)!.syncPartialFailure(
                '$decryptionFailures',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        } else {
          final synced = Provider.of<MemoProvider>(
            context,
            listen: false,
          ).lastSyncNoteCount;
          ScaffoldMessenger.of(context).showSnackBar(
            buildAppSnackBar(
              context,
              message: AppLocalizations.of(context)!.syncCompletedWithCount(
                synced,
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showError(AppLocalizations.of(context)!.syncErrorWithDetail('$e'));
      }
    }
  }

  /// Deletes the kDrive version history of every note in the selected folder.
  ///
  /// Versioning itself stays on: each upload still keeps the previous content
  /// as a version. This is an explicit maintenance action for users who do not
  /// want old copies of their notes (including plain text written before
  /// encryption was enabled) kept on the remote server.
  Future<void> _clearOldVersions() async {
    if (_isSyncing || _isClearingVersions) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearOldVersionsTitle),
        content: Text(l10n.clearOldVersionsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isClearingVersions = true;
      _syncDone = 0;
      _syncTotal = 0;
    });
    try {
      final remoteMemos = await _storage.listRemoteMemos();
      if (!mounted) return;
      setState(() => _syncTotal = remoteMemos.length);

      var cleared = 0;
      for (var i = 0; i < remoteMemos.length; i++) {
        if (await _storage.clearVersions(remoteMemos[i].remoteFileId)) {
          cleared++;
        }
        if (!mounted) return;
        setState(() => _syncDone++);
        // The kDrive API allows 60 requests per minute. Pace the cleanup so a
        // folder with many notes does not hit the rate limit and fail midway.
        if (i < remoteMemos.length - 1) {
          await Future.delayed(const Duration(milliseconds: 1100));
          if (!mounted) return;
        }
      }

      if (!mounted) return;
      setState(() => _isClearingVersions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: l10n.clearOldVersionsDone(cleared),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isClearingVersions = false);
      _showError(l10n.clearOldVersionsError('$e'));
    }
  }

  /// Performs sync with passphrase prompts and confirmation of
  /// deletion for non-decryptable remote notes.
  Future<int> _runSyncWithPrompts({bool force = false}) async {
    final memoProvider = Provider.of<MemoProvider>(context, listen: false);
    return await memoProvider.performSync(
      force: force,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _syncDone = done;
          _syncTotal = total;
        });
      },
      requestPassphrase: (remoteFileId) async {
        // Prompt the user for a passphrase for this specific note.
        // The dialog owns its controller and disposes it when it leaves the
        // tree, avoiding the "_dependents.isEmpty" assertion that happened
        // when the controller was disposed right after showDialog returned.
        return await showDialog<String?>(
          context: context,
          builder: (ctx) => const _RequestPassphraseDialog(),
        );
      },
      confirmDeleteRemote: (remoteFileId) async {
        final delete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.couldNotDecrypt),
            content: Text(
              AppLocalizations.of(context)!.afterTwoAttempts,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.ignore),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.delete),
              ),
            ],
          ),
        );
        return delete == true;
      },
    );
  }

  Future<void> _logout() async {
    // Mark all notes as not synced in all states (Drift, memory)
    await Provider.of<MemoProvider>(context, listen: false).disableSync();
    await _storage.logout();
    if (mounted) {
      setState(() {
        _tokenController.clear();
        _selectedDriveId = '';
        _selectedDriveName = '';
        _drives = [];
        _selectedFolderId = '';
        _selectedFolderName = '';
        _remoteFolder = 'kmemo/notes';
        _currentFolderId = '5';
        _currentFolderName = 'Private';
        _currentFolderContents = [];
        _breadcrumb = [];
        _encryptionEnabled = false;
        _passphraseController.clear();
      });
    }
  }


  // -------------------------------------------------------------------
  // WebDAV
  // -------------------------------------------------------------------

  /// True when the WebDAV form has enough data to be saved (or to switch
  /// encryption): the same rule as the kDrive switch needing a token.
  bool get _canConfigureWebdav =>
      _webdavUrlController.text.trim().isNotEmpty &&
      _webdavUserController.text.trim().isNotEmpty &&
      (_webdav.hasPassword || _webdavPasswordController.text.isNotEmpty);

  /// Clears the kDrive form/state after its configuration was removed because
  /// WebDAV became the active backend.
  void _resetKdriveForm() {
    _tokenController.clear();
    _selectedDriveId = '';
    _selectedDriveName = '';
    _drives = [];
    _selectedFolderId = '';
    _selectedFolderName = '';
    _remoteFolder = 'kmemo/notes';
    _breadcrumb = [];
    _currentFolderContents = [];
    _currentFolderId = '5';
    _currentFolderName = 'Private';
    _encryptionEnabled = false;
    _passphraseController.clear();
  }

  /// Clears the WebDAV form/state after its configuration was removed because
  /// kDrive became the active backend.
  void _resetWebdavForm() {
    _webdavUrlController.clear();
    _webdavUserController.clear();
    _webdavPasswordController.clear();
    _webdavFolderController.clear();
    _webdavPassphraseController.clear();
    _webdavEncryption = false;
    _webdavConfigured = false;
  }

  void _loadWebdavValues() {
    _webdavUrlController.text = _webdav.baseUrl;
    _webdavUserController.text = _webdav.username;
    _webdavFolderController.text = _webdav.folder;
    _webdavEncryption = _webdav.encryptionEnabled;
    _webdavConfigured = _webdav.isConfigured;
  }

  /// Makes [storage] the backend used by the next sync.
  ///
  /// The backend being replaced has the only copies of the notes, so every
  /// note is marked as not synced: the new backend receives a full upload
  /// instead of staying empty.
  Future<void> _switchBackend(StorageRepository storage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kSyncBackendKey,
      storage.storageName == 'WebDAV' ? kSyncBackendWebDav : kSyncBackendKDrive,
    );
    if (!mounted) return;
    final provider = Provider.of<MemoProvider>(context, listen: false);
    if (provider.storage != storage) {
      await provider.disableSync();
      provider.useStorage(storage);
      debugPrint('[SyncSettings] switched backend to ${storage.storageName}');
    }
  }

  /// Same dialog as kDrive: passphrase + confirmation, validated add nothing
  /// is enabled until both match.
  Future<bool> _showWebdavPassphraseDialog() async {
    _webdavPassphraseController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PassphraseDialog(
        passphraseController: _webdavPassphraseController,
        dialogWidth: MediaQuery.of(context).size.width * 0.90,
      ),
    );
    return confirmed == true;
  }

  Future<void> _onWebdavEncryptionChanged(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (value) {
      // Ask for the passphrase (with confirmation) before enabling.
      if (!await _showWebdavPassphraseDialog()) return;
    } else {
      _webdavPassphraseController.clear();
    }
    if (!mounted) return;

    // Explain what happens to the remote copies before rewriting them.
    final enabling = value;
    final confirmedSync = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          enabling ? l10n.enableEncryptionTitle : l10n.disableEncryptionTitle,
        ),
        content: Text(
          enabling
              ? l10n.enableEncryptionMessage
              : l10n.disableEncryptionMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sync),
          ),
        ],
      ),
    );
    if (confirmedSync != true) return;
    if (!mounted) return;

    setState(() => _webdavEncryption = value);
    await _saveWebdav(sync: true);
  }

  Future<void> _testWebdav() async {
    final l10n = AppLocalizations.of(context)!;
    if (_webdavUrlController.text.trim().isEmpty ||
        _webdavUserController.text.trim().isEmpty ||
        (!_webdav.hasPassword && _webdavPasswordController.text.isEmpty)) {
      _showError(l10n.webdavMissingFields);
      return;
    }
    setState(() => _webdavBusy = true);
    try {
      await _webdav.testConnectionWith(
        baseUrl: _webdavUrlController.text,
        username: _webdavUserController.text,
        password: _webdavPasswordController.text,
        folder: _webdavFolderController.text,
      );
      if (!mounted) return;
      setState(() => _webdavBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: l10n.webdavConnectionOk,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _webdavBusy = false);
      _showError(l10n.webdavConnectionFailed('$e'));
    }
  }

  Future<bool> _saveWebdav({bool sync = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_webdavUrlController.text.trim().isEmpty ||
        _webdavUserController.text.trim().isEmpty ||
        (!_webdav.hasPassword && _webdavPasswordController.text.isEmpty)) {
      _showError(l10n.webdavMissingFields);
      return false;
    }

    setState(() => _webdavBusy = true);
    try {
      final provider = Provider.of<MemoProvider>(context, listen: false);
      final switching = provider.storage != _webdav;
      final wasConfigured = _webdav.isConfigured;
      final wasEncryption = _webdav.encryptionEnabled;
      final wasServiceEnabled = EncryptionService.instance.isEnabled;

      await _webdav.configure(
        baseUrl: _webdavUrlController.text,
        username: _webdavUserController.text,
        password: _webdavPasswordController.text,
        folder: _webdavFolderController.text,
        encryptionEnabled: _webdavEncryption,
        passphrase: _webdavPassphraseController.text,
      );

      // Only one backend may be configured at a time: activating WebDAV
      // removes the kDrive token, drive and folder.
      await _storage.logout();
      _resetKdriveForm();

      // A passphrase that was missing at start means the notes uploaded until
      // now are plain text on the remote storage (same rule as kDrive).
      final passphraseRestored =
          _webdavEncryption &&
          !wasServiceEnabled &&
          EncryptionService.instance.isEnabled;
      if (switching ||
          !wasConfigured ||
          wasEncryption != _webdavEncryption ||
          passphraseRestored) {
        await provider.disableSync();
      }
      await _switchBackend(_webdav);

      _webdavPasswordController.clear();
      _webdavPassphraseController.clear();
      // Reflect the normalised URL (scheme added, trailing slash) in the form.
      _webdavUrlController.text = _webdav.baseUrl;
      if (!mounted) return true;
      setState(() {
        _webdavBusy = false;
        _webdavConfigured = _webdav.isConfigured;
        _webdavEncryption = _webdav.encryptionEnabled;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: l10n.webdavConfigurationSaved,
          backgroundColor: Colors.green,
        ),
      );
      if (sync) await _syncWebdavNow();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _webdavBusy = false);
        _showError(l10n.syncErrorWithDetail('$e'));
      }
      return false;
    }
  }

  Future<void> _syncWebdavNow() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncDone = 0;
      _syncTotal = 0;
    });
    try {
      final decryptionFailures = await _runSyncWithPrompts(force: true);
      if (!mounted) return;
      setState(() => _isSyncing = false);
      final l10n = AppLocalizations.of(context)!;
      if (decryptionFailures > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            context,
            message: l10n.syncPartialFailure('$decryptionFailures'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
          ),
        );
      } else {
        final synced = Provider.of<MemoProvider>(
          context,
          listen: false,
        ).lastSyncNoteCount;
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            context,
            message: l10n.syncCompletedWithCount(synced),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showError(AppLocalizations.of(context)!.syncErrorWithDetail('$e'));
      }
    }
  }

  Future<void> _removeWebdav() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.webdavRemoveConfiguration),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _webdav.clearConfiguration();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSyncBackendKey, kSyncBackendKDrive);
    if (!mounted) return;
    // Nothing is configured now: keep kDrive as the selected protocol so the
    // next configuration starts from a clean form.
    Provider.of<MemoProvider>(context, listen: false).useStorage(_storage);
    setState(_resetWebdavForm);
  }

  List<Widget> _buildWebdavSection(bool isDarkMode) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = isDarkMode
        ? const Color(0xFF1E1E1E)
        : Colors.grey.shade100;
    final borderColor = isDarkMode
        ? Colors.grey.shade800
        : Colors.grey.shade300;

    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    Widget field(
      TextEditingController controller,
      String label, {
      bool obscure = false,
      String? hint,
      TextInputType? keyboardType,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        // Rebuild so the encryption switch enables as soon as the form has
        // URL + username + password (same rule as kDrive needing a token).
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return [
      // Mirrors the kDrive status card: same colours, same active/inactive
      // wording and the same lines (server, folder, encryption, last sync).
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _webdavConfigured
              ? cardColor
              : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _webdavConfigured ? Icons.cloud_done : Icons.cloud_off,
                  color: isDarkMode
                      ? Colors.amber.shade300
                      : Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  _webdavConfigured
                      ? l10n.activeSyncTitle
                      : l10n.inactiveSyncTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _webdavConfigured
                        ? Colors.amber.shade700
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_webdavConfigured) ...[
              Text(
                '${l10n.webdavServerUrl}: ${_webdav.baseUrl}\n'
                '${l10n.destinationFolder}: ${_webdav.folder}\n'
                '${l10n.encryption}: ${_webdavEncryption ? l10n.active : l10n.inactive}\n'
                '${l10n.lastSync}: ${_formatWebdavLastSync()}',
                style: const TextStyle(fontSize: 13),
              ),
            ] else
              Text(
                l10n.configureRemoteStorage,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      card([
        field(
          _webdavUrlController,
          l10n.webdavServerUrl,
          hint: l10n.webdavServerUrlHint,
          keyboardType: TextInputType.url,
        ),
        field(_webdavUserController, l10n.webdavUsername),
        field(
          _webdavPasswordController,
          l10n.webdavPassword,
          obscure: true,
          hint: l10n.webdavPasswordKeepHint,
        ),
        field(_webdavFolderController, l10n.webdavFolderLabel),
        const Divider(height: 24),
        // Same control and same passphrase dialog as kDrive.
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.encryptNotes),
          subtitle: Text(
            l10n.encryptNotesOnClient,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Switch(
            value: _webdavEncryption,
            onChanged: (_webdavBusy || _isSyncing || !_canConfigureWebdav)
                ? null
                : _onWebdavEncryptionChanged,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          onPressed: _webdavBusy ? null : _testWebdav,
          icon: const Icon(Icons.wifi_tethering),
          label: Text(l10n.webdavTestConnection),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _webdavBusy ? null : () => _saveWebdav(),
          icon: _webdavBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(l10n.save),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: (_isSyncing || !_webdavConfigured)
              ? null
              : _syncWebdavNow,
          icon: _isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(
            _isSyncing ? l10n.syncingNow : l10n.syncNowButton,
          ),
        ),
      ),
      if (_webdavConfigured) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _webdavBusy ? null : _removeWebdav,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.webdavRemoveConfiguration),
          ),
        ),
      ],
    ];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(
        context,
        message: message,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final configured = _storage.isConfigured;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.syncTitle), elevation: 0),
      bottomNavigationBar: (_isSyncing || _isClearingVersions)
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isClearingVersions
                              ? AppLocalizations.of(context)!.clearingVersions
                              : AppLocalizations.of(context)!.syncingNow,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _syncTotal > 0
                              ? _syncDone / _syncTotal
                              : null,
                        ),
                        SizedBox(height: 6),
                        Text(
                          '$_syncDone / $_syncTotal',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.0).copyWith(bottom: 100),
              children: [
                Center(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'kdrive',
                        label: Text('kDrive'),
                        icon: Icon(Icons.cloud),
                      ),
                      ButtonSegment<String>(
                        value: 'webdav',
                        label: Text('WebDAV'),
                        icon: Icon(Icons.storage),
                      ),
                    ],
                    selected: {_selectedProtocol},
                    onSelectionChanged: (selected) {
                      setState(() => _selectedProtocol = selected.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                if (_selectedProtocol == 'kdrive') ...[
                  // Current status
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: configured
                          ? (isDarkMode
                                ? Color(0xFF1E1E1E) // Configured + Dark
                                : Colors.grey.shade100) // Configured + Light
                          : (isDarkMode
                                ? Color(
                                    0xFF2C2C2C,
                                  ) // Not configured + Dark (example)
                                : Colors
                                      .white), // Not configured + Light (example)
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              configured ? Icons.cloud_done : Icons.cloud_off,
                              color: isDarkMode
                                  ? Colors.amber.shade300
                                  : Colors.amber.shade700,
                            ),
                            SizedBox(width: 8),
                            Text(
                              configured
                                  ? AppLocalizations.of(context)!.activeSyncTitle
                                  : AppLocalizations.of(context)!.inactiveSyncTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: configured
                                    ? Colors.amber.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (configured) ...[
                          Text(
                            '${AppLocalizations.of(context)!.drive}: ${_storage.storageName}\n'
                            '${AppLocalizations.of(context)!.destinationFolder}: $_selectedFolderName\n'
                            '${AppLocalizations.of(context)!.encryption}: ${_encryptionEnabled ? AppLocalizations.of(context)!.active : AppLocalizations.of(context)!.inactive}\n'
                            '${AppLocalizations.of(context)!.lastSync}: ${_formatLastSync()}',
                            style: TextStyle(fontSize: 13),
                          ),
                        ] else
                          Text(
                            AppLocalizations.of(context)!.configureRemoteStorage,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Configuration section
                  Text(
                    AppLocalizations.of(context)!.configureRemoteSection,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Color(0xFF1E1E1E)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        // token
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.infomaniakToken),
                          subtitle: Text(
                            AppLocalizations.of(context)!.generateTokenAtManager,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: _editToken,
                        ),
                        Divider(
                          height: 1,
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),

                        // drive
                        if (_isLoadingDrives)
                          ListTile(
                            title: Text(AppLocalizations.of(context)!.discoveringDrives),
                            trailing: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_tokenController.text.isNotEmpty &&
                            _drives.isEmpty)
                          ListTile(
                            title: Text(AppLocalizations.of(context)!.kdriveDrive),
                            subtitle: Text(
                              AppLocalizations.of(context)!.noKdriveInAccount,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                            trailing: Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            onTap: null,
                          )
                        else
                          ListTile(
                            title: Text(AppLocalizations.of(context)!.kdriveDrive),
                            subtitle: Text(
                              _selectedDriveId.isEmpty
                                  ? AppLocalizations.of(context)!.selectDrive
                                  : '$_selectedDriveName ($_selectedDriveId)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: _selectDrive,
                          ),
                        Divider(
                          height: 1,
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),

                        // Destination folder inside the drive
                        if (_selectedDriveId.isNotEmpty) ...[
                          if (_isLoadingFolderContents)
                            ListTile(
                              title: Text(AppLocalizations.of(context)!.discoveringFolders),
                              trailing: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            _buildDestinationFolderSection(isDarkMode),
                          Divider(
                            height: 1,
                            color: isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                        ],

                        // Encryption
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.encryptNotes),
                          subtitle: Text(
                            AppLocalizations.of(context)!.encryptNotesOnClient,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Switch(
                            value: _encryptionEnabled,
                            // Uses the theme primary (vivid amber) so the
                            // toggle matches every other control in both
                            // light and dark mode.
                            // Without a token there is nothing to configure,
                            // so the switch stays disabled (WebDAV works the
                            // same way until its own fields are filled).
                            onChanged:
                                _isSyncing ||
                                    _tokenController.text.trim().isEmpty
                                ? null
                                : (value) async {
                              if (value) {
                                // Prompt for passphrase before enabling
                                final confirmed = await _showPassphraseDialog();
                                if (!confirmed) {
                                  // User cancelled, do not enable
                                  return;
                                }
                              } else {
                                // Disable encryption and clear passphrase
                                _passphraseController.clear();
                              }

                              if (!context.mounted) return;

                              // Explain exactly what will happen before
                              // replacing local/remote notes.
                              final l10n = AppLocalizations.of(context)!;
                              final enabling = value;
                              // Ask the user whether to sync all notes
                              // ignore: use_build_context_synchronously
                              final confirmedSync = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    enabling
                                        ? l10n.enableEncryptionTitle
                                        : l10n.disableEncryptionTitle,
                                  ),
                                  content: Text(
                                    enabling
                                        ? l10n.enableEncryptionMessage
                                        : l10n.disableEncryptionMessage,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(AppLocalizations.of(context)!.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(AppLocalizations.of(context)!.sync),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmedSync != true) {
                                // User cancelled, do not change encryption
                                return;
                              }

                              if (mounted) {
                                setState(() => _encryptionEnabled = value);
                                await _saveCurrentConfig(
                                  sync: confirmedSync == true,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Maintenance: version history is kept by default, but it
                  // can be cleared explicitly (e.g. after enabling encryption,
                  // so older plain-text copies stop living on the server).
                  if (configured) ...[
                    Text(
                      AppLocalizations.of(context)!.maintenanceSection,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Color(0xFF1E1E1E)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.history_toggle_off),
                        title: Text(
                          AppLocalizations.of(context)!.clearOldVersions,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.clearOldVersionsSubtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: _isSyncing || _isClearingVersions
                            ? null
                            : _clearOldVersions,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                ] else ...[
                  ..._buildWebdavSection(isDarkMode),
                ],
                // Action buttons
                if (_selectedProtocol == 'kdrive' && !configured) ...[
                  // If not configured, show instructions (kDrive only)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: configured
                          ? (isDarkMode
                                ? Color(0xFF1E1E1E) // Configured + Dark
                                : Colors.grey.shade100) // Configured + Light
                          : (isDarkMode
                                ? Color(
                                    0xFF2C2C2C,
                                  ) // Not configured + Dark (example)
                                : Colors
                                      .white), // Not configured + Light (example)
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.stepsToConfigure,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.step1EnterToken,
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          AppLocalizations.of(context)!.step2SelectDrive,
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          AppLocalizations.of(context)!.step3SelectFolder,
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          AppLocalizations.of(context)!.step4ClickSync,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ] else if (_selectedProtocol == 'kdrive') ...[
                  // Manual sync (push + pull)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing || _isClearingVersions
                          ? null
                          : _syncNow,
                      icon: _isSyncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.sync),
                      label: Text(
                        _isSyncing ? AppLocalizations.of(context)!.syncingNow : AppLocalizations.of(context)!.syncNowButton,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout),
                      label: Text(AppLocalizations.of(context)!.disableSync),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Destination folder selection section with hierarchical navigation
  Widget _buildDestinationFolderSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs
        if (_breadcrumb.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 4,
              children: _breadcrumb.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isLast = idx == _breadcrumb.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (idx > 0)
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.grey,
                      ),
                    GestureDetector(
                      onTap: isLast
                          ? null
                          : () => _navigateToFolder(item['id'], item['name']),
                      child: Text(
                        item['name'] ?? AppLocalizations.of(context)!.folderWord,
                        style: TextStyle(
                          fontSize: 12,
                          color: isLast ? Colors.amber : Colors.blue,
                          fontWeight: isLast
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        // Current folder title
        ListTile(
          title: Text(
            _currentFolderName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            _selectedFolderId.isNotEmpty
                ? AppLocalizations.of(context)!.selectedFolder(_selectedFolderName)
                : AppLocalizations.of(context)!.selectFolderToStoreNotes,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: _selectedFolderId.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.green)
              : null,
        ),
        Divider(
          height: 1,
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        // Current folder contents
        if (_isLoadingFolderContents)
          Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_currentFolderContents.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.emptyFolder,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _currentFolderContents.length,
            itemBuilder: (ctx, index) {
              final item = _currentFolderContents[index];
              final rawType = item['type']?.toString() ?? '';
              // Treat as folder any item that is not clearly a file
              // (the kDrive API may return various types for folders)
              final isNotFile =
                  (rawType.toLowerCase() != 'file' &&
                  rawType.toLowerCase() != 'document' &&
                  rawType.toLowerCase() != 'note');
              final isFolder = isNotFile || rawType.isEmpty;
              return ListTile(
                leading: Icon(
                  isFolder ? Icons.folder : Icons.description,
                  color: isFolder ? Colors.amber : Colors.grey,
                ),
                title: Text(item['name'] ?? AppLocalizations.of(context)!.itemWord),
                subtitle: Text(
                  isFolder
                      ? AppLocalizations.of(context)!.folderIdLabel('${item['id']}')
                      : AppLocalizations.of(context)!.fileIdLabel('${item['id']}'),
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: _selectedFolderId == item['id'].toString()
                    ? Icon(Icons.check, color: Colors.amber)
                    : null,
                onTap: () {
                  final folderId = item['id']?.toString() ?? '';
                  final folderName = item['name']?.toString() ?? AppLocalizations.of(context)!.itemWord;
                  debugPrint(
                    '[SyncSettings] onTap: id=$folderId, name=$folderName, isFolder=$isFolder',
                  );
                  if (isFolder && folderId.isNotEmpty) {
                    // Navigate into the folder
                    _navigateToFolder(folderId, folderName);
                  } else {
                    // Selecting a file does not make sense for storing notes
                    _showError(
                      AppLocalizations.of(context)!.cannotCreateInFile(rawType),
                    );
                  }
                },
              );
            },
          ),
        // Button to create a new folder (always allowed, including at root)
        if (_currentFolderId.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoadingFolderContents
                  ? null
                  : _showCreateFolderDialog,
              icon: Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.of(context)!.createNewFolder),
            ),
          ),
      ],
    );
  }

  /// Navigates to the specific folder and sets it as the destination folder.
  Future<void> _navigateToFolder(String folderId, String folderName) async {
    debugPrint(
      '[SyncSettings] _navigateToFolder called: id=$folderId, name=$folderName',
    );
    setState(() => _isLoadingFolderContents = true);
    try {
      // If already in this folder, do not add to breadcrumb again
      if (_currentFolderId != folderId) {
        // Add to breadcrumb only if not a duplicate of the previous entry
        if (_breadcrumb.isEmpty || _breadcrumb.last['id'] != _currentFolderId) {
          _breadcrumb.add({'id': _currentFolderId, 'name': _currentFolderName});
        }
        // Remove consecutive duplicate entries
        while (_breadcrumb.length > 1 &&
            _breadcrumb[_breadcrumb.length - 1]['id'] ==
                _breadcrumb[_breadcrumb.length - 2]['id']) {
          _breadcrumb.removeLast();
        }
      }
      _currentFolderId = folderId;
      _currentFolderName = folderName;
      // Set this folder as the destination for storing notes
      _selectedFolderId = folderId;
      _selectedFolderName = folderName;

      debugPrint(
        '[SyncSettings] _navigateToFolder: calling listFolderContents($folderId)',
      );
      final contents = await _storage.listFolderContents(folderId);
      debugPrint(
        '[SyncSettings] _navigateToFolder: got ${contents.length} items',
      );
      if (mounted) {
        setState(() {
          _currentFolderContents = contents;
          _isLoadingFolderContents = false;
        });
      }
      // Persist the breadcrumb path of the selected folder
      await _storage.setFolderPath(_breadcrumb);
      // Save the selected folder as destination persistently (without sync)
      debugPrint(
        '[SyncSettings] _navigateToFolder: calling _saveCurrentConfig(sync: false)',
      );
      await _saveCurrentConfig(sync: false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFolderContents = false);
        _showError(AppLocalizations.of(context)!.errorListingFolder('$e'));
      }
    }
  }

  /// Shows dialog to create a new folder
  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    // When at the kDrive root (id=1), the API does not allow creating folders
    // directly; redirect into the "Private" folder (or the first available).
    String createParentId = _currentFolderId;
    String createParentName = _currentFolderName;
    if (_currentFolderId == '1' && _currentFolderContents.isNotEmpty) {
      final privateFolder = _currentFolderContents.firstWhere(
        (f) => (f['name'] as String?)?.toLowerCase() == 'private',
        orElse: () => _currentFolderContents.first,
      );
      createParentId = privateFolder['id']?.toString() ?? '1';
      createParentName = privateFolder['name'] as String? ?? _currentFolderName;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.createNewFolder),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.createInFolder(createParentName),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.newFolderName,
                    labelText: AppLocalizations.of(context)!.folderName,
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    buildAppSnackBar(
                      context,
                      message: AppLocalizations.of(context)!.enterFolderName,
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  final newFolderId = await _storage.createDirectory(
                    createParentId,
                    name,
                  );
                  if (mounted) {
                    setState(() {
                      // Add the new folder to the current list
                      _currentFolderContents.add({
                        'id': newFolderId,
                        'name': name,
                        'type': 'directory',
                      });
                    });
                    // Automatically select the new folder as destination
                    setState(() {
                      _selectedFolderId = newFolderId ?? '';
                      _selectedFolderName = name;
                    });
                    await _saveCurrentConfig();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        buildAppSnackBar(
                          context,
                          message: AppLocalizations.of(context)!.folderCreatedSuccessfully,
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _showError(
                      AppLocalizations.of(context)!.errorCreatingFolderIn(_currentFolderName, '$e'),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.create),
            ),
          ],
        );
      },
    );
  }

  /// Builds the informational chip for an Infomaniak API scope.
  Widget _buildScopeChip(String scope, String description) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.amber.shade700),
          SizedBox(width: 6),
          Text(
            scope,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
          SizedBox(width: 6),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _editToken() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool showToken = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.infomaniakToken),
            insetPadding: EdgeInsets.symmetric(horizontal: 24),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.generateTokenWithScopes,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildScopeChip('drive', AppLocalizations.of(context)!.scopeDrive),
                      _buildScopeChip('user_info', AppLocalizations.of(context)!.scopeUserInfo),
                      _buildScopeChip('accounts', AppLocalizations.of(context)!.scopeAccounts),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.pasteTokenHere,
                      suffixIcon: IconButton(
                        icon: Icon(
                          showToken ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDialogState(() => showToken = !showToken),
                      ),
                    ),
                    maxLines: 1,
                    obscureText: !showToken,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context)!.ok),
              ),
            ],
          ),
        );
      },
    );
    if (_tokenController.text.isNotEmpty) {
      debugPrint(
        '[SyncSettings] _editToken(): saving token (length=${_tokenController.text.trim().length}) and discovering drives',
      );
      await _storage.setToken(_tokenController.text.trim());
      await _discoverAccountsAndDrives();
      // Do not sync automatically: the user must choose the folder and click "sync".
    } else {
      debugPrint('[SyncSettings] _editToken(): token empty, skipping');
    }
  }

  /// Lists the user's accounts, selects the first one and lists drives.
  Future<void> _discoverAccountsAndDrives() async {
    setState(() => _isLoadingDrives = true);
    try {
      final accounts = await _storage.listAccounts();
      if (mounted) {
        setState(() {
          // Automatically select the first account
          if (accounts.isNotEmpty) {
            _selectedAccountId =
                int.tryParse(accounts[0]['id'].toString()) ?? 0;
          } else {
            _selectedAccountId = null;
          }
        });
      }
      if (_selectedAccountId != null && _selectedAccountId! > 0) {
        final drives = await _storage.listDrives(_selectedAccountId!);
        String? autoSelectedId;
        String? autoSelectedName;
        if (drives.length == 1) {
          autoSelectedId = drives[0]['id']?.toString();
          autoSelectedName = drives[0]['name'] as String? ?? 'kDrive';
        }
        if (mounted) {
          setState(() {
            _drives = drives;
            if (autoSelectedId != null) {
              _selectedDriveId = autoSelectedId;
              _selectedDriveName = autoSelectedName ?? '';
            }
            _isLoadingDrives = false;
          });
          if (drives.isEmpty) {
            _showError(
              AppLocalizations.of(context)!.noKdriveInAccount,
            );
          } else if (autoSelectedId != null) {
            // Pre-selected the drive: save driveId
            await _storage.setDriveId(int.parse(autoSelectedId));
            // Load the root folders of the pre-selected drive
            await _loadRootFolders();
            // Do not sync automatically: the user must choose the folder and click "sync".
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingDrives = false);
          _showError(
            AppLocalizations.of(context)!.noValidAccount,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDrives = false);
        _showError(AppLocalizations.of(context)!.errorDiscoveringAccounts('$e'));
      }
    }
  }

  Future<void> _selectDrive() async {
    if (_drives.isEmpty) {
      await _discoverAccountsAndDrives();
      return;
    }
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.chooseKdriveDrive),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _drives.length,
              itemBuilder: (ctx, index) {
                final drive = _drives[index];
                final isSelected = drive['id'].toString() == _selectedDriveId;
                return ListTile(
                  title: Text(drive['name'] as String? ?? AppLocalizations.of(context)!.drive),
                  subtitle: Text(AppLocalizations.of(context)!.idLabel('${drive['id']}')),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Colors.amber)
                      : null,
                  onTap: () async {
                    debugPrint(
                      '[SyncSettings] _selectDrive(): selected drive id=${drive['id']}, name=${drive['name']}',
                    );
                    setState(() {
                      _selectedDriveId = drive['id'].toString();
                      _selectedDriveName = drive['name'] as String? ?? '';
                      _selectedFolderId = '';
                      _selectedFolderName = '';
                      _currentFolderId = '5';
                      _currentFolderName = 'Private';
                      _currentFolderContents = [];
                      _breadcrumb = [];
                    });
                    Navigator.pop(dialogContext);
                    await _storage.setDriveId(
                      int.parse(drive['id'].toString()),
                    );
                    await _loadRootFolders();
                    if (_tokenController.text.isNotEmpty) {
                      await _saveCurrentConfig(sync: false);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  /// Loads the contents of the specific folder by id (used when reopening the page).
  Future<void> _loadFolderById(String folderId, String folderName) async {
    setState(() => _isLoadingFolderContents = true);
    try {
      final contents = await _storage.listFolderContents(folderId);
      if (mounted) {
        setState(() {
          _currentFolderContents = contents;
          _currentFolderId = folderId;
          _currentFolderName = folderName;
          // Keep the persisted breadcrumb (do not overwrite)
          _isLoadingFolderContents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFolderContents = false);
        _showError(AppLocalizations.of(context)!.errorListingFolder('$e'));
      }
    }
  }

  /// Loads the contents of the Private folder (id: 5) — the effective root where folders can be created.
  Future<void> _loadRootFolders() async {
    setState(() => _isLoadingFolderContents = true);
    try {
      // List contents of the Private folder (id=5) instead of the kDrive root (id=1)
      // because the API does not allow creating folders directly at the root
      final contents = await _storage.listFolderContents('5');
      if (mounted) {
        setState(() {
          _currentFolderContents = contents;
          _currentFolderId = '5';
          _currentFolderName = 'Private';
          _breadcrumb = [];
          _isLoadingFolderContents = false;
          // Default destination folder: Private (id=5)
          if (_selectedFolderId.isEmpty) {
            _selectedFolderId = '5';
            _selectedFolderName = 'Private';
          }
        });
        if (contents.isEmpty) {
          _showError(AppLocalizations.of(context)!.privateFolderEmpty);
        }
        if (_tokenController.text.isNotEmpty) {
          await _saveCurrentConfig(sync: false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFolderContents = false);
        _showError(AppLocalizations.of(context)!.errorListingPrivateFolder('$e'));
      }
    }
  }

  /// Passphrase dialog with confirmation and visibility toggle.
  /// Returns true if the user confirmed, false if cancelled.
  Future<bool> _showPassphraseDialog() async {
    _passphraseController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PassphraseDialog(
        passphraseController: _passphraseController,
        dialogWidth: MediaQuery.of(context).size.width * 0.90,
      ),
    );
    return confirmed == true;
  }
}

/// Passphrase dialog with confirmation and visibility toggle.
class _PassphraseDialog extends StatefulWidget {
  final TextEditingController passphraseController;
  final double dialogWidth;

  const _PassphraseDialog({
    required this.passphraseController,
    required this.dialogWidth,
  });

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _confirmController = TextEditingController();
  bool _showPassphrase = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.encryptionPassphrase),
      content: SizedBox(
        width: widget.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.definePassphrase,
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 16),
            TextField(
              controller: widget.passphraseController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.passphrase,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassphrase ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassphrase = !_showPassphrase),
                ),
              ),
              obscureText: !_showPassphrase,
              maxLines: 1,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.confirmPassphrase,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassphrase ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassphrase = !_showPassphrase),
                ),
              ),
              obscureText: !_showPassphrase,
              maxLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: () {
            if (widget.passphraseController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                buildAppSnackBar(
                  context,
                  message: AppLocalizations.of(context)!.enterPassphrase,
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (widget.passphraseController.text != _confirmController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                buildAppSnackBar(
                  context,
                  message: AppLocalizations.of(context)!.passphrasesDoNotMatch,
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context, true);
          },
          child: Text(AppLocalizations.of(context)!.confirm),
        ),
      ],
    );
  }
}

/// Asks the user for the passphrase of a single encrypted remote note.
///
/// The dialog owns its [TextEditingController] so it is only disposed after
/// the route has been removed from the tree.
class _RequestPassphraseDialog extends StatefulWidget {
  const _RequestPassphraseDialog();

  @override
  State<_RequestPassphraseDialog> createState() =>
      _RequestPassphraseDialogState();
}

class _RequestPassphraseDialogState extends State<_RequestPassphraseDialog> {
  final _controller = TextEditingController();
  bool _showPassphrase = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.noteEncryptedInCloud),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.thisNoteIsEncryptedInCloud,
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.passphrase,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassphrase ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassphrase = !_showPassphrase),
                ),
              ),
              obscureText: !_showPassphrase,
              maxLines: 1,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(AppLocalizations.of(context)!.ignore),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.pop(context, text.isEmpty ? null : text);
          },
          child: Text(AppLocalizations.of(context)!.confirm),
        ),
      ],
    );
  }
}
