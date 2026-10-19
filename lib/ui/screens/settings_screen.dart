// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Definições',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // SECÇÃO: APARENCIA
          const Text(
            'APARÊNCIA',
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: ListTile(
              title: const Text('Tema'),
              trailing: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeSegment(
                      context,
                      'Claro',
                      ThemeMode.light,
                      themeProvider.themeMode == ThemeMode.light,
                    ),
                    _buildThemeSegment(
                      context,
                      'Escuro',
                      ThemeMode.dark,
                      themeProvider.themeMode == ThemeMode.dark,
                    ),
                    _buildThemeSegment(
                      context,
                      'Auto',
                      ThemeMode.system,
                      themeProvider.themeMode == ThemeMode.system,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // SECÇÃO: SINCRONIZAÇÃO
          const Text(
            'SINCRONIZAÇÃO',
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: ListTile(
              title: const Text('Armazenamento remoto'),
              subtitle: const Text(
                'Sincronize as suas notas com kDrive ou WebDAV',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const SyncSettingsScreen()),
                );
                if (changed == true && context.mounted) {
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // SECÇÃO: ISSUE REPORTING
          const Text(
            'REPORTAR PROBLEMA',
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Enviar feedback'),
                  subtitle: const Text(
                    'Reporte um bug, sugira uma funcionalidade, ou deixe um comentário',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _launchUrl(
                    'https://github.com/marotoweb/kmemo/issues/new',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SECÇÃO: ABOUT
          const Text(
            'SOBRE',
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Open source'),
                  trailing: const Icon(Icons.north_east, size: 18),
                  onTap: () => _launchUrl('https://github.com/marotoweb/kmemo'),
                ),
                Divider(
                  height: 1,
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                ListTile(
                  title: const Text('Version'),
                  trailing: Text(
                    _appVersion,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegment(
    BuildContext context,
    String label,
    ThemeMode mode,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        Provider.of<ThemeProvider>(context, listen: false).setThemeMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }
}
