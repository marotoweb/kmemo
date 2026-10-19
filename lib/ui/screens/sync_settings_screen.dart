// lib/ui/screens/sync_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../../services/kdrive_storage.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  // Usa a MESMA instância registada em main.dart (partilhada com MemoProvider)
  late final KDriveStorage _storage;
  bool _isLoading = true;
  bool _isSyncing = false;

  // Estado do formulário de configuração
  final _tokenController = TextEditingController();
  final _passphraseController = TextEditingController();
  String _selectedDriveId = '';
  String _selectedDriveName = '';
  String _selectedFolderId = '';
  String _selectedFolderName = '';
  String _remoteFolder = 'kmemo/notes';
  bool _encryptionEnabled = false;

  // Lista de drives descobertos
  List<Map<String, dynamic>> _drives = [];
  bool _isLoadingDrives = false;

  // Navegação hierárquica de pastas
  List<Map<String, dynamic>> _currentFolderContents = [];
  List<Map<String, dynamic>> _breadcrumb = [];
  String _currentFolderId =
      '5'; // '5' = pasta Private (raiz efetiva onde se podem criar pastas)
  String _currentFolderName = 'Private';
  bool _isLoadingFolderContents = false;

  // Conta selecionada (para listar drives)
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
    // NÃO fechamos _storage: é partilhada com MemoProvider
    super.dispose();
  }

  /// Carrega os valores persistidos do storage para o estado local do ecrã.
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
    // Restaurar o caminho (breadcrumb) persistido
    _breadcrumb = _storage.folderPath
        .map((e) => <String, dynamic>{'id': e['id'], 'name': e['name']})
        .toList();
    _remoteFolder = _storage.remoteFolder;
    _encryptionEnabled = _storage.encryptionEnabled;
    debugPrint(
      '[SyncSettings] _loadPersistedValues(): set _remoteFolder="$_remoteFolder", _selectedFolderId=$_selectedFolderId, _selectedFolderName=$_selectedFolderName, _encryptionEnabled=$_encryptionEnabled',
    );

    // Ler o token guardado no secure storage para mostrar no campo
    final token = await _storage.getStoredToken();
    if (token != null && token.isNotEmpty) {
      _tokenController.text = token;
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): token carregado do secure storage (length=${token.length})',
      );
    } else {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): nenhum token guardado',
      );
    }

    // Se já temos drive selecionado, carregar drives e pastas da raiz
    if (_selectedDriveId.isNotEmpty) {
      debugPrint(
        '[SyncSettings] _loadPersistedValues(): drive já selecionado, descobrindo drives e carregando pastas da raiz',
      );
      _selectedDriveId = _storage.driveId.toString();
      // Carregar drives para mostrar o nome correto na UI (não ficar com "Nenhum drive kDrive nesta conta")
      if (_drives.isEmpty) {
        await _discoverAccountsAndDrives();
      }
      // Mostrar a pasta de destino persistida (ou a raiz Private por defeito)
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
        '[SyncSettings] _loadPersistedValues(): sem drive selecionado',
      );
    }
  }

  /// Guarda a configuração atual no storage (chamado após cada alteração do utilizador).
  /// Se [sync] for true, executa também uma sincronização imediata.
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
      // Verificar se a encriptação mudou (ativada ou desativada)
      final wasEncryptionEnabled = _storage.encryptionEnabled;
      final encryptionChanged = wasEncryptionEnabled != _encryptionEnabled;

      // Se a encriptação mudou, marcar todas as notas como não sincronizadas
      // para que sejam re-enviadas com/sem encriptação
      if (encryptionChanged) {
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): encriptação mudou ($wasEncryptionEnabled -> $_encryptionEnabled), marcando todas as notas como não sincronizadas',
        );
        final db = Provider.of<AppDatabase>(context, listen: false);
        await db.customStatement(
          'UPDATE memos SET is_synced = 0, remote_file_id = NULL',
        );
        debugPrint(
          '[SyncSettings] _saveCurrentConfig(): todas as notas marcadas como não sincronizadas e remoteFileId limpo',
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

      // Sincronização imediata opcional (envia notas locais e puxa remotas)
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
          // A configuração está guardada; falha de sync não impede continuar
          debugPrint(
            '[SyncSettings] _saveCurrentConfig(): sync inicial falhou: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[SyncSettings] _saveCurrentConfig(): erro: $e');
      if (mounted) {
        _showError('Erro ao guardar configuração: $e');
      }
    } finally {
      // _isConfiguring removido
    }
  }

  /// Formata a última data de sincronização para apresentação.
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

  /// Sincronização manual (push + pull) acionada pelo utilizador.
  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      if (!mounted) return;
      // Garantir que a configuração atual está guardada antes de sincronizar
      await _saveCurrentConfig(sync: false);
      if (!mounted) return;
      final decryptionFailures = await _runSyncWithPrompts(force: true);
      if (mounted) {
        setState(() => _isSyncing = false);
        if (decryptionFailures > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sincronização concluída, mas $decryptionFailures ficheiro(s) não puderam ser desencriptados. '
                'Verifique se a passphrase está correta.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronização concluída'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showError('Erro na sincronização: $e');
      }
    }
  }

  /// Executa a sincronização com pedidos de passphrase e confirmação de
  /// eliminação para notas remotas não desencriptáveis.
  Future<int> _runSyncWithPrompts({bool force = false}) async {
    final memoProvider = Provider.of<MemoProvider>(context, listen: false);
    return await memoProvider.performSync(
      force: force,
      requestPassphrase: (remoteFileId) async {
        // Pedir passphrase ao utilizador para esta nota específica
        final controller = TextEditingController();
        final result = await showDialog<String?>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nota encriptada na nuvem'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Esta nota está encriptada na nuvem. '
                    'Insira a passphrase usada para a encriptar.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Passphrase'),
                    obscureText: true,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Ignorar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Confirmar'),
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
            title: const Text('Não foi possível desencriptar'),
            content: const Text(
              'Após duas tentativas, a nota não pôde ser desencriptada. '
              'Pretende eliminar a nota remota?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ignorar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        return delete == true;
      },
    );
  }

  Future<void> _logout() async {
    // Marcar todas as notas como não sincronizadas em todos os estados (Drift, memória)
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
      appBar: AppBar(title: const Text('Sincronização'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 100),
              children: [
                // Estado atual
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: configured
                        ? (isDarkMode
                              ? const Color(0xFF1E1E1E) // Configurado + Dark
                              : Colors.grey.shade100) // Configurado + Light
                        : (isDarkMode
                              ? const Color(
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
                          const SizedBox(width: 8),
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
                      const SizedBox(height: 8),
                      if (configured) ...[
                        Text(
                          'Drive: ${_storage.storageName}\n'
                          'Pasta de destino: $_selectedFolderName\n'
                          'Encriptação: ${_encryptionEnabled ? 'Ativa' : 'Inativa'}\n'
                          'Última sincronização: ${_formatLastSync()}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ] else
                        const Text(
                          'Configure um armazenamento remoto para sincronizar as suas notas.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Secção de configuração
                const Text(
                  'CONFIGURAR ARMAZENAMENTO REMOTO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
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
                      // Token
                      ListTile(
                        title: const Text('Token da Infomaniak'),
                        subtitle: const Text(
                          'Gere um token em manager.infomaniak.com',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editToken,
                      ),
                      Divider(
                        height: 1,
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),

                      // Drive
                      if (_isLoadingDrives)
                        const ListTile(
                          title: Text('A descobrir drives...'),
                          trailing: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_tokenController.text.isNotEmpty &&
                          _drives.isEmpty)
                        ListTile(
                          title: const Text('Drive kDrive'),
                          subtitle: const Text(
                            'Nenhum drive kDrive nesta conta. '
                            'Ative o kDrive em manager.infomaniak.com.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          onTap: null,
                        )
                      else
                        ListTile(
                          title: const Text('Drive kDrive'),
                          subtitle: Text(
                            _selectedDriveId.isEmpty
                                ? 'Selecione um drive'
                                : '$_selectedDriveName ($_selectedDriveId)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _selectDrive,
                        ),
                      Divider(
                        height: 1,
                        color: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                      ),

                      // Pasta de destino dentro do drive
                      if (_selectedDriveId.isNotEmpty) ...[
                        if (_isLoadingFolderContents)
                          const ListTile(
                            title: Text('A descobrir pastas...'),
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
                        title: const Text('Encriptar notas'),
                        subtitle: const Text(
                          'Encripta as notas no cliente antes de enviar para a nuvem',
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
                              // Pedir passphrase antes de ativar
                              final confirmed = await _showPassphraseDialog();
                              if (!confirmed) {
                                // Utilizador cancelou, não ativar
                                return;
                              }
                            } else {
                              // Desativar encriptação e limpar passphrase
                              _passphraseController.clear();
                            }

                            if (!mounted) return;

                            // Confirmar com o utilizador se quer sincronizar todas as notas
                            final action = value
                                ? 'encriptadas'
                                : 'desencriptadas';
                            final confirmedSync = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Sincronizar todas as notas'),
                                content: Text(
                                  'Pretende sincronizar todas as notas locais '
                                  '$action para a nuvem?\n\n'
                                  'Todas as notas serão re-enviadas '
                                  '${value ? 'com encriptação' : 'sem encriptação'}.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sincronizar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmedSync != true) {
                              // Utilizador cancelou, não alterar encriptação
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
                const SizedBox(height: 24),

                // Botões de ação
                if (!configured) ...[
                  // Se não está configurado, mostrar instruções
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: configured
                          ? (isDarkMode
                                ? const Color(0xFF1E1E1E) // Configurado + Dark
                                : Colors.grey.shade100) // Configurado + Light
                          : (isDarkMode
                                ? const Color(
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
                        const Text(
                          'Passos para configurar:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Insira o token da Infomaniak',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '2. Selecione o drive kDrive',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '3. Selecione a pasta de destino',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          '4. Carregue em "Syncronizar agora" para guardar a configuração e sincronizar as notas',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Sincronização manual (push + pull)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _syncNow,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        _isSyncing ? 'A sincronizar...' : 'Sincronizar agora',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Desativar sincronização'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// Secção de seleção de pasta de destino com navegação hierárquica
  Widget _buildDestinationFolderSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumbs
        if (_breadcrumb.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      const Icon(
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
        // Título da pasta atual
        ListTile(
          title: Text(
            _currentFolderName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            _selectedFolderId.isNotEmpty
                ? 'Pasta selecionada: $_selectedFolderName'
                : 'Selecione uma pasta para guardar as notas',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: _selectedFolderId.isNotEmpty
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
        ),
        Divider(
          height: 1,
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        // Conteúdo da pasta atual
        if (_isLoadingFolderContents)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_currentFolderContents.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Pasta vazia',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentFolderContents.length,
            itemBuilder: (ctx, index) {
              final item = _currentFolderContents[index];
              final rawType = item['type']?.toString() ?? '';
              // Tratar como pasta qualquer item que não seja claramente um ficheiro
              // (a API kDrive pode retornar tipos variados para pastas)
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
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: _selectedFolderId == item['id'].toString()
                    ? const Icon(Icons.check, color: Colors.amber)
                    : null,
                onTap: () {
                  final folderId = item['id']?.toString() ?? '';
                  final folderName = item['name']?.toString() ?? 'Item';
                  debugPrint(
                    '[SyncSettings] onTap: id=$folderId, name=$folderName, isFolder=$isFolder',
                  );
                  if (isFolder && folderId.isNotEmpty) {
                    // Navegar para dentro da pasta
                    _navigateToFolder(folderId, folderName);
                  } else {
                    // Selecionar ficheiro não faz sentido para guardar notas
                    _showError(
                      'Não é possível criar pasta dentro de um ficheiro '
                      '(tipo: $rawType).',
                    );
                  }
                },
              );
            },
          ),
        // Botão para criar nova pasta (sempre permite criar, inclusive na raiz)
        if (_currentFolderId.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoadingFolderContents
                  ? null
                  : _showCreateFolderDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Criar nova pasta'),
            ),
          ),
      ],
    );
  }

  /// Navega para uma pasta específica e a define como pasta de destino.
  Future<void> _navigateToFolder(String folderId, String folderName) async {
    debugPrint(
      '[SyncSettings] _navigateToFolder called: id=$folderId, name=$folderName',
    );
    setState(() => _isLoadingFolderContents = true);
    try {
      // Se já estamos nesta pasta, não adicionar ao breadcrumb novamente
      if (_currentFolderId != folderId) {
        // Adicionar ao breadcrumb apenas se não for duplicado da entrada anterior
        if (_breadcrumb.isEmpty || _breadcrumb.last['id'] != _currentFolderId) {
          _breadcrumb.add({'id': _currentFolderId, 'name': _currentFolderName});
        }
        // Remover entradas duplicadas consecutivas
        while (_breadcrumb.length > 1 &&
            _breadcrumb[_breadcrumb.length - 1]['id'] ==
                _breadcrumb[_breadcrumb.length - 2]['id']) {
          _breadcrumb.removeLast();
        }
      }
      _currentFolderId = folderId;
      _currentFolderName = folderName;
      // Define esta pasta como destino para guardar as notas
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
      // Persistir o caminho (breadcrumb) da pasta selecionada
      await _storage.setFolderPath(_breadcrumb);
      // Guardar a pasta selecionada como destino de forma persistente (sem sincronizar)
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

  /// Mostra diálogo para criar nova pasta
  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    // Quando estiver na raiz do kDrive (id=1), a API não permite criar pastas
    // diretamente; redireciona para dentro da pasta "Private" (ou primeira disponível).
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
          title: const Text('Criar nova pasta'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criar dentro de: $createParentName',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
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
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Insira um nome para a pasta'),
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
                      // Adicionar a nova pasta à lista atual
                      _currentFolderContents.add({
                        'id': newFolderId,
                        'name': name,
                        'type': 'directory',
                      });
                    });
                    // Selecionar a nova pasta automaticamente como destino
                    setState(() {
                      _selectedFolderId = newFolderId ?? '';
                      _selectedFolderName = name;
                    });
                    await _saveCurrentConfig();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pasta criada com sucesso'),
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
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  /// Constrói um chip informativo para um scope da API Infomaniak.
  Widget _buildScopeChip(String scope, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.amber.shade700),
          const SizedBox(width: 6),
          Text(
            scope,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
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
            title: const Text('Token da Infomaniak'),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.90,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gere um token em manager.infomaniak.com com os seguintes scopes:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildScopeChip('drive', 'Produtos kDrive'),
                      _buildScopeChip('user_info', 'Informações do perfil'),
                      _buildScopeChip('accounts', 'Listar contas'),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
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
      // Não sincronizar automaticamente: o utilizador deve escolher a pasta e clicar em "Sincronizar".
    } else {
      debugPrint('[SyncSettings] _editToken(): token empty, skipping');
    }
  }

  /// Lista as contas do utilizador, seleciona a primeira e lista os drives.
  Future<void> _discoverAccountsAndDrives() async {
    setState(() => _isLoadingDrives = true);
    try {
      final accounts = await _storage.listAccounts();
      if (mounted) {
        setState(() {
          // Seleciona automaticamente a primeira conta
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
              'Nenhum drive kDrive encontrado nesta conta. '
              'Ative o kDrive em manager.infomaniak.com primeiro.',
            );
          } else if (autoSelectedId != null) {
            // Pré-selecionou um drive: guardar driveId
            await _storage.setDriveId(int.parse(autoSelectedId));
            // Carregar as pastas da raiz do drive pré-selecionado
            await _loadRootFolders();
            // Não sincronizar automaticamente: o utilizador deve escolher a pasta e clicar em "Sincronizar".
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
          title: const Text('Escolher drive kDrive'),
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
                      ? const Icon(Icons.check, color: Colors.amber)
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
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  /// Carrega o conteúdo de uma pasta específica por ID (usado ao reabrir a página).
  Future<void> _loadFolderById(String folderId, String folderName) async {
    setState(() => _isLoadingFolderContents = true);
    try {
      final contents = await _storage.listFolderContents(folderId);
      if (mounted) {
        setState(() {
          _currentFolderContents = contents;
          _currentFolderId = folderId;
          _currentFolderName = folderName;
          // Manter o breadcrumb persistido (não sobrescrever)
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

  /// Carrega o conteúdo da pasta Private (ID: 5) — a raiz efetiva onde se podem criar pastas.
  Future<void> _loadRootFolders() async {
    setState(() => _isLoadingFolderContents = true);
    try {
      // Listar conteúdo da pasta Private (id=5) em vez da raiz do kDrive (id=1)
      // pois a API não permite criar pastas diretamente na raiz
      final contents = await _storage.listFolderContents('5');
      if (mounted) {
        setState(() {
          _currentFolderContents = contents;
          _currentFolderId = '5';
          _currentFolderName = 'Private';
          _breadcrumb = [];
          _isLoadingFolderContents = false;
          // Pasta padrão de destino: Private (id=5)
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

  /// Diálogo de passphrase com confirmação e toggle de visibilidade.
  /// Retorna true se o utilizador confirmou, false se cancelou.
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

/// Diálogo de passphrase com confirmação e toggle de visibilidade.
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
      title: const Text('Passphrase de encriptação'),
      content: SizedBox(
        width: widget.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Defina uma passphrase para encriptar as suas notas. '
              'Sem ela, não será possível recuperar os dados.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 12),
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
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (widget.passphraseController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Insira uma passphrase'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (widget.passphraseController.text != _confirmController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('As passphrases não coincidem'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context, true);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
