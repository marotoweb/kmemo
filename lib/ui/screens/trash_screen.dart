// lib/ui/screens/trash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
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
    final deletedMemos = provider.deletedMemos;
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
                IconButton(
                  icon: Icon(
                    Icons.restore,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  tooltip: AppLocalizations.of(context)!.restore,
                  onPressed: () async {
                    final uuidsToRestore = List<String>.from(_selectedUuids);
                    _clearSelection();

                    await provider.restoreMultiple(uuidsToRestore);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          uuidsToRestore.length > 1
                              ? AppLocalizations.of(context)!.notesRestoredCount('${uuidsToRestore.length}')
                              : AppLocalizations.of(context)!.noteRestored,
                        ),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  onSelected: (value) async {
                    final memoProvider = context.read<MemoProvider>();
                    if (value == 'delete_permanent') {
                      final uuidsToDelete = List<String>.from(_selectedUuids);
                      _clearSelection();
                      await memoProvider.deleteMultiplePermanent(uuidsToDelete);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete_permanent',
                      child: Text(AppLocalizations.of(context)!.deletePermanently),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: Text(
                AppLocalizations.of(context)!.trash,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator())
          : deletedMemos.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.trashIsEmpty,
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black45,
                ),
              ),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 120.0),
                itemCount: deletedMemos.length,
                itemBuilder: (context, index) {
                  final memo = deletedMemos[index];
                  final isSelected = _selectedUuids.contains(memo.uuid);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.amber.shade900
                                : Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.restore,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      Dismissible(
                        key: Key(memo.uuid),
                        direction: DismissDirection.startToEnd,
                        background: SizedBox.shrink(),
                        onDismissed: (direction) async {
                          final uuidToRestore = memo.uuid;
                          await provider.restoreMultiple([uuidToRestore]);

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!.noteRestored),
                              duration: Duration(seconds: 4),
                            ),
                          );
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
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
