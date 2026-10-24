// lib/ui/screens/sync_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../../services/kdrive_storage.dart';
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

  // Configuration form state
  final _tokenController = TextEditingController();
  final _passphraseController = TextEditingController();
  String _selectedDriveId = '';
  String _selectedDriveName = '';
  String _selectedFolderId = '';
  String _selectedFolderName = '';
  String _remoteFolder = 'kmemo/notes';
  bool _encryptionEnabled = false;

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
        '[SyncSettings] _loadPersistedValues(): token loaded of secure storage (length=${token.length})',
      );
    } else {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): nenhum token saved',
      );
    }

    // If a drive is already selected, load drives and root folders
    if (_selectedDriveId.isNotEmpty) {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): drive já selected, discovering drives and loading folders of root',
      );
      _selectedDriveId = _storage.driveId.toString();
      // Load drives to show the correct name in the UI
      if (_drives.isEmpty) {
        await _discoverAccountsAndDrives();
      }
      // Show the persisted destination folder (or the Private root by default)
      if (_selectedFolderId.isNotEmpty && _selectedFolderId != '5') {
        await _loadFolderById(
          _selectedFolderId,
          _selectedFolderName.isNotEmpty ? _selectedFolderName : 'Pasta',
        );
      } else {
        await _loadRootFolders();
      }
    } else {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): without drive selected',
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
      '[SyncSettings] _saveCurrentConfig(): token_length=${_tokenController.text.trim().length}, driveId=$_selectedDriveId, folderId=$_selectedFolderId, remoteFolder="$_remoteFolder", encryptionEnabled=$_encryptionEnabled, passphrase_length=${_passphraseController.text.trim().length}',
    );
    try {
      // Check if encryption changed (enabled or disabled)
      final wasEncryptionEnabled = _storage.encryptionEnabled;
      final encryptionChanged = wasEncryptionEnabled != _encryptionEnabled;

      // If encryption changed, mark all notes as not synced
      // so they are re-uploaded with/without encryption
      if (encryptionChanged) {
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): encriptação mudou ($wasEncryptionEnabled -> $_encryptionEnabled), marcando all the notes como não sincronizadas',
        );
        final db = Provider.of<AppDatabase>(context, listen: false);
        await db.customStatement(
          'UPDATE memos SET is_synced = 0, remote_file_id = NULL',
        );
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): all the notes marcadas como não sincronizadas and remoteFileId limpo',
        );
      }

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
      debugPrint(
        '[SyncSettings] _saveCurrentConfig(): configure() completed successfully',
      );

      // Optional immediate sync (uploads local notes and pulls remote ones)
      if (sync) {
        try {
          if (!mounted) return;
          final decryptionFailures = await _runSyncWithPrompts(force: true);
          if (decryptionFailures > 0 && mounted) {
            _showError(
              '$decryptionFailures ficheiro(s) não puderam ser desencriptados. Verifique a passphrase.',
            );
          }
        } catch (e) {
          // Configuration is saved; sync failure does not block continuation
          debugPrint(
            '[SyncSettings] _saveCurrentConfig(): sync inicial failed: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[SyncSettings] _saveCurrentConfig(): error: $e');
      if (mounted) {
        _showError('Error saving configuration: $e');
      }
    } finally {
      // _isConfiguring removed
    }
  }

  /// Formats the last sync date for display.
  String _formatLastSync() {
    final last = _storage.lastSync;
    if (last == null) return 'Nunca';
    final now = DateTime.now();
    final diff = now.difference(last);
    if (diff.inMinutes < 1) {
      return 'Agora há pouco';
    } else if (diff.inHours < 1) {
      return 'Há ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Há ${diff.inHours} h';
    } else {
      return '${last.day}/${last.month}/${last.year} ${last.hour}:${last.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Manual sync (push + pull) triggered by the user.
  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
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
            SnackBar(
              content: Text(
                'Sync completed, but $decryptionFailures file(s) could not be decrypted. '
                'Check that the passphrase is correct.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.syncCompleted),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showError('Sync error: $e');
      }
    }
  }

  /// Performs sync with passphrase prompts and confirmation of
  /// deletion for non-decryptable remote notes.
  Future<int> _runSyncWithPrompts({bool force = false}) async {
    final memoProvider = Provider.of<MemoProvider>(context, listen: false);
    return await memoProvider.performSync(
      force: force,
      requestPassphrase: (remoteFileId) async {
        // Prompt the user for a passphrase for this specific note
        final controller = TextEditingController();
        final result = await showDialog<String?>(
          context: context,
          builder: (ctx) => AlertDialog(
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
                    controller: controller,
                    decoration: InputDecoration(hintText: 'Passphrase'),
                    obscureText: true,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(AppLocalizations.of(context)!.ignore),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(AppLocalizations.of(context)!.confirm),
              ),
            ],
          ),
        );
        controller.dispose();
        return (result != null && result.isNotEmpty) ? result : null;
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final configured = _storage.isConfigured;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.syncTitle), elevation: 0),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.0).copyWith(bottom: 100),
              children: [
                // Estado atual
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: configured
                        ? (isDarkMode
                              ? Color(0xFF1E1E1E) // Configurado + Dark
                              : Colors.grey.shade100) // Configurado + Light
                        : (isDarkMode
                              ? Color(
                                  0xFF2C2C2C,
                                ) // Não configurado + Dark (exemplo)
                              : Colors
                                    .white), // Não configurado + Light (exemplo)
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
                                ? 'Sincronização ativa'
                                : 'Sincronização desativada',
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

                // Secção of configuração
                Text(
                  'CONFIGURAR ARMAZENAMENTO REMOTO',
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
                                ? 'Selecione um drive'
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

                      // Encriptação
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.encryptNotes),
                        subtitle: Text(
                          AppLocalizations.of(context)!.encryptNotesOnClient,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Switch(
                          value: _encryptionEnabled,
                          activeThumbColor: isDarkMode
                              ? Colors.amber.shade300
                              : Colors.amber.shade700,
                          activeTrackColor:
                              (isDarkMode
                                      ? Colors.amber.shade300
                                      : Colors.amber.shade700)
                                  .withValues(alpha: 0.5),
                          onChanged: (value) async {
                            if (value) {
                              // Pedir passphrase antes of ativar
                              final confirmed = await _showPassphraseDialog();
                              if (!confirmed) {
                                // user cancelou, não ativar
                                return;
                              }
                            } else {
                              // Desativar encriptação and limpar passphrase
                              _passphraseController.clear();
                            }

                            if (!context.mounted) return;

                            // Ask the user whether to sync all notes
                            // ignore: use_build_context_synchronously
                            final confirmedSync = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(AppLocalizations.of(context)!.syncAllNotes),
                                content: Text(
                                  AppLocalizations.of(context)!.wantToSyncAllNotes,
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
                              // user cancelou, não alterar encriptação
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

                // Botões of ação
                if (!configured) ...[
                  // if não está configurado, mostrar instruções
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: configured
                          ? (isDarkMode
                                ? Color(0xFF1E1E1E) // Configurado + Dark
                                : Colors.grey.shade100) // Configurado + Light
                          : (isDarkMode
                                ? Color(
                                    0xFF2C2C2C,
                                  ) // Não configurado + Dark (exemplo)
                                : Colors
                                      .white), // Não configurado + Light (exemplo)
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
                ] else ...[
                  // Sincronização manual (push + pull)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _syncNow,
                      icon: _isSyncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.sync),
                      label: Text(
                        _isSyncing ? 'A sincronizar...' : 'Sincronizar agora',
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
                        item['name'] ?? 'Pasta',
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
                ? 'Pasta selecionada: $_selectedFolderName'
                : 'Selecione uma pasta para guardar as notas',
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
                title: Text(item['name'] ?? 'Item'),
                subtitle: Text(
                  isFolder
                      ? 'Pasta (ID: ${item['id']})'
                      : 'Ficheiro (ID: ${item['id']})',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: _selectedFolderId == item['id'].toString()
                    ? Icon(Icons.check, color: Colors.amber)
                    : null,
                onTap: () {
                  final folderId = item['id']?.toString() ?? '';
                  final folderName = item['name']?.toString() ?? 'Item';
                  debugPrint(
                    '[SyncSettings] onTap: id=$folderId, name=$folderName, isFolder=$isFolder',
                  );
                  if (isFolder && folderId.isNotEmpty) {
                    // Navigate into the folder
                    _navigateToFolder(folderId, folderName);
                  } else {
                    // Selecting a file does not make sense for storing notes
                    _showError(
                      'Não é possível criar pasta dentro de um ficheiro '
                      '(tipo: $rawType).',
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
        _showError('Erro ao listar pasta: $e');
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
                  'Criar dentro de: $createParentName',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Nome da nova pasta',
                    labelText: 'Nome da pasta',
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
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.enterFolderName),
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
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.folderCreatedSuccessfully),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    _showError(
                      'Erro ao criar pasta em "$_currentFolderName": $e',
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
                      _buildScopeChip('drive', 'Produtos kDrive'),
                      _buildScopeChip('user_info', 'Informações do perfil'),
                      _buildScopeChip('accounts', 'Listar contas'),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      hintText: 'Cole o token aqui',
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
      // Não sync automaticamente: the user deve escolher the folder and clicar in "sync".
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
            'Nenhuma conta Infomaniak válida encontrada para este token.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDrives = false);
        _showError('Erro ao descobrir contas/drives: $e');
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
                  title: Text(drive['name'] as String? ?? 'Drive'),
                  subtitle: Text('ID: ${drive['id']}'),
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
        _showError('Erro ao listar pasta: $e');
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
          _showError('A pasta Private está vazia.');
        }
        if (_tokenController.text.isNotEmpty) {
          await _saveCurrentConfig(sync: false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFolderContents = false);
        _showError('Erro ao listar pasta Private: $e');
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
                hintText: 'Passphrase',
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
                hintText: 'Confirmar passphrase',
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
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.enterPassphrase),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (widget.passphraseController.text != _confirmController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.passphrasesDoNotMatch),
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
