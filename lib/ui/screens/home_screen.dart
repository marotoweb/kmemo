// lib/ui/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _showStyleMenu(BuildContext context) {
    final List<Color> colorsPalette = [
      Colors.white,
      Colors.red.shade100,
      Colors.orange.shade100,
      Colors.yellow.shade100,
      Colors.green.shade100,
      Colors.teal.shade100,
      Colors.blue.shade100,
      Colors.indigo.shade100,
      Colors.purple.shade100,
      Colors.pink.shade100,
      Colors.brown.shade100,
      Colors.blueGrey.shade100,
      Colors.amber.shade100,
      Colors.lightGreen.shade100,
      Colors.cyan.shade100,
      const Color(0xFFF5F5F5),
    ];

    final List<String> bgImagesPalette = List.generate(
      16,
      (i) => 'assets/backgrounds/bg_$i.png',
    );

    final provider = context.read<MemoProvider>();
    Memo? singleSelectedMemo;
    if (_selectedUuids.length == 1) {
      try {
        singleSelectedMemo = provider.memos.firstWhere(
          (m) => m.uuid == _selectedUuids.first,
        );
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const TabBar(
                    tabs: [
                      Tab(text: 'Cores (16)'),
                      Tab(text: 'Imagens (16)'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: colorsPalette.length,
                      itemBuilder: (context, i) {
                        final isSelected =
                            singleSelectedMemo != null &&
                            singleSelectedMemo.bgImageIndex == -1 &&
                            singleSelectedMemo.colorIndex == i;

                        return GestureDetector(
                          onTap: () {
                            context.read<MemoProvider>().changeColorMultiple(
                              _selectedUuids,
                              i,
                            );
                            _clearSelection();
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorsPalette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: bgImagesPalette.length,
                      itemBuilder: (context, i) {
                        final isSelected =
                            singleSelectedMemo != null &&
                            singleSelectedMemo.bgImageIndex == i;

                        return GestureDetector(
                          onTap: () {
                            context.read<MemoProvider>().changeColorMultiple(
                              _selectedUuids,
                              i,
                            );
                            _clearSelection();
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: Text(
                                    'BG $i',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MemoProvider>(context);
    final isSelectionMode = _selectedUuids.isNotEmpty;
    final activeMemos = provider.activeMemos;

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
                  icon: const Icon(
                    Icons.push_pin_outlined,
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    _clearSelection();
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.palette_outlined,
                    color: Colors.black87,
                  ),
                  onPressed: () => _showStyleMenu(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) async {
                    final memoProvider = context.read<MemoProvider>();
                    if (value == 'archive') {
                      final uuidsToArchive = List<String>.from(_selectedUuids);
                      _clearSelection();

                      await memoProvider.archiveMultiple(uuidsToArchive);

                      if (!context.mounted) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.hideCurrentSnackBar();

                      final snackBarController = scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            uuidsToArchive.length > 1
                                ? '${uuidsToArchive.length} notas arquivadas'
                                : 'Nota arquivada',
                          ),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: 'Anular',
                            textColor: Colors.amberAccent,
                            onPressed: () async {
                              scaffoldMessenger.hideCurrentSnackBar();
                              for (var uuid in uuidsToArchive) {
                                await memoProvider.archiveMemoStatus(
                                  uuid,
                                  false,
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
                      final uuidsToDelete = List<String>.from(_selectedUuids);
                      _clearSelection();

                      await memoProvider.deleteMultiple(uuidsToDelete);

                      if (!context.mounted) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      scaffoldMessenger.hideCurrentSnackBar();

                      final snackBarController = scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            uuidsToDelete.length > 1
                                ? '${uuidsToDelete.length} notas enviadas para a lixeira'
                                : 'Nota enviada para a lixeira',
                          ),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: 'Anular',
                            textColor: Colors.amberAccent,
                            onPressed: () async {
                              scaffoldMessenger.hideCurrentSnackBar();
                              await memoProvider.restoreMultiple(uuidsToDelete);
                            },
                          ),
                        ),
                      );

                      Future.delayed(const Duration(seconds: 8), () {
                        try {
                          snackBarController.close();
                        } catch (_) {}
                      });
                    } else if (value == 'copy') {
                      await memoProvider.duplicateMultiple(_selectedUuids);
                      _clearSelection();
                    } else {
                      _clearSelection();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Arquivar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Fazer cópia'),
                    ),
                    const PopupMenuItem(value: 'share', child: Text('Enviar')),
                    const PopupMenuItem(
                      value: 'kdrive',
                      child: Text('Copiar para kDrive'),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: const Text(
                'kMemo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.amber),
              child: Text(
                'kMemo',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Notas'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Arquivo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArchiveScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Lixeira'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrashScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeMemos.isEmpty
          ? const Center(
              child: Text(
                'Nenhuma nota ativa',
                style: TextStyle(color: Colors.black45),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120.0),
                itemCount: activeMemos.length,
                itemBuilder: (context, index) {
                  final memo = activeMemos[index];
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
                            Icons.archive,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Dismissible(
                        key: Key(memo.uuid),
                        direction: DismissDirection.startToEnd,
                        background: const SizedBox.shrink(),
                        onDismissed: (direction) async {
                          final uuidToArchive = memo.uuid;

                          await provider.archiveMemoStatus(uuidToArchive, true);

                          if (!context.mounted) return;

                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          scaffoldMessenger.hideCurrentSnackBar();

                          final snackBarController = scaffoldMessenger
                              .showSnackBar(
                                SnackBar(
                                  content: const Text('Nota arquivada'),
                                  duration: const Duration(seconds: 8),
                                  action: SnackBarAction(
                                    label: 'Anular',
                                    textColor: Colors.amberAccent,
                                    onPressed: () async {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                      await provider.archiveMemoStatus(
                                        uuidToArchive,
                                        false,
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
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.amber,
              onPressed: () async {
                final newMemo = await provider.createNewMemo();
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemoDetailScreen(memo: newMemo),
                    ),
                  );
                }
              },
              child: const Icon(Icons.add, color: Colors.black87),
            ),
    );
  }
}
