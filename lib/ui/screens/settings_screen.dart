// lib/ui/screens/settings_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/encryption_service.dart';
import '../../services/kdrive_storage.dart';
import '../../services/webdav_storage.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/update_service.dart';
import '../../services/widget_debug_log.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/simple_markdown.dart';
import '../../services/widget_service.dart';
import '../../services/sync_debug_log.dart';
import 'sync_settings_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';
  bool _isCheckingUpdate = false;

  /// Pending widget refresh after the user stops adjusting an opacity slider.
  Timer? _widgetRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _widgetRefreshDebounce?.cancel();
    super.dispose();
  }

  /// Coalesces rapid opacity adjustments into a single widget refresh: each
  /// slider release reschedules the timer, so dragging back and forth only
  /// rebuilds the widget once the value settles.
  void _scheduleWidgetRefresh() {
    _widgetRefreshDebounce?.cancel();
    _widgetRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Provider.of<MemoProvider>(context, listen: false).refreshWidget();
    });
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final info = await UpdateService().checkForUpdate();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (info.error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.updateCheckFailed,
        ),
      );
      return;
    }

    if (!info.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.upToDateMessage(
            info.latestVersion,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          // The release notes are prose: the default dialog width turned them
          // into a narrow column. They now use almost the whole screen, with a
          // readable cap on wide windows.
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          title: Text(AppLocalizations.of(ctx)!.newVersionAvailable),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(ctx)!.newVersionMessage(
                        info.latestVersion,
                        info.currentVersion,
                      ),
                    ),
                    if (info.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(ctx)!.releaseNotes,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SimpleMarkdown(
                        UpdateService.withoutPlatformTags(info.releaseNotes),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(ctx)!.later),
            ),
            if (info.releaseUrl.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _launchUrl(info.releaseUrl);
                },
                child: Text(AppLocalizations.of(ctx)!.viewReleasePage),
              ),
            if (info.downloadUrl.isNotEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _launchUrl(info.downloadUrl);
                },
                child: Text(AppLocalizations.of(ctx)!.downloadUpdate),
              ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  /// Copies the debug-only widget log so it can be pasted into a report when
  /// ADB/wireless debugging is not available.
  Future<void> _copyWidgetDebugLog() async {
    final log = await WidgetDebugLog.read();
    if (!mounted) return;
    if (log.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(
          context,
          message: 'Widget log is empty. Reproduce the issue first.',
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(
        context,
        message: 'Widget log copied to the clipboard.',
      ),
    );
  }

  /// Confirmation shared by the two destructive actions: the consequence is
  /// spelled out, the safe choice is Cancel and the action itself is red.
  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 32,
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Removes every note from this device (active, archived and in the trash).
  /// The server is not touched.
  Future<void> _deleteAllNotes() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<MemoProvider>(context, listen: false);
    final confirmed = await _confirmDestructive(
      title: l10n.deleteAllNotesConfirmTitle,
      body: l10n.deleteAllNotesConfirmBody,
      action: l10n.deleteAllNotesConfirmAction,
    );
    if (!confirmed) return;
    await provider.deleteAllNotesLocally();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(context, message: l10n.allNotesDeleted),
    );
  }

  /// Factory reset of this device: notes, settings, sync configuration and
  /// caches. The copies already uploaded stay on the server.
  Future<void> _deleteAllAppData() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<MemoProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    // The storages are captured before the first await: they are the instances
    // the app is using, so clearing them also clears their in-memory state.
    KDriveStorage? kdrive;
    WebDAVStorage? webdav;
    try {
      kdrive = Provider.of<KDriveStorage>(context, listen: false);
    } catch (_) {
      // Not registered (tests).
    }
    try {
      webdav = Provider.of<WebDAVStorage>(context, listen: false);
    } catch (_) {
      // Not registered (tests).
    }

    final confirmed = await _confirmDestructive(
      title: l10n.deleteAllDataConfirmTitle,
      body: l10n.deleteAllDataConfirmBody,
      action: l10n.deleteAllDataConfirmAction,
    );
    if (!confirmed) return;

    await provider.wipeAllData();
    await (kdrive ?? KDriveStorage()).clearConfiguration();
    await (webdav ?? WebDAVStorage()).clearConfiguration();
    EncryptionService.instance.disable();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // The diagnostics belong to the local data as well: a fresh install has no
    // sync log and no widget log, and the action promises exactly that. They
    // are removed in the background: deleting a log must never delay the reset
    // or fail it.
    unawaited(SyncDebugLog.clear());
    unawaited(WidgetDebugLog.clear());

    // Every setting goes back to what a fresh install has. The reset does not
    // write the defaults back, so the stored state stays empty and the next
    // start reads the same defaults.
    themeProvider.resetToDefaults();
    provider.refreshWidget();

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(context, message: l10n.allDataDeleted),
    );
  }

  /// Copies the sync log (counts and decisions, no content) to the clipboard.
  Future<void> _copySyncLog() async {
    final log = await SyncDebugLog.read();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (log.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        buildAppSnackBar(context, message: l10n.syncLogEmpty),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      buildAppSnackBar(context, message: l10n.copiedToClipboard),
    );
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
        // Extra bottom padding so the last item is not covered by the FAB
        // or the system navigation bar.
        padding: EdgeInsets.all(16.0).copyWith(bottom: 100),
        children: [
          // SECTION: SYNCHRONIZATION
          // Kept first: configuring the remote storage is the action most
          // users open this screen for.
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
            child: Column(
              children: [
                ListTile(
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
                Divider(height: 1),
                // The sync log has no credential and no note content, so it can
                // be copied from a release build: it is how a problem with a
                // note that does not reach the other device gets diagnosed.
                ListTile(
                  title: Text(AppLocalizations.of(context)!.syncLog),
                  subtitle: Text(
                    AppLocalizations.of(context)!.syncLogSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.copy, size: 18, color: Colors.grey),
                  onTap: _copySyncLog,
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    AppLocalizations.of(context)!.showLastSyncHint,
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.showLastSyncHintSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.showLastSyncHint,
                  onChanged: (value) =>
                      themeProvider.setShowLastSyncHint(value),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

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
                    Provider.of<MemoProvider>(context, listen: false).refreshWidget();
                  } else {
                    themeProvider.setLocale(Locale(code));
                    Provider.of<MemoProvider>(context, listen: false).refreshWidget();
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 24),

          // SECTION: EDITOR
          Text(
            AppLocalizations.of(context)!.editor,
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
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.autoWrapLines),
                  subtitle: Text(
                    AppLocalizations.of(context)!.autoWrapLinesSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.autoWrap,
                  onChanged: (value) {
                    themeProvider.setAutoWrap(value);
                    Provider.of<MemoProvider>(context, listen: false).refreshWidget();
                  },
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.strikethroughChecked),
                  subtitle: Text(
                    AppLocalizations.of(context)!.strikethroughCheckedSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.strikethroughChecked,
                  onChanged: (value) {
                    themeProvider.setStrikethroughChecked(value);
                    Provider.of<MemoProvider>(context, listen: false).refreshWidget();
                  },
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)!.showLinkPreviews),
                  subtitle: Text(
                    AppLocalizations.of(context)!.showLinkPreviewsSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.showLinkPreviews,
                  onChanged: (value) {
                    themeProvider.setShowLinkPreviews(value);
                    Provider.of<MemoProvider>(context, listen: false).refreshWidget();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // SECTION: WIDGET
          // The home-screen widget is Android-only: the transparency sliders
          // change nothing on desktop, so they are not shown there.
          if (WidgetService.isSupported) ...[
            Text(
              AppLocalizations.of(context)!.widget,
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
                  _buildTransparencyTile(
                    context,
                    title:
                        AppLocalizations.of(context)!.widgetBackgroundTransparency,
                    // The stored value is opacity; the slider shows transparency
                    // (0% = fully opaque, 100% = fully transparent).
                    transparency: 1 - themeProvider.widgetBgOpacity,
                    onChanged: (value) =>
                        themeProvider.setWidgetBgOpacity(1 - value),
                  ),
                  Divider(height: 1),
                  _buildTransparencyTile(
                    context,
                    title: AppLocalizations.of(context)!.widgetCardTransparency,
                    transparency: 1 - themeProvider.widgetCardOpacity,
                    onChanged: (value) =>
                        themeProvider.setWidgetCardOpacity(1 - value),
                  ),
              ],
            ),
          ),
          SizedBox(height: 24),
          ],

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
                    'https://github.com/marotoweb/kmemo/issues/new',
                  ),
                ),
                // Debug-only: there is no ADB on devices without wireless
                // debugging, so the widget log is copied from here.
                if (kDebugMode) ...[
                  Divider(
                    height: 1,
                    color: isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  ),
                  ListTile(
                    title: const Text('Widget debug log'),
                    subtitle: const Text(
                      'Copy the recent widget events to the clipboard',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.copy),
                    onTap: _copyWidgetDebugLog,
                  ),
                ],
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
                  title: Text(AppLocalizations.of(context)!.checkForUpdates),
                  subtitle: Text(
                    _appVersion,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isCheckingUpdate ? null : _checkForUpdate,
                ),
                Divider(
                  height: 1,
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.openSource),
                  trailing: Icon(Icons.north_east, size: 18),
                  onTap: () => _launchUrl('https://github.com/marotoweb/kmemo'),
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
          SizedBox(height: 24),

          // SECTION: DANGER ZONE
          // Deliberately last: neither action can be undone, so they sit as
          // far as possible from the settings used every day.
          Text(
            AppLocalizations.of(context)!.dangerZone,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Color(0xFF1E1E1E)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Colors.red,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.deleteAllNotes,
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.deleteAllNotesSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _deleteAllNotes,
                ),
                Divider(
                  height: 1,
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.deleteAllData,
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.deleteAllDataSubtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Icon(Icons.chevron_right, color: Colors.red),
                  onTap: _deleteAllAppData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Slider tile used by the widget transparency settings. [transparency] is
  /// 0.0 for fully opaque and 1.0 for fully transparent; the stored value is
  /// the inverse opacity. The widget payload is refreshed 300 ms after the
  /// user releases the slider, so dragging stays smooth.
  Widget _buildTransparencyTile(
    BuildContext context, {
    required String title,
    required double transparency,
    required Future<void> Function(double) onChanged,
  }) {
    final value = transparency.clamp(0.0, 1.0);
    final percent = (value * 100).round();
    final label = AppLocalizations.of(context)!.transparencyPercent(percent);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          Slider(
            value: value.clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 20,
            label: label,
            onChanged: (newValue) => onChanged(newValue),
            onChangeEnd: (_) => _scheduleWidgetRefresh(),
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
        Provider.of<MemoProvider>(context, listen: false).refreshWidget();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // Same vivid amber in both themes (theme primary), with a dark
          // foreground that stays readable on the yellow.
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}
