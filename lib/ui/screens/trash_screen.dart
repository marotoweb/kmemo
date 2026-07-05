// lib/ui/screens/trash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';

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
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.black87),
                  tooltip: 'Restaurar',
                  onPressed: () async {
                    final uuidsToRestore = List<String>.from(_selectedUuids);
                    _clearSelection();

                    await provider.restoreMultiple(uuidsToRestore);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          uuidsToRestore.length > 1
                              ? '${uuidsToRestore.length} notas restauradas'
                              : 'Nota restaurada',
                        ),
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) async {
                    final memoProvider = context.read<MemoProvider>();
                    if (value == 'delete_permanent') {
                      final uuidsToDelete = List<String>.from(_selectedUuids);
                      _clearSelection();
                      await memoProvider.deleteMultiplePermanent(uuidsToDelete);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete_permanent',
                      child: Text('Eliminar definitivamente'),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: const Text(
                'Lixeira',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
            ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : deletedMemos.isEmpty
          ? const Center(
              child: Text(
                'A lixeira está vazia.',
                style: TextStyle(color: Colors.black45),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120.0),
                itemCount: deletedMemos.length,
                itemBuilder: (context, index) {
                  final memo = deletedMemos[index];
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
                            Icons.restore,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Dismissible(
                        key: Key(memo.uuid),
                        direction: DismissDirection.startToEnd,
                        background: const SizedBox.shrink(),
                        onDismissed: (direction) async {
                          final uuidToRestore = memo.uuid;
                          await provider.restoreMultiple([uuidToRestore]);

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nota restaurada'),
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
