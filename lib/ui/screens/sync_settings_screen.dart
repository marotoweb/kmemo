// lib/ui/screens/sync_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _isConfiguring = false;
  bool _isSyncing = false;

  // Estado do formulário de configuração
  final _tokenController = TextEditingController();
  final _passphraseController = TextEditingController();
  String _selectedDriveId = '';
  String _selectedDriveName = '';
  String _remoteFolder = 'kmemo/notes';
  bool _encryptionEnabled = false;

  // Lista de drives descobertos
  List<Map<String, dynamic>> _drives = [];
  bool _isLoadingDrives = false;

  // Conta selecionada (para listar drives)
  int? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _storage = Provider.of<KDriveStorage>(context, listen: false);
    _loadPersistedValues();
    _isLoading = false;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passphraseController.dispose();
    // NÃO fechamos _storage: é partilhada com MemoProvider
    super.dispose();
  }

  /// Carrega os valores persistidos do storage para o estado local do ecrã.
  void _loadPersistedValues() {
    if (_storage.driveId != null) {
      _selectedDriveId = _storage.driveId.toString();
    }
    _remoteFolder = _storage.remoteFolder;
    _encryptionEnabled = _storage.encryptionEnabled;

    // Se já temos drive selecionado, tentar descobrir o nome
    if (_selectedDriveId.isNotEmpty && _drives.isEmpty) {
      _discoverAccountsAndDrives();
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
      await Provider.of<MemoProvider>(context, listen: false).performSync();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização concluída'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        _showError('Erro na sincronização: $e');
      }
    }
  }

  Future<void> _saveConfiguration() async {
    if (_tokenController.text.trim().isEmpty) {
      _showError('Insira o token da Infomaniak');
      return;
    }
    if (_selectedDriveId.isEmpty) {
      _showError('Selecione um drive kDrive');
      return;
    }

    final drive = _drives.firstWhere(
      (d) => d['id'].toString() == _selectedDriveId,
      orElse: () => <String, dynamic>{},
    );

    setState(() => _isConfiguring = true);
    try {
      await _storage.configure(
        token: _tokenController.text.trim(),
        driveId: int.parse(_selectedDriveId),
        driveName: drive['name'] as String? ?? 'kDrive',
        remoteFolder: _remoteFolder.isEmpty ? 'kmemo/notes' : _remoteFolder,
        encryptionEnabled: _encryptionEnabled,
        encryptionPassphrase:
            _encryptionEnabled ? _passphraseController.text.trim() : null,
      );

      // Primeira sincronização imediata (envia notas locais e puxa remotas)
      try {
        await Provider.of<MemoProvider>(context, listen: false).performSync();
      } catch (e) {
        // A configuração está guardada; falha de sync não impede sair
        print('[SyncSettings] Sync inicial falhou: $e');
      }

      if (mounted) {
        setState(() => _isConfiguring = false);
        if (Navigator.canPop(context)) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfiguring = false);
        _showError('Erro ao configurar: $e');
      }
    }
  }

  Future<void> _logout() async {
    await _storage.logout();
    if (mounted) {
      setState(() {
        _tokenController.clear();
        _selectedDriveId = '';
        _selectedDriveName = '';
        _drives = [];
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configured = _storage.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronização'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Estado atual
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: configured
                        ? Colors.green.shade50.withValues(alpha: 0.8)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: configured
                          ? Colors.green.shade300
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
                            color: configured ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            configured
                                ? 'Sincronização ativa'
                                : 'Sincronização desativada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: configured
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (configured) ...[
                        Text(
                          'Drive: ${_storage.storageName}\n'
                          'Pasta: $_remoteFolder\n'
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
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
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
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
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
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                          trailing: const Icon(Icons.info_outline, color: Colors.orange),
                          onTap: null,
                        )
                      else
                        ListTile(
                          title: const Text('Drive kDrive'),
                          subtitle: Text(
                            _selectedDriveId.isEmpty
                                ? 'Selecione um drive'
                                : '$_selectedDriveName ($_selectedDriveId)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _selectDrive,
                        ),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),

                      // Pasta remota
                      ListTile(
                        title: const Text('Pasta remota'),
                        subtitle: Text(
                          _remoteFolder,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editRemoteFolder,
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),

                      // Encriptação
                      ListTile(
                        title: const Text('Encriptar notas'),
                        subtitle: const Text(
                          'Encripta as notas no cliente antes de enviar para a nuvem',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Switch(
                          value: _encryptionEnabled,
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
                            if (mounted) {
                              setState(() => _encryptionEnabled = value);
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isConfiguring ? null : _saveConfiguration,
                      icon: _isConfiguring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Guardar configuração'),
                    ),
                  ),
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
                      label: Text(_isSyncing
                          ? 'A sincronizar...'
                          : 'Sincronizar agora'),
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

  Future<void> _editToken() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool showToken = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Token da Infomaniak'),
            // Diálogo mais largo para acomodar tokens longos
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            content: SizedBox(
              // Largura generosa: ocupa quase todo o ecrã
              width: MediaQuery.of(dialogContext).size.width * 0.95,
              child: TextField(
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
    // Após fechar o diálogo, guarda o token e tenta descobrir contas e drives
    if (_tokenController.text.isNotEmpty) {
      await _storage.setToken(_tokenController.text.trim());
      await _discoverAccountsAndDrives();
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

        // Se só existe um drive, pré-seleciona automaticamente
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
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingDrives = false);
          _showError('Nenhuma conta Infomaniak válida encontrada para este token.');
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
                  onTap: () {
                    setState(() {
                      _selectedDriveId = drive['id'].toString();
                      _selectedDriveName = drive['name'] as String? ?? '';
                    });
                    Navigator.pop(dialogContext);
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

  Future<void> _editRemoteFolder() async {
    final controller = TextEditingController(text: _remoteFolder);
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pasta remota'),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.85,
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'kmemo/notes',
                labelText: 'Caminho da pasta',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _remoteFolder = controller.text.trim());
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Diálogo de passphrase com confirmação (duplo campo) e botão de mostrar/esconder.
  /// Retorna true se o utilizador confirmou, false se cancelou.
  Future<bool> _showPassphraseDialog() async {
    _passphraseController.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PassphraseDialog(
        passphraseController: _passphraseController,
        dialogWidth: MediaQuery.of(dialogContext).size.width * 0.85,
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
