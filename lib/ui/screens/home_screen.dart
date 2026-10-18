// lib/ui/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<String> _selectedUuids = [];
  static const MethodChannel _widgetChannel = MethodChannel('com.marotoweb.kmemo/widget');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWidgetLaunch();
      _checkSharedText();
    });
    _setupWidgetChannel();
  }

  void _setupWidgetChannel() {
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'openNote') {
        final String? uuid = call.arguments as String?;
        if (uuid != null && uuid.isNotEmpty) {
          debugPrint('[HomeScreen] Widget channel: opening note $uuid');
          await _openNoteFromWidget(uuid);
        }
      } else if (call.method == 'getPendingNoteUuid') {
        // O Android consulta aqui se há um UUID pendente
        final prefs = await SharedPreferences.getInstance();
        final uuid = prefs.getString('flutter.clicked_note_uuid');
        if (uuid != null && uuid.isNotEmpty) {
          await prefs.setString('flutter.clicked_note_uuid', '');
          debugPrint('[HomeScreen] Returning pending UUID: $uuid');
          await _openNoteFromWidget(uuid);
        }
      } else if (call.method == 'onSharedTextReceived') {
        debugPrint('[HomeScreen] Widget channel: onSharedTextReceived');
        await _checkSharedText();
      }
    });
  }

  Future<void> _openNoteFromWidget(String uuid) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final memo = await (db.select(
      db.memos,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

    if (memo != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemoDetailScreen(memo: memo),
        ),
      );
    }
  }

  Future<void> _checkWidgetLaunch() async {
    try {
      debugPrint('[HomeScreen] _checkWidgetLaunch called');
      final prefs = await SharedPreferences.getInstance();
      final clickedUuid = prefs.getString('flutter.clicked_note_uuid');
      debugPrint('[HomeScreen] clickedUuid from prefs: $clickedUuid');
      if (clickedUuid != null && clickedUuid.isNotEmpty) {
        await prefs.setString('flutter.clicked_note_uuid', '');

        if (!mounted) return;

        final db = Provider.of<AppDatabase>(context, listen: false);
        final memo = await (db.select(
          db.memos,
        )..where((t) => t.uuid.equals(clickedUuid))).getSingleOrNull();

        if (memo != null && mounted) {
          debugPrint('[HomeScreen] Opening note: $clickedUuid (${memo.title})');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemoDetailScreen(memo: memo),
            ),
          );
        } else {
          debugPrint('[HomeScreen] Memo not found for uuid: $clickedUuid');
        }
      } else {
        debugPrint('[HomeScreen] No pending UUID in SharedPreferences');
      }
    } catch (e) {
      debugPrint('[HomeScreen] Erro ao abrir nota via widget: $e');
    }
  }

  /// Verifica se há texto partilhado de outra aplicação e cria uma nova nota com esse conteúdo.
  Future<void> _checkSharedText() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharedText = prefs.getString('kmemo.shared_text');
      debugPrint('[HomeScreen] sharedText from prefs: $sharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        await prefs.setString('kmemo.shared_text', '');

        if (!mounted) return;

        final provider = context.read<MemoProvider>();
        final now = DateTime.now();

        // Usa a primeira linha como título, ou "Nota partilhada" se estiver vazio
        final lines = sharedText.split('\n');
        final title = lines.first.trim().isNotEmpty
            ? lines.first.trim()
            : 'Nota partilhada';

        // O corpo é o resto (ou o texto completo se for uma linha só)
        final body = lines.length > 1
            ? lines.sublist(1).join('\n')
            : '';

        final memo = Memo(
          uuid: const Uuid().v4(),
          title: title,
          createdAt: now,
          updatedAt: now,
          isSynced: false,
          colorIndex: 0,
          bgImageIndex: -1,
          imageAttachments: '[]',
          audioAttachments: '[]',
          linkAttachments: '[]',
          isArchived: false,
          isDeleted: false,
        );

        final block = Block(
          id: 0,
          uuid: const Uuid().v4(),
          memoUuid: memo.uuid,
          type: BlockType.text,
          content: {'text': body},
          sortOrder: 0,
          isDeleted: false,
        );

        await provider.saveMemo(memo, [block]);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoDetailScreen(memo: memo),
          ),
        );

        debugPrint('[HomeScreen] Nova nota criada a partir de texto partilhado: $title');
      }
    } catch (e) {
      debugPrint('[HomeScreen] Erro ao processar texto partilhado: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // A app voltou ao foreground (ex.: ao clicar no widget enquanto já estava aberta)
      _checkWidgetLaunch();
      _checkSharedText();
    }
  }

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Paleta para o tema claro (tons suaves/pastel)
    final List<Color> lightColorsPalette = [
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

    // Paleta para o tema escuro (tons profundos e suaves)
    final List<Color> darkColorsPalette = [
      const Color(0xFF1E1E1E),
      const Color(0xFF3B1A1A),
      const Color(0xFF3D2C1E),
      const Color(0xFF3D361E),
      const Color(0xFF1E3322),
      const Color(0xFF1E3331),
      const Color(0xFF1E2A3B),
      const Color(0xFF261E3B),
      const Color(0xFF331E3B),
      const Color(0xFF3B1E32),
      const Color(0xFF2E2621),
      const Color(0xFF252B2E),
      const Color(0xFF3B2E1E),
      const Color(0xFF27331E),
      const Color(0xFF1E3338),
      const Color(0xFF2C2C2C),
    ];

    final colorsPalette = isDarkMode ? darkColorsPalette : lightColorsPalette;

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
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300),
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
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300),
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                color: isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                                child: Center(
                                  child: Text(
                                    'BG $i',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: isDarkMode
                  ? const Color(0xFF3B2E1E)
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
                    Icons.push_pin_outlined,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  onPressed: () {
                    _clearSelection();
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.palette_outlined,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  onPressed: () => _showStyleMenu(context),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
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
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF3B2E1E) : Colors.amber,
              ),
              child: Text(
                'kMemo',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
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
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Definições'),
              // SettingsScreen
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeMemos.isEmpty
          ? Center(
              child: Text(
                'Nenhuma nota ativa',
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black45,
                ),
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
                            color: isDarkMode
                                ? const Color(0xFF3B2E1E)
                                : Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.archive,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
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
              backgroundColor: isDarkMode
                  ? const Color(0xFF3B2E1E)
                  : Colors.amber,
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
              child: Icon(
                Icons.add,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
    );
  }
}
