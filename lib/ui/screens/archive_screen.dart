// lib/ui/screens/archive_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/swipe_action_card.dart';
import 'memo_detail_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final List<String> _selectedUuids = [];

  void _toggleSelection(String uuid) {
    setState(() {
      if (_selectedUuids.contains(uuid)) {
        _selectedUuids.remove(uuid);
      } else {
        _selectedUuids.add(uuid);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUuids.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MemoProvider>(context);
    final isSelectionMode = _selectedUuids.isNotEmpty;
    final archivedMemos = provider.archivedMemos;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: isDarkMode
                  ? Colors.amber.shade900
                  : Colors.amber.shade100,
              leading: IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedUuids.length}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  onSelected: (value) async {
                    final memoProvider = context.read<MemoProvider>();
                    if (value == 'unarchive') {
                      final uuidsToUnarchive = List<String>.from(
                        _selectedUuids,
                      );
                      _clearSelection();

                      for (var uuid in uuidsToUnarchive) {
                        await memoProvider.archiveMemoStatus(uuid, false);
                      }

                      if (!context.mounted) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.hideCurrentSnackBar();

                      final snackBarController = scaffoldMessenger.showSnackBar(
                        buildAppSnackBar(
                          context,
                          message: uuidsToUnarchive.length > 1
                              ? AppLocalizations.of(
                                  context,
                                )!.notesUnarchivedCount(
                                  '${uuidsToUnarchive.length}',
                                )
                              : AppLocalizations.of(
                                  context,
                                )!.noteRemovedFromArchive,
                          duration: Duration(seconds: 8),
                          actionLabel: AppLocalizations.of(context)!.undo,
                          onAction: () async {
                            scaffoldMessenger.hideCurrentSnackBar();
                            for (var uuid in uuidsToUnarchive) {
                              await memoProvider.archiveMemoStatus(uuid, true);
                            }
                          },
                        ),
                      );

                      Future.delayed(Duration(seconds: 8), () {
                        try {
                          snackBarController.close();
                        } catch (_) {}
                      });
                    } else if (value == 'delete') {
                      await memoProvider.deleteMultiple(_selectedUuids);
                      _clearSelection();
                    } else {
                      _clearSelection();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'unarchive',
                      child: Text(
                        AppLocalizations.of(context)!.removeFromArchive,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)!.delete),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: Text(
                AppLocalizations.of(context)!.archiveScreen,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: [
                if (archivedMemos.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.unarchive,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    onPressed: () async {
                      final uuidsToUnarchive = archivedMemos
                          .map((m) => m.uuid)
                          .toList();

                      for (var uuid in uuidsToUnarchive) {
                        await provider.archiveMemoStatus(uuid, false);
                      }

                      if (!context.mounted) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.hideCurrentSnackBar();

                      final snackBarController = scaffoldMessenger.showSnackBar(
                        buildAppSnackBar(
                          context,
                          message: uuidsToUnarchive.length > 1
                              ? AppLocalizations.of(
                                  context,
                                )!.notesUnarchivedCount(
                                  '${uuidsToUnarchive.length}',
                                )
                              : AppLocalizations.of(
                                  context,
                                )!.noteRemovedFromArchive,
                          duration: Duration(seconds: 8),
                          actionLabel: AppLocalizations.of(context)!.undo,
                          onAction: () async {
                            scaffoldMessenger.hideCurrentSnackBar();
                            for (var uuid in uuidsToUnarchive) {
                              await provider.archiveMemoStatus(uuid, true);
                            }
                          },
                        ),
                      );

                      Future.delayed(Duration(seconds: 8), () {
                        try {
                          snackBarController.close();
                        } catch (_) {}
                      });
                    },
                  ),
              ],
            ),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator())
          : archivedMemos.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noArchivedNotes,
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black45,
                ),
              ),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 120.0),
                itemCount: archivedMemos.length,
                itemBuilder: (context, index) {
                  final memo = archivedMemos[index];
                  final isSelected = _selectedUuids.contains(memo.uuid);

                  return SwipeActionCard(
                    dismissKey: Key(memo.uuid),
                    // Right unarchives, left moves the note to the trash (the
                    // same soft delete as the home screen, so it can still be
                    // restored from there). Both directions require a
                    // near-complete swipe (see SwipeActionCard).
                    direction: DismissDirection.horizontal,
                    background: Container(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.amber.shade900
                            : Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.unarchive,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF4A1E1E)
                            : Colors.red.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    onDismissed: (direction) async {
                      final uuid = memo.uuid;
                      final l10n = AppLocalizations.of(context)!;
                      final isUnarchive =
                          direction == DismissDirection.startToEnd;

                      if (isUnarchive) {
                        await provider.archiveMemoStatus(uuid, false);
                      } else {
                        await provider.deleteMemo(uuid);
                      }

                      if (!context.mounted) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.hideCurrentSnackBar();

                      final snackBarController = scaffoldMessenger.showSnackBar(
                        buildAppSnackBar(
                          context,
                          message: isUnarchive
                              ? l10n.noteRemovedFromArchive
                              : l10n.noteSentToTrash,
                          duration: Duration(seconds: 8),
                          actionLabel: l10n.undo,
                          onAction: () async {
                            scaffoldMessenger.hideCurrentSnackBar();
                            if (isUnarchive) {
                              await provider.archiveMemoStatus(uuid, true);
                            } else {
                              await provider.restoreMultiple([uuid]);
                            }
                          },
                        ),
                      );

                      Future.delayed(Duration(seconds: 8), () {
                        try {
                          snackBarController.close();
                        } catch (_) {}
                      });
                    },
                    child: MemoCard(
                      memo: memo,
                      isSelected: isSelected,
                      onLongPress: () => _toggleSelection(memo.uuid),
                      onTap: () {
                        if (isSelectionMode) {
                          _toggleSelection(memo.uuid);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MemoDetailScreen(memo: memo),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
