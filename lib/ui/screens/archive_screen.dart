// lib/ui/screens/archive_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';

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

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: Colors.amber.shade100,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedUuids.length}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
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
                        SnackBar(
                          content: Text(
                            uuidsToUnarchive.length > 1
                                ? '${uuidsToUnarchive.length} notas retiradas do arquivo'
                                : 'Nota retirada do arquivo',
                          ),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: 'Anular',
                            textColor: Colors.amberAccent,
                            onPressed: () async {
                              scaffoldMessenger.hideCurrentSnackBar();
                              for (var uuid in uuidsToUnarchive) {
                                await memoProvider.archiveMemoStatus(
                                  uuid,
                                  true,
                                );
                              }
                            },
                          ),
                        ),
                      );

                      Future.delayed(const Duration(seconds: 8), () {
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
                    const PopupMenuItem(
                      value: 'unarchive',
                      child: Text('Remover do arquivo'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar permanentemente'),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: const Text(
                'Arquivo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
            ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : archivedMemos.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma nota arquivada.',
                style: TextStyle(color: Colors.black45),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120.0),
                itemCount: archivedMemos.length,
                itemBuilder: (context, index) {
                  final memo = archivedMemos[index];
                  final isSelected = _selectedUuids.contains(memo.uuid);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.unarchive,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Dismissible(
                        key: Key(memo.uuid),
                        direction: DismissDirection.startToEnd,
                        background: const SizedBox.shrink(),
                        onDismissed: (direction) async {
                          final uuidToUnarchive = memo.uuid;

                          await provider.archiveMemoStatus(
                            uuidToUnarchive,
                            false,
                          );

                          if (!context.mounted) return;

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          scaffoldMessenger.hideCurrentSnackBar();

                          final snackBarController = scaffoldMessenger
                              .showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Nota retirada do arquivo',
                                  ),
                                  duration: const Duration(seconds: 8),
                                  action: SnackBarAction(
                                    label: 'Anular',
                                    textColor: Colors.amberAccent,
                                    onPressed: () async {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                      await provider.archiveMemoStatus(
                                        uuidToUnarchive,
                                        true,
                                      );
                                    },
                                  ),
                                ),
                              );

                          Future.delayed(const Duration(seconds: 8), () {
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
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
