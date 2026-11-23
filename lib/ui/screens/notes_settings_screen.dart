// lib/ui/screens/notes_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';

/// Editor and image options, opened from the settings screen.
///
/// The editor switches used to sit on the main settings page. They moved here
/// so the image options have a home next to them, and the main page stays a
/// list of destinations.
class NotesSettingsScreen extends StatelessWidget {
  const NotesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notesSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(l10n.editor),
          _card(
            isDarkMode,
            Column(
              children: [
                SwitchListTile(
                  title: Text(l10n.autoWrapLines),
                  subtitle: Text(
                    l10n.autoWrapLinesSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.autoWrap,
                  onChanged: (value) {
                    themeProvider.setAutoWrap(value);
                    Provider.of<MemoProvider>(
                      context,
                      listen: false,
                    ).refreshWidget();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.strikethroughChecked),
                  subtitle: Text(
                    l10n.strikethroughCheckedSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.strikethroughChecked,
                  onChanged: (value) {
                    themeProvider.setStrikethroughChecked(value);
                    Provider.of<MemoProvider>(
                      context,
                      listen: false,
                    ).refreshWidget();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(l10n.showLinkPreviews),
                  subtitle: Text(
                    l10n.showLinkPreviewsSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: themeProvider.showLinkPreviews,
                  onChanged: (value) {
                    themeProvider.setShowLinkPreviews(value);
                    Provider.of<MemoProvider>(
                      context,
                      listen: false,
                    ).refreshWidget();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(l10n.images),
          _card(
            isDarkMode,
            Column(
              children: [
                ListTile(
                  title: Text(l10n.imageMaxSize),
                  subtitle: Text(
                    l10n.imageMaxSizeSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: DropdownButton<int>(
                    value: themeProvider.imageMaxSide,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 1280, child: Text('1280 px')),
                      DropdownMenuItem(value: 1920, child: Text('1920 px')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setImageMaxSide(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.imageResizeMode),
                  subtitle: Text(
                    l10n.imageResizeModeSubtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: DropdownButton<ImageResizeMode>(
                    value: themeProvider.imageResizeMode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: ImageResizeMode.ask,
                        child: Text(l10n.imageResizeAsk),
                      ),
                      DropdownMenuItem(
                        value: ImageResizeMode.always,
                        child: Text(l10n.imageResizeAlways),
                      ),
                      DropdownMenuItem(
                        value: ImageResizeMode.never,
                        child: Text(l10n.imageResizeNever),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        themeProvider.setImageResizeMode(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _card(bool isDarkMode, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}
