// lib/ui/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import 'sync_settings_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';

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
        title: Text(
          AppLocalizations.of(context)!.settings,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          // SECTION: APPEARANCE
          Text(
            AppLocalizations.of(context)!.appearance,
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: ListTile(
              title: Text(AppLocalizations.of(context)!.theme),
              trailing: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeSegment(
                      context,
                      AppLocalizations.of(context)!.light,
                      ThemeMode.light,
                      themeProvider.themeMode == ThemeMode.light,
                    ),
                    _buildThemeSegment(
                      context,
                      AppLocalizations.of(context)!.dark,
                      ThemeMode.dark,
                      themeProvider.themeMode == ThemeMode.dark,
                    ),
                    _buildThemeSegment(
                      context,
                      AppLocalizations.of(context)!.auto,
                      ThemeMode.system,
                      themeProvider.themeMode == ThemeMode.system,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 24),

          // SECTION: LANGUAGE
          Text(
            AppLocalizations.of(context)!.language,
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: ListTile(
              title: Text(AppLocalizations.of(context)!.languageSetting),
              trailing: DropdownButton<String?>(
                value: themeProvider.locale?.languageCode,
                underline: SizedBox.shrink(),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.system),
                  ),
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                  DropdownMenuItem(value: 'it', child: Text('Italiano')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                ],
                onChanged: (code) {
                  if (code == null) {
                    themeProvider.setLocale(null);
                  } else {
                    themeProvider.setLocale(Locale(code));
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 24),

          // SECTION: SYNCHRONIZATION
          Text(
            AppLocalizations.of(context)!.syncSection,
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: ListTile(
              title: Text(AppLocalizations.of(context)!.remoteStorage),
              subtitle: Text(
                AppLocalizations.of(context)!.syncSubtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => SyncSettingsScreen()),
                );
                if (changed == true && context.mounted) {
                  setState(() {});
                }
              },
            ),
          ),
          SizedBox(height: 24),

          // SECTION: ISSUE REPORTING
          Text(
            AppLocalizations.of(context)!.reportProblem,
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(AppLocalizations.of(context)!.sendFeedback),
                  subtitle: Text(
                    AppLocalizations.of(context)!.reportBugSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _launchUrl(
                    'https://github.with/marotoweb/kmemo/issues/new',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // SECTION: ABOUT
          Text(
            AppLocalizations.of(context)!.about,
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
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(AppLocalizations.of(context)!.openSource),
                  trailing: Icon(Icons.north_east, size: 18),
                  onTap: () => _launchUrl('https://github.with/marotoweb/kmemo'),
                ),
                Divider(
                  height: 1,
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.version),
                  trailing: Text(
                    _appVersion,
                    style: TextStyle(color: Colors.grey),
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
