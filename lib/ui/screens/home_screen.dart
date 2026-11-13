// lib/ui/screens/home_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../models/background_images.dart';
import '../../models/home_sort.dart';
import '../../models/note_palette.dart';
import '../../models/shared_text.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/swipe_action_card.dart';
import '../../services/docx_export_service.dart';
import '../../services/kdrive_storage.dart';
import '../../services/widget_service.dart';
import 'memo_detail_screen.dart';
import 'archive_screen.dart';
import 'trash_screen.dart';
import 'settings_screen.dart';
import 'sync_settings_screen.dart';
import 'package:kmemo/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<String> _selectedUuids = [];
  static const MethodChannel _widgetChannel = MethodChannel(
    'com.marotoweb.kmemo/widget',
  );
  bool _isOpeningNote = false;

  // AppBar search (pill field replacing the title).
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  List<Memo> _searchResults = [];
  Timer? _searchDebounce;

  /// One search query runs at a time. A change that arrives while a query is
  /// in flight is remembered and the query is repeated once it finishes, so the
  /// list always ends up reflecting the latest memo data.
  bool _searchQueryRunning = false;
  bool _searchQueryPending = false;

  MemoProvider? _memoProvider;

  // Hybrid gesture (reorder-allowed view): long-press + drag reorders;
  // long-press + release without moving toggles multi-selection.
  //
  // The selection is detected from the reorder callbacks instead of the card
  // itself: once the delayed drag starts, the card widget is unmounted, so a
  // Listener on the card never sees the pointer up. onReorderStart only fires
  // for a long-press (never for a scroll), and onReorderEnd reports the drop
  // index, which stays equal to the start index when the finger did not move.
  int? _dragStartIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-run an open search when the memo data changes: the results are a
    // snapshot, so archiving, trashing, restoring or editing a note used to
    // leave stale cards in the list until the user typed again.
    final provider = context.read<MemoProvider>();
    if (!identical(provider, _memoProvider)) {
      _memoProvider?.removeListener(_onMemoDataChanged);
      _memoProvider = provider;
      provider.addListener(_onMemoDataChanged);
    }
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
      // Apply any widget reload deferred before the first frame (the app may
      // still have been reported as backgrounded while starting).
      if (mounted) {
        Provider.of<MemoProvider>(context, listen: false).refreshWidget();
      }
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
    // Resolve the database before awaiting: the context must not be used
    // across an async gap.
    final db = Provider.of<AppDatabase>(context, listen: false);
    // Consume the pending record as soon as the note is opened: it must not
    // survive the session, otherwise the next app start reopens this note.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('flutter.clicked_note_uuid', '');
    final memo = await (db.select(
      db.memos,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();

    if (memo != null && mounted) {
      debugPrint('[HomeScreen] Opening note: $uuid (${memo.title})');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MemoDetailScreen(memo: memo)),
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
        createNewNote =
            await _widgetChannel.invokeMethod<bool>('getCreateNoteFlag') ??
            false;
        debugPrint(
          '[HomeScreen] createNewNote from MethodChannel: $createNewNote',
        );
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
        clickedUuid = await _widgetChannel.invokeMethod<String>(
          'getPendingNoteUuid',
        );
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
          debugPrint(
            '[HomeScreen] Already opening note, skipping _checkWidgetLaunch',
          );
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
        debugPrint(
          '[HomeScreen] Already opening note, skipping _createNoteFromWidget',
        );
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
    final cleaned = input.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );
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

        // Plain text stays text; only real checklist markers become items.
        final parsed = parseSharedText(
          sanitized,
          fallbackTitle: AppLocalizations.of(context)!.sharedNote,
        );

        debugPrint('[HomeScreen] title: "${parsed.title}"');
        debugPrint('[HomeScreen] blocks: ${parsed.blocks.length}');

        final memo = Memo(
          uuid: Uuid().v4(),
          title: parsed.title,
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
          isPinned: false,
          sortIndex: provider.nextTopSortIndex(),
        );

        final List<Block> blocks = [];
        int sortOrder = 0;
        for (final spec in parsed.blocks) {
          final isChecklist = spec.type == SharedTextBlockType.checklist;
          blocks.add(
            Block(
              id: 0,
              uuid: Uuid().v4(),
              memoUuid: memo.uuid,
              type: isChecklist ? BlockType.checklist : BlockType.text,
              content: isChecklist
                  ? {'text': spec.text, 'checked': spec.checked}
                  : {'text': spec.text},
              sortOrder: sortOrder++,
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

        debugPrint(
          '[HomeScreen] New note created from shared text: ${parsed.title}',
        );
      }
    } catch (e) {
      debugPrint('[HomeScreen] error processing shared text: $e');
    } finally {
      _isOpeningNote = false;
    }
  }

  @override
  void dispose() {
    _memoProvider?.removeListener(_onMemoDataChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
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
      // Apply any widget reload that was deferred while the app was in the
      // background (it is deferred to avoid resetting the widget scroll).
      Provider.of<MemoProvider>(context, listen: false).refreshWidget();
    }
  }

  void _toggleSelection(String uuid) {
    if (_selectedUuids.isEmpty && _isSearching) {
      _closeSearch();
    }
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

  // ---------------------------------------------------------------------------
  // Search (AppBar pill)
  // ---------------------------------------------------------------------------

  void _toggleSearch() {
    if (_isSearching) {
      _closeSearch();
      return;
    }
    setState(() {
      _isSearching = true;
      _selectedUuids.clear();
    });
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) _searchResults = [];
    });
    if (query.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_runSearch(query));
    });
  }

  /// A memo changed (edit, archive, trash, restore, sync). An open search is
  /// refreshed so cards that no longer match disappear and new matches appear.
  void _onMemoDataChanged() {
    if (!_isSearching || _searchQuery.isEmpty) return;
    unawaited(_runSearch(_searchQuery));
  }

  /// Runs [MemoProvider.searchMemos] for [query], one query at a time. Results
  /// for a query the user already replaced are dropped, and a change that
  /// arrives mid-query repeats the query once it finishes.
  Future<void> _runSearch(String query) async {
    if (query.isEmpty) return;
    final provider = _memoProvider;
    if (provider == null) return;
    if (_searchQueryRunning) {
      _searchQueryPending = true;
      return;
    }
    _searchQueryRunning = true;
    try {
      final results = await provider.searchMemos(query);
      if (!mounted || _searchQuery != query) return;
      setState(() => _searchResults = results);
    } finally {
      _searchQueryRunning = false;
      final repeat = _searchQueryPending;
      _searchQueryPending = false;
      if (repeat && mounted && _isSearching && _searchQuery.isNotEmpty) {
        unawaited(_runSearch(_searchQuery));
      }
    }
  }

  /// Fully rounded search field that replaces the AppBar title.
  Widget _buildSearchField(bool isDarkMode) {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = isDarkMode ? Colors.white54 : Colors.black45;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide.none,
    );

    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        style: TextStyle(fontSize: 15, color: textColor),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.searchNotes,
          hintStyle: TextStyle(fontSize: 15, color: hintColor),
          prefixIcon: Icon(Icons.search, size: 20, color: hintColor),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.clear, size: 18, color: hintColor),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    _searchFocus.requestFocus();
                  },
                ),
          filled: true,
          fillColor: isDarkMode
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
          contentPadding: EdgeInsets.zero,
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder,
        ),
      ),
    );
  }

  /// Notes currently displayed: search results or the provider's sorted list.
  List<Memo> _visibleMemos(MemoProvider provider) =>
      _searchQuery.isEmpty ? provider.activeMemos : _searchResults;

  // ---------------------------------------------------------------------------
  // Sort options (bottom sheet)
  // ---------------------------------------------------------------------------

  void _showSortMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final provider = context.watch<MemoProvider>();

              Widget option(HomeSortMode mode, String label) {
                final selected = provider.sortMode == mode;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(label),
                  onTap: () async {
                    await provider.setSortMode(mode);
                    setSheetState(() {});
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          l10n.sortBy,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  option(HomeSortMode.updated, l10n.sortByUpdated),
                  option(HomeSortMode.created, l10n.sortByCreated),
                  option(HomeSortMode.custom, l10n.sortByCustom),
                  if (provider.sortMode != HomeSortMode.custom)
                    SwitchListTile(
                      secondary: Icon(
                        provider.sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      title: Text(
                        provider.sortAscending
                            ? l10n.ascending
                            : l10n.descending,
                      ),
                      value: provider.sortAscending,
                      onChanged: (value) async {
                        await provider.setSortAscending(value);
                        setSheetState(() {});
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Custom order (drag only the single selected card)
  // ---------------------------------------------------------------------------

  Future<void> _handleReorder(
    MemoProvider provider,
    List<Memo> items,
    int oldIndex,
    int newIndex,
  ) async {
    // Automatically switch to custom order when the user drags in any other
    // sort mode (seeds the current order so nothing jumps).
    if (provider.sortMode != HomeSortMode.custom) {
      await provider.setSortMode(HomeSortMode.custom);
      if (!mounted) return;
    }

    if (newIndex > oldIndex) newIndex -= 1;

    final list = List<Memo>.from(items);
    final moved = list.removeAt(oldIndex);
    // Pinned and non-pinned notes are separate sections; keep the moved note
    // inside its own section.
    final pinnedInList = list.where((m) => m.isPinned).length;
    final minIndex = moved.isPinned ? 0 : pinnedInList;
    final maxIndex = moved.isPinned ? pinnedInList : list.length;
    final target = newIndex.clamp(minIndex, maxIndex);
    if (target == oldIndex) return;
    list.insert(target, moved);

    _clearSelection();
    await provider.reorderActiveMemos(list.map((m) => m.uuid).toList());
  }

  List<Memo> _selectedMemos(MemoProvider provider) {
    final selected = <Memo>[];
    for (final uuid in _selectedUuids) {
      for (final memo in provider.memos) {
        if (memo.uuid == uuid) {
          selected.add(memo);
          break;
        }
      }
    }
    return selected;
  }

  Future<void> _shareSelectedNotes() async {
    final provider = context.read<MemoProvider>();
    final l10n = AppLocalizations.of(context)!;
    final memos = _selectedMemos(provider);
    if (memos.isEmpty) return;

    final buffer = StringBuffer();
    for (var i = 0; i < memos.length; i++) {
      final memo = memos[i];
      final blocks = await provider.loadBlocks(memo.uuid);
      final body = blocks
          .map((b) => b.content['text']?.toString() ?? '')
          .join('\n');
      final title = memo.title.trim().isEmpty ? l10n.note : memo.title.trim();
      if (i > 0) buffer.write('\n\n');
      buffer.write('$title\n$body');
    }

    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString().trim(),
        title: memos.length == 1
            ? (memos.first.title.trim().isEmpty
                  ? l10n.note
                  : memos.first.title.trim())
            : l10n.sharedNote,
      ),
    );
  }

  Future<void> _exportSelectedNotesToKDrive() async {
    final provider = context.read<MemoProvider>();
    final storage = context.read<KDriveStorage>();
    final l10n = AppLocalizations.of(context)!;
    final memos = _selectedMemos(provider);
    if (memos.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);

    if (!storage.isConfigured) {
      final navigator = Navigator.of(context);
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: l10n.kdriveNotConfigured,
          actionLabel: l10n.settings,
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => SyncSettingsScreen()),
          ),
        ),
      );
      return;
    }

    final sections = <DocxSection>[];
    for (final memo in memos) {
      final blocks = await provider.loadBlocks(memo.uuid);
      final body = blocks
          .map((b) => b.content['text']?.toString() ?? '')
          .join('\n');
      sections.add(
        DocxSection(
          title: memo.title.trim().isEmpty ? l10n.note : memo.title.trim(),
          body: body,
        ),
      );
    }

    final docxBytes = DocxExportService.buildDocx(sections: sections);
    final fileName = sections.length == 1
        ? '${sections.first.title}.docx'
        : 'kMemo-${sections.length}-notes.docx';

    try {
      await storage.uploadMemoBytes(fileName: fileName, bytes: docxBytes);
      if (!mounted) return;
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: l10n.copiedToKdrive,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: '${l10n.copyToKdriveFailed}: $e',
          duration: const Duration(seconds: 5),
        ),
      );
    }
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

    final colorsPalette = isDarkMode ? kDarkNotePalette : lightColorsPalette;

    final bgImageNumbers = noteBackgroundNumbers;

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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: bgImageNumbers.length,
                      itemBuilder: (context, i) {
                        final number = bgImageNumbers[i];
                        final isSelected =
                            singleSelectedMemo != null &&
                            normalizedBackgroundImageIndex(
                                  singleSelectedMemo.bgImageIndex,
                                ) ==
                                number;

                        return GestureDetector(
                          onTap: () {
                            context.read<MemoProvider>().changeBgImageMultiple(
                              _selectedUuids,
                              number,
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
                              child: Image.asset(
                                noteBackgroundImagePath(number)!,
                                fit: BoxFit.cover,
                                cacheWidth: 240,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 18,
                                        color: isDarkMode
                                            ? Colors.white54
                                            : Colors.black45,
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

  Widget _buildBody(
    MemoProvider provider,
    List<Memo> items,
    bool isDarkMode,
    bool isSelectionMode,
  ) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? l10n.noResults : l10n.noActiveNotes,
          style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black45),
        ),
      );
    }

    // Drag & drop is available when not searching: the single selected note
    // can be dragged. Dropping in a date sort mode automatically switches to
    // the custom order (see _handleReorder).
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 120.0),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildMemoItem(
            provider,
            items[index],
            index,
            isDarkMode,
            isSelectionMode,
            reorderableView: false,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 120.0),
        buildDefaultDragHandles: false,
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) =>
            _handleReorder(provider, items, oldIndex, newIndex),
        // A long-press that never moves the card ends with the same drop
        // index, so treat it as a multi-selection toggle. A real reorder
        // changes the index and is handled by onReorder.
        onReorderStart: (index) {
          _dragStartIndex = index;
        },
        onReorderEnd: (index) {
          final startIndex = _dragStartIndex;
          _dragStartIndex = null;
          if (startIndex == null || startIndex != index) return;
          if (startIndex < items.length) {
            _toggleSelection(items[startIndex].uuid);
          }
        },
        // The default proxy wraps the dragged item in a rectangular Material,
        // which shows as a dark box behind the rounded card. Keep the lift
        // animation but make the proxy transparent so the card shape wins.
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(animation.value);
              return Transform.scale(
                scale: 1 + 0.02 * t,
                child: Material(type: MaterialType.transparency, child: child),
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) => _buildMemoItem(
          provider,
          items[index],
          index,
          isDarkMode,
          isSelectionMode,
          reorderableView: true,
        ),
      ),
    );
  }

  /// Colored background revealed while a card is swiped away. The icon stays
  /// on [alignment], the side the card is dragged away from.
  Widget _buildSwipeBackground({
    required bool isDarkMode,
    required IconData icon,
    required Color color,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: isDarkMode ? Colors.white70 : Colors.black87),
    );
  }

  Widget _buildMemoItem(
    MemoProvider provider,
    Memo memo,
    int index,
    bool isDarkMode,
    bool isSelectionMode, {
    required bool reorderableView,
  }) {
    final isSelected = _selectedUuids.contains(memo.uuid);

    Widget card = SwipeActionCard(
      dismissKey: Key(memo.uuid),
      // Right archives, left moves the note to the trash. Both directions
      // require a near-complete swipe (see SwipeActionCard).
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        isDarkMode: isDarkMode,
        icon: Icons.archive,
        color: isDarkMode ? const Color(0xFF3B2E1E) : Colors.amber,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeBackground(
        isDarkMode: isDarkMode,
        icon: Icons.delete_outline,
        color: isDarkMode ? const Color(0xFF4A1E1E) : Colors.red.shade200,
        alignment: Alignment.centerRight,
      ),
      onDismissed: (direction) async {
        final uuid = memo.uuid;
        final l10n = AppLocalizations.of(context)!;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final isArchive = direction == DismissDirection.startToEnd;

        if (isArchive) {
          await provider.archiveMemoStatus(uuid, true);
        } else {
          await provider.deleteMemo(uuid);
        }

        if (!mounted) return;

        scaffoldMessenger.hideCurrentSnackBar();

        final snackBarController = scaffoldMessenger.showSnackBar(
          buildAppSnackBar(
            context,
            message: isArchive ? l10n.noteArchived : l10n.noteSentToTrash,
            duration: const Duration(seconds: 8),
            actionLabel: l10n.undo,
            onAction: () async {
              scaffoldMessenger.hideCurrentSnackBar();
              if (isArchive) {
                await provider.archiveMemoStatus(uuid, false);
              } else {
                await provider.restoreMultiple([uuid]);
              }
            },
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
        searchQuery: _isSearching ? _searchQuery : '',
        // In the reorder view, long-press + drag reorders and a
        // long-press released without dragging toggles selection.
        onLongPress: reorderableView ? null : () => _toggleSelection(memo.uuid),
        onTap: () {
          if (isSelectionMode) {
            _toggleSelection(memo.uuid);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemoDetailScreen(memo: memo),
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          }
        },
      ),
    );

    if (reorderableView) {
      // Always enabled: long-press + drag starts a reorder (1 gesture).
      // Selection comes from the list-level onReorderStart/onReorderEnd.
      card = ReorderableDelayedDragStartListener(
        index: index,
        enabled: true,
        child: card,
      );
    }

    return KeyedSubtree(key: ValueKey(memo.uuid), child: card);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MemoProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final isSelectionMode = _selectedUuids.isNotEmpty;
    final activeMemos = _visibleMemos(provider);
    final selectedMemos = _selectedMemos(provider);
    final allSelectedPinned =
        selectedMemos.isNotEmpty && selectedMemos.every((m) => m.isPinned);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // The system back button closes the search instead of leaving the app.
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) _closeSearch();
      },
      child: Scaffold(
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
                    tooltip: allSelectedPinned ? l10n.unpin : l10n.pin,
                    icon: Icon(
                      allSelectedPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    onPressed: () async {
                      final uuids = List<String>.from(_selectedUuids);
                      final pinned = !allSelectedPinned;
                      _clearSelection();
                      await provider.setPinnedMultiple(uuids, pinned);
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
                        final uuidsToArchive = List<String>.from(
                          _selectedUuids,
                        );
                        _clearSelection();

                        await memoProvider.archiveMultiple(uuidsToArchive);

                        if (!context.mounted) return;

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.hideCurrentSnackBar();

                        final snackBarController = scaffoldMessenger
                            .showSnackBar(
                              buildAppSnackBar(
                                context,
                                message: uuidsToArchive.length > 1
                                    ? AppLocalizations.of(
                                        context,
                                      )!.notesArchivedCount(
                                        '${uuidsToArchive.length}',
                                      )
                                    : AppLocalizations.of(
                                        context,
                                      )!.noteArchived,
                                duration: Duration(seconds: 8),
                                actionLabel: AppLocalizations.of(context)!.undo,
                                onAction: () async {
                                  scaffoldMessenger.hideCurrentSnackBar();
                                  for (var uuid in uuidsToArchive) {
                                    await memoProvider.archiveMemoStatus(
                                      uuid,
                                      false,
                                    );
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
                        final uuidsToDelete = List<String>.from(_selectedUuids);
                        _clearSelection();

                        await memoProvider.deleteMultiple(uuidsToDelete);

                        if (!context.mounted) return;

                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.hideCurrentSnackBar();

                        final snackBarController = scaffoldMessenger
                            .showSnackBar(
                              buildAppSnackBar(
                                context,
                                message: uuidsToDelete.length > 1
                                    ? AppLocalizations.of(
                                        context,
                                      )!.notesSentToTrashCount(
                                        '${uuidsToDelete.length}',
                                      )
                                    : AppLocalizations.of(
                                        context,
                                      )!.noteSentToTrash,
                                duration: Duration(seconds: 8),
                                actionLabel: AppLocalizations.of(context)!.undo,
                                onAction: () async {
                                  scaffoldMessenger.hideCurrentSnackBar();
                                  await memoProvider.restoreMultiple(
                                    uuidsToDelete,
                                  );
                                },
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
                      } else if (value == 'share') {
                        await _shareSelectedNotes();
                      } else if (value == 'kdrive') {
                        await _exportSelectedNotesToKDrive();
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
                      PopupMenuItem(
                        value: 'share',
                        child: Text(AppLocalizations.of(context)!.send),
                      ),
                      PopupMenuItem(
                        value: 'kdrive',
                        child: Text(AppLocalizations.of(context)!.copyToKdrive),
                      ),
                    ],
                  ),
                ],
              )
            : AppBar(
                title: _isSearching
                    ? _buildSearchField(isDarkMode)
                    : Text(
                        'kMemo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                actions: [
                  if (!_isSearching)
                    IconButton(
                      tooltip: l10n.searchNotes,
                      icon: const Icon(Icons.search),
                      onPressed: _toggleSearch,
                    ),
                  // The search field replaces the title, so the actions keep
                  // the same width in both states: the sort icon is always the
                  // last one (rightmost) and never shifts when the search opens.
                  if (_isSearching)
                    IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close),
                      onPressed: _closeSearch,
                    ),
                  IconButton(
                    tooltip: l10n.sortBy,
                    icon: const Icon(Icons.sort),
                    onPressed: _showSortMenu,
                  ),
                ],
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
                    MaterialPageRoute(builder: (context) => ArchiveScreen()),
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
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
        body: _buildBody(provider, activeMemos, isDarkMode, isSelectionMode),
        floatingActionButton: isSelectionMode
            ? null
            : FloatingActionButton(
                backgroundColor: isDarkMode ? Color(0xFF3B2E1E) : Colors.amber,
                onPressed: () async {
                  final newMemo = await provider.createNewMemo();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MemoDetailScreen(memo: newMemo, isNew: true),
                      ),
                    );
                  }
                },
                child: Icon(
                  Icons.add,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
      ),
    );
  }
}
