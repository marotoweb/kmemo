// lib/ui/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import '../../services/widget_service.dart';
import 'memo_detail_screen.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<String> _selectedUuids = [];
  static const MethodChannel _widgetChannel = MethodChannel('com.marotoweb.kmemo/widget');
  bool _isOpeningNote = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    WidgetService.saveLabels(
      untitled: l10n.widgetUntitled,
      empty: l10n.widgetEmptyNote,
      listItem: l10n.listItem,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Prioritize shared text over pending widget note to avoid overlapping navigation.
      final prefs = await SharedPreferences.getInstance();
      final sharedText = prefs.getString('kmemo.shared_text');
      if (sharedText != null && sharedText.isNotEmpty) {
        await _checkSharedText();
      } else {
        await _checkWidgetLaunch();
      }
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
        // Android checks here if there is a pending uuid
        final prefs = await SharedPreferences.getInstance();
        final uuid = prefs.getString('flutter.clicked_note_uuid');
        if (uuid != null && uuid.isNotEmpty) {
          await prefs.setString('flutter.clicked_note_uuid', '');
          debugPrint('[HomeScreen] Returning pending UUID: $uuid');
          await _openNoteFromWidget(uuid);
        }
      } else if (call.method == 'createNewNote') {
        debugPrint('[HomeScreen] Widget channel: createNewNote');
        await _createNoteFromWidget();
      } else if (call.method == 'onSharedTextReceived') {
        debugPrint('[HomeScreen] Widget channel: onSharedTextReceived');
        await _checkSharedText();
      }
    });
  }

  Future<void> _openNoteFromWidget(String uuid) async {
    if (_isOpeningNote) {
      debugPrint('[HomeScreen] Already opening note, skipping');
      return;
    }
    _isOpeningNote = true;
    final db = Provider.of<AppDatabase>(context, listen: false);
    final memo = await (db.select(
      db.memos,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    
    if (memo != null && mounted) {
      debugPrint('[HomeScreen] Opening note: $uuid (${memo.title})');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemoDetailScreen(memo: memo),
        ),
      ).then((_) {
        // Clear the flag when returning
        _isOpeningNote = false;
        debugPrint('[HomeScreen] Returned from note detail');
      });
    } else {
      _isOpeningNote = false;
    }
  }

  Future<void> _checkWidgetLaunch() async {
    try {
      debugPrint('[HomeScreen] _checkWidgetLaunch called');
      
      // Check if there is a flag to create a new note
      bool createNewNote = false;
      try {
        createNewNote = await _widgetChannel.invokeMethod<bool>('getCreateNoteFlag') ?? false;
        debugPrint('[HomeScreen] createNewNote from MethodChannel: $createNewNote');
      } catch (e) {
        debugPrint('[HomeScreen] MethodChannel error (getCreateNoteFlag): $e');
      }
      
      if (createNewNote) {
        if (!mounted) return;
        await _createNoteFromWidget();
        return;
      }
      
      // Try to get the uuid via MethodChannel (more reliable than SharedPreferences)
      String? clickedUuid;
      try {
        clickedUuid = await _widgetChannel.invokeMethod<String>('getPendingNoteUuid');
        debugPrint('[HomeScreen] UUID from MethodChannel: $clickedUuid');
      } catch (e) {
        debugPrint('[HomeScreen] MethodChannel error: $e');
      }
      
      // Fallback: try reading directly from SharedPreferences
      if (clickedUuid == null || clickedUuid.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        clickedUuid = prefs.getString('flutter.clicked_note_uuid');
        if (clickedUuid != null && clickedUuid.isNotEmpty) {
          await prefs.setString('flutter.clicked_note_uuid', '');
        }
        debugPrint('[HomeScreen] clickedUuid from prefs: $clickedUuid');
      }
      
      if (clickedUuid != null && clickedUuid.isNotEmpty) {
        if (!mounted) return;
        
        // Check if we are already opening the note
        if (_isOpeningNote) {
          debugPrint('[HomeScreen] Already opening note, skipping _checkWidgetLaunch');
          return;
        }
        
        final db = Provider.of<AppDatabase>(context, listen: false);
        final memo = await (db.select(
          db.memos,
        )..where((t) => t.uuid.equals(clickedUuid!))).getSingleOrNull();
        
        if (memo != null && mounted) {
          debugPrint('[HomeScreen] Opening note: $clickedUuid (${memo.title})');
          _isOpeningNote = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemoDetailScreen(memo: memo),
            ),
          ).then((_) {
            // Clear the flag when returning
            _isOpeningNote = false;
            debugPrint('[HomeScreen] Returned from note detail');
          });
        } else {
          debugPrint('[HomeScreen] Memo not found for uuid: $clickedUuid');
        }
      } else {
        debugPrint('[HomeScreen] in pending UUID found');
      }
    } catch (e) {
      debugPrint('[HomeScreen] error opening note via widget: $e');
    }
  }

  Future<void> _createNoteFromWidget() async {
    try {
      if (_isOpeningNote) {
        debugPrint('[HomeScreen] Already opening note, skipping _createNoteFromWidget');
        return;
      }
      _isOpeningNote = true;
      
      final provider = context.read<MemoProvider>();
      final newMemo = await provider.createNewMemo();
      
      if (!mounted) {
        _isOpeningNote = false;
        return;
      }
      
      debugPrint('[HomeScreen] Creating new note from widget: ${newMemo.uuid}');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemoDetailScreen(memo: newMemo, isNew: true),
        ),
      ).then((_) {
        _isOpeningNote = false;
        debugPrint('[HomeScreen] Returned from new note detail');
      });
    } catch (e) {
      _isOpeningNote = false;
      debugPrint('[HomeScreen] error creating note via widget: $e');
    }
  }

  /// Sanitizes text received from other apps before storing it in a note.
  String _sanitizeSharedText(String input) {
    // Remove null bytes and other control characters except newline/tab.
    final cleaned = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    // Normalize line endings and collapse excessive blank lines.
    final normalized = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final trimmedLines = lines.map((l) => l.trimRight()).toList();
    // Limit total length to avoid huge notes.
    const maxLength = 100000;
    var result = trimmedLines.join('\n').trim();
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }
    return result;
  }

  /// Checks if there is text shared from another app and creates a new note with that content.
  Future<void> _checkSharedText() async {
    if (_isOpeningNote) {
      debugPrint('[HomeScreen] Already opening note, skipping shared text');
      return;
    }
    _isOpeningNote = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharedText = prefs.getString('kmemo.shared_text');
      debugPrint('[HomeScreen] sharedText from prefs: $sharedText');
      if (sharedText != null && sharedText.isNotEmpty) {
        await prefs.setString('kmemo.shared_text', '');
        // Clear any pending widget note to avoid overlapping navigation
        await prefs.setString('flutter.clicked_note_uuid', '');

        if (!mounted) return;

        final provider = context.read<MemoProvider>();
        final now = DateTime.now();

        // Sanitize the shared text: remove control characters, normalize
        // whitespace and limit length to avoid malformed notes.
        final sanitized = _sanitizeSharedText(sharedText);
        if (sanitized.isEmpty) return;

        final lines = sanitized.split('\n');

        // Detect checklist pattern: if the FIRST line is a checklist item,
        // treat the entire text as a checklist (first line becomes first item,
        // title defaults to "shared note").
        final checklistRegex = RegExp(r'^\s*[-*]?\s*\[([xX ]?)\]\s*(.*)$');
        final firstLine = lines.first.trim();
        final firstLineIsChecklist = firstLine.isNotEmpty &&
            checklistRegex.hasMatch(firstLine);

        String title;
        List<String> bodyLines;
        if (firstLineIsChecklist) {
          title = AppLocalizations.of(context)!.sharedNote;
          bodyLines = lines; // all lines are checklist items
        } else {
          title = firstLine.isNotEmpty
              ? firstLine
              : AppLocalizations.of(context)!.sharedNote;
          // the body is the rest (or the full text if it's the only line)
          bodyLines = lines.length > 1
              ? lines.sublist(1)
              : [];
        }

        debugPrint('[HomeScreen] title: "$title"');
        debugPrint('[HomeScreen] firstLineIsChecklist: $firstLineIsChecklist');
        debugPrint('[HomeScreen] bodyLines: $bodyLines');

        final memo = Memo(
          uuid: Uuid().v4(),
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

        final List<Block> blocks = [];
        int sortOrder = 0;
        for (final line in bodyLines) {
          if (line.trim().isEmpty) continue;
          final match = checklistRegex.firstMatch(line);
          if (match != null) {
            final marker = match.group(1) ?? '';
            final text = match.group(2) ?? '';
            blocks.add(
              Block(
                id: 0,
                uuid: Uuid().v4(),
                memoUuid: memo.uuid,
                type: BlockType.checklist,
                content: {
                  'text': text.trim(),
                  'checked': marker.toLowerCase() == 'x',
                },
                sortOrder: sortOrder++,
                isDeleted: false,
              ),
            );
          } else if (line.trim().isNotEmpty) {
            // Non-checklist line: keep as checklist item with original text
            blocks.add(
              Block(
                id: 0,
                uuid: Uuid().v4(),
                memoUuid: memo.uuid,
                type: BlockType.checklist,
                content: {
                  'text': line.trim(),
                  'checked': false,
                },
                sortOrder: sortOrder++,
                isDeleted: false,
              ),
            );
          }
        }
        if (blocks.isEmpty) {
          blocks.add(
            Block(
              id: 0,
              uuid: Uuid().v4(),
              memoUuid: memo.uuid,
              type: BlockType.text,
              content: {'text': bodyLines.join('\n')},
              sortOrder: 0,
              isDeleted: false,
            ),
          );
        }

        await provider.saveMemo(memo, blocks);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoDetailScreen(memo: memo, isNew: true),
          ),
        );

        debugPrint('[HomeScreen] New note created from shared text: $title');
      }
    } catch (e) {
      debugPrint('[HomeScreen] error processing shared text: $e');
    } finally {
      _isOpeningNote = false;
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
      // the app returned to foreground (e.g. when clicking the widget while already open)
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

  Future<void> _showStyleMenu(BuildContext context) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
      Color(0xFFF5F5F5),
    ];

    final List<Color> darkColorsPalette = [
      Color(0xFF1E1E1E),
      Color(0xFF3B1A1A),
      Color(0xFF3D2C1E),
      Color(0xFF3D361E),
      Color(0xFF1E3322),
      Color(0xFF1E3331),
      Color(0xFF1E2A3B),
      Color(0xFF261E3B),
      Color(0xFF331E3B),
      Color(0xFF3B1E32),
      Color(0xFF2E2621),
      Color(0xFF252B2E),
      Color(0xFF3B2E1E),
      Color(0xFF27331E),
      Color(0xFF1E3338),
      Color(0xFF2C2C2C),
    ];

    final colorsPalette = isDarkMode ? darkColorsPalette : lightColorsPalette;

    final List<String> bgImagesPalette = [];
    final bundle = DefaultAssetBundle.of(context);
    for (int i = 0; i < 16; i++) {
      final path = 'assets/backgrounds/bg_$i.png';
      try {
        await bundle.load(path);
        bgImagesPalette.add(path);
      } catch (_) {
        // Image does not exist, skipping
      }
    }

    if (!context.mounted) return;
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
                  title: TabBar(
                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.colorsTab),
                      Tab(text: AppLocalizations.of(context)!.imagesTab),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
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
                      padding: EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
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
                                    AppLocalizations.of(context)!.bgLabel('$i'),
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
                  ? Color(0xFF3B2E1E)
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
                                ? AppLocalizations.of(context)!.notesArchivedCount('${uuidsToArchive.length}')
                                : AppLocalizations.of(context)!.noteArchived,
                          ),
                          duration: Duration(seconds: 8),
                          action: SnackBarAction(
                            label: AppLocalizations.of(context)!.undo,
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

                      Future.delayed(Duration(seconds: 8), () {
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
                                ? AppLocalizations.of(context)!.notesSentToTrashCount('${uuidsToDelete.length}')
                                : AppLocalizations.of(context)!.noteSentToTrash,
                          ),
                          duration: Duration(seconds: 8),
                          action: SnackBarAction(
                            label: AppLocalizations.of(context)!.undo,
                            textColor: Colors.amberAccent,
                            onPressed: () async {
                              scaffoldMessenger.hideCurrentSnackBar();
                              await memoProvider.restoreMultiple(uuidsToDelete);
                            },
                          ),
                        ),
                      );

                      Future.delayed(Duration(seconds: 8), () {
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
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(AppLocalizations.of(context)!.archive),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)!.delete),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(AppLocalizations.of(context)!.makeCopy2),
                    ),
                    PopupMenuItem(value: 'share', child: Text(AppLocalizations.of(context)!.send)),
                    PopupMenuItem(
                      value: 'kdrive',
                      child: Text(AppLocalizations.of(context)!.copyToKdrive),
                    ),
                  ],
                ),
              ],
            )
          : AppBar(
              title: Text(
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
                color: isDarkMode ? Color(0xFF3B2E1E) : Colors.amber,
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
              leading: Icon(Icons.lightbulb_outline),
              title: Text(AppLocalizations.of(context)!.notes),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text(AppLocalizations.of(context)!.archiveScreen),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArchiveScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text(AppLocalizations.of(context)!.trash),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TrashScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text(AppLocalizations.of(context)!.settings),
              // SettingsScreen
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? Center(child: CircularProgressIndicator())
          : activeMemos.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(context)!.noActiveNotes,
                style: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black45,
                ),
              ),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 120.0),
                itemCount: activeMemos.length,
                itemBuilder: (context, index) {
                  final memo = activeMemos[index];
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
                                ? Color(0xFF3B2E1E)
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
                        background: SizedBox.shrink(),
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
                                  content: Text(AppLocalizations.of(context)!.noteArchived),
                                  duration: Duration(seconds: 8),
                                  action: SnackBarAction(
                                    label: AppLocalizations.of(context)!.undo,
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
                  ? Color(0xFF3B2E1E)
                  : Colors.amber,
              onPressed: () async {
                final newMemo = await provider.createNewMemo();
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemoDetailScreen(memo: newMemo, isNew: true),
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
