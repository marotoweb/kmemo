// lib/ui/screens/memo_detail_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';
import 'package:kmemo/l10n/app_localizations.dart';

/// Captures editor state to support undo/redo.
class _MemoEditorSnapshot {
  final String title;
  final String text;
  final bool isChecklistMode;
  final List<String> listTexts;
  final List<bool> listCheckStates;

  _MemoEditorSnapshot({
    required this.title,
    required this.text,
    required this.isChecklistMode,
    required this.listTexts,
    required this.listCheckStates,
  });

  factory _MemoEditorSnapshot.fromEditor(_MemoDetailScreenState editor) {
    return _MemoEditorSnapshot(
      title: editor._titleController.text,
      text: editor._textNoteController.text,
      isChecklistMode: editor._isChecklistMode,
      listTexts: editor._listControllers.map((c) => c.text).toList(),
      listCheckStates: List<bool>.from(editor._listCheckStates),
    );
  }
}

// ---------- Search regions and results ----------
class _SearchRegion {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String text;
  _SearchRegion(this.controller, this.focusNode, this.text);
}

class _Match {
  final int regionIndex;
  final int start;
  final int end;
  _Match(this.regionIndex, this.start, this.end);
}

class MemoDetailScreen extends StatefulWidget {
  final Memo memo;
  final bool isNew;

  const MemoDetailScreen({super.key, required this.memo, this.isNew = false});

  @override
  State<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends State<MemoDetailScreen> {
  late Memo _currentMemo;
  late TextEditingController _titleController;
  bool _isChecklistMode = false;
  bool _isLoading = true;
  bool _isRestoring = false;
  bool _isSearchActive = false;

  // Focus of the text field (running note mode)
  late FocusNode _textFocusNode;

  // Focus of the search field
  late FocusNode _searchFocusNode;

  // Inline search state
  final TextEditingController _searchQueryController = TextEditingController();
  int _searchMatchIndex = -1;
  List<_Match> _searchMatches = [];

  // Undo/redo history
  final List<_MemoEditorSnapshot> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

  // Controllers for text and sequential list modes
  late TextEditingController _textNoteController;
  final List<TextEditingController> _listControllers = [];
  final List<FocusNode> _listFocusNodes = [];
  final List<bool> _listCheckStates = [];

  // Joplin approach: static and persistent IDs per element
  final List<String> _listUuids = [];
  final List<int> _listIds = [];
  late String _textBlockUuid;
  int _textBlockId = 0;

  // Lists of local attachments
  List<String> _imageAttachments = [];
  List<String> _audioAttachments = [];
  List<String> _linksValues = [];

  final _uuidGenerator = Uuid();

  // Original state captured at load time to detect real changes before persisting.
  String? _originalTitle;
  String? _originalText;
  List<Map<String, dynamic>> _originalChecklists = [];
  String _originalImageAttachments = '[]';
  String _originalAudioAttachments = '[]';
  String _originalLinkAttachments = '[]';
  int _originalColorIndex = 0;
  int _originalBgImageIndex = -1;

  /// Returns true if the note has no title, content, or attachments.
  bool _isEmpty() {
    if (_titleController.text.trim().isNotEmpty) return false;
    if (_isChecklistMode) {
      for (var c in _listControllers) {
        if (c.text.trim().isNotEmpty) return false;
      }
    } else {
      if (_textNoteController.text.trim().isNotEmpty) return false;
    }
    if (_imageAttachments.isNotEmpty ||
        _audioAttachments.isNotEmpty ||
        _linksValues.isNotEmpty) {
      return false;
    }
    return true;
  }

  bool get _isDirty {
    if (_originalTitle == null || _originalText == null) return false;
    if (_titleController.text != _originalTitle) return true;
    if (_currentMemo.colorIndex != _originalColorIndex) return true;
    if (_currentMemo.bgImageIndex != _originalBgImageIndex) return true;
    if (_isChecklistMode) {
      if (_listControllers.length != _originalChecklists.length) return true;
      for (int i = 0; i < _listControllers.length; i++) {
        final o = _originalChecklists[i];
        if (_listControllers[i].text != (o['text'] as String? ?? '')) return true;
        if (_listCheckStates[i] != (o['checked'] as bool? ?? false)) return true;
      }
      return false;
    }
    if (_textNoteController.text != _originalText) return true;
    if (jsonEncode(_imageAttachments) != _originalImageAttachments) return true;
    if (jsonEncode(_audioAttachments) != _originalAudioAttachments) return true;
    if (jsonEncode(_linksValues) != _originalLinkAttachments) return true;
    return false;
  }

  void _captureOriginalState() {
    _originalTitle = _titleController.text;
    _originalText = _textNoteController.text;
    _originalChecklists = _listControllers.asMap().entries.map((e) {
      return {
        'uuid': _listUuids[e.key],
        'text': e.value.text,
        'checked': _listCheckStates[e.key],
      };
    }).toList();
    _originalImageAttachments = jsonEncode(_imageAttachments);
    _originalAudioAttachments = jsonEncode(_audioAttachments);
    _originalLinkAttachments = jsonEncode(_linksValues);
    _originalColorIndex = _currentMemo.colorIndex;
    _originalBgImageIndex = _currentMemo.bgImageIndex;
  }

  final List<Color> _lightColorsPalette = [
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

  final List<Color> _darkColorsPalette = [
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

  // List of predefined background image paths (app assets)
  // Only images that exist in the bundle are included.
  List<String> _bgImagesPalette = [];

  @override
  void initState() {
    super.initState();
    _currentMemo = widget.memo;
    _titleController = TextEditingController(text: _currentMemo.title);
    _textNoteController = TextEditingController();
    _textFocusNode = FocusNode();
    _searchFocusNode = FocusNode();

    // Fixed id for the text block when the note stays in running text mode
    _textBlockUuid = '${_currentMemo.uuid}_text_fixed';
    _loadAvailableBgImages();
    _loadMemoData();
  }

  Future<void> _loadAvailableBgImages() async {
    final bundle = DefaultAssetBundle.of(context);
    final available = <String>[];
    for (int i = 0; i < 16; i++) {
      final path = 'assets/backgrounds/bg_$i.png';
      try {
        await bundle.load(path);
        available.add(path);
      } catch (_) {
        // Image does not exist, skipping
      }
    }
    if (mounted) {
      setState(() => _bgImagesPalette = available);
    }
  }

  @override
  void dispose() {
    // Reject empty notes when closing the screen (e.g. app backgrounded)
    if (!_isLoading && widget.isNew && !_isDirty && _isEmpty()) {
      try {
        context.read<MemoProvider>().rejectEmptyMemo(widget.memo.uuid);
      } catch (_) {
        // Context may no longer be available; ignore
      }
    } else if (!_isLoading) {
      // Try to save the data before closing the screen
      _persistData();
    }
    _titleController.dispose();
    _textNoteController.dispose();
    _textFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchQueryController.dispose();
    _clearListControllers();
    super.dispose();
  }

  void _clearListControllers() {
    for (var controller in _listControllers) {
      controller.dispose();
    }
    for (var node in _listFocusNodes) {
      node.dispose();
    }
    _listControllers.clear();
    _listFocusNodes.clear();
    _listCheckStates.clear();
    _listUuids.clear();
    _listIds.clear();
  }

  Future<void> _loadMemoData() async {
    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    final provider = context.read<MemoProvider>();
    final blocks = await provider.loadBlocks(_currentMemo.uuid);

    setState(() {
      try {
        _imageAttachments = List<String>.from(
          jsonDecode(_currentMemo.imageAttachments),
        );
        _audioAttachments = List<String>.from(
          jsonDecode(_currentMemo.audioAttachments),
        );
        _linksValues = List<String>.from(
          jsonDecode(_currentMemo.linkAttachments),
        );
      } catch (_) {
        _imageAttachments = [];
        _audioAttachments = [];
        _linksValues = [];
      }

      if (blocks.isNotEmpty &&
          blocks.any((b) => b.type == BlockType.checklist)) {
        _isChecklistMode = true;
        _clearListControllers();
        final sortedBlocks = List<Block>.from(blocks)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (var block in sortedBlocks) {
          _listControllers.add(
            TextEditingController(
              text: block.content['text']?.toString() ?? '',
            ),
          );
          _listFocusNodes.add(FocusNode());
          _listCheckStates.add(block.content['checked'] as bool? ?? false);
          _listUuids.add(block.uuid);
          _listIds.add(block.id);
        }
      } else {
        _isChecklistMode = false;
        if (blocks.isNotEmpty) {
          _textBlockUuid = blocks.first.uuid;
          _textBlockId = blocks.first.id;
          _textNoteController.text = blocks
              .map((b) => b.content['text']?.toString() ?? '')
              .join('\n');
        }
      }
      _isLoading = false;
      _pushSnapshot();
      _captureOriginalState();
    });
  }

  void _switchMode(bool toChecklist) {
    if (_isChecklistMode == toChecklist) return;
    setState(() {
      if (toChecklist) {
        final lines = _textNoteController.text.split('\n');
        _clearListControllers();
        if (lines.isEmpty || (lines.length == 1 && lines.first.isEmpty)) {
          _addChecklistItem(0, '', id: _uuidGenerator.v4());
        } else {
          for (int i = 0; i < lines.length; i++) {
            _addChecklistItem(i, lines[i], id: _uuidGenerator.v4());
          }
        }
        _isChecklistMode = true;
      } else {
        final linesToJoin = _listControllers.map((c) => c.text).toList();
        _textNoteController.text = linesToJoin.join('\n');
        _clearListControllers();
        _isChecklistMode = false;
      }
    });
    // Do not persist on load: opening a note must not mark it as modified/unsynced.
    // Persistence happens only when the user edits content (via onChanged).
  }

  void _addChecklistItem(
    int index,
    String text, {
    bool checked = false,
    required String id,
    bool requestFocus = true,
  }) {
    final controller = TextEditingController(text: text);
    final focusNode = FocusNode();
    _listControllers.insert(index, controller);
    _listFocusNodes.insert(index, focusNode);
    _listCheckStates.insert(index, checked);
    _listUuids.insert(index, id);
    _listIds.insert(index, 0);

    if (!_isLoading && requestFocus && !_isRestoring) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => focusNode.requestFocus(),
      );
    }
  }

  void _removeChecklistItem(int index) {
    if (_listControllers.length <= 1) {
      _listControllers[0].clear();
      _listCheckStates[0] = false;
      _persistData();
      return;
    }
    setState(() {
      _listControllers[index].dispose();
      _listFocusNodes[index].dispose();
      _listControllers.removeAt(index);
      _listFocusNodes.removeAt(index);
      _listCheckStates.removeAt(index);
      _listUuids.removeAt(index);
      _listIds.removeAt(index);

      final targetIndex = index > 0 ? index - 1 : 0;
      if (_listFocusNodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _listFocusNodes[targetIndex].requestFocus();
          _listControllers[targetIndex].selection = TextSelection.fromPosition(
            TextPosition(offset: _listControllers[targetIndex].text.length),
          );
        });
      }
    });
    _persistData();
  }

  // Captures persisted blocks and syncs real SQLite IDs
  void _pushSnapshot() {
    if (_isRestoring || !mounted) return;

    final snapshot = _MemoEditorSnapshot.fromEditor(this);

    // Avoids consecutive duplicates of the same state
    if (_historyIndex >= 0 &&
        _history[_historyIndex].title == snapshot.title &&
        _history[_historyIndex].text == snapshot.text &&
        _history[_historyIndex].isChecklistMode == snapshot.isChecklistMode &&
        _history[_historyIndex].listTexts == snapshot.listTexts &&
        _history[_historyIndex].listCheckStates == snapshot.listCheckStates) {
      return;
    }

    // Discards future history when a new state is created
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(snapshot);
    _historyIndex = _history.length - 1;

    // Limits history size
    while (_history.length > _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void _undo() {
    if (!_canUndo) return;
    _historyIndex--;
    _restoreSnapshot(_history[_historyIndex]);
    _persistData(pushSnapshot: false);
  }

  void _redo() {
    if (!_canRedo) return;
    _historyIndex++;
    _restoreSnapshot(_history[_historyIndex]);
    _persistData(pushSnapshot: false);
  }

  void _restoreSnapshot(_MemoEditorSnapshot s) {
    _isRestoring = true;
    setState(() {
      _titleController.text = s.title;
      _textNoteController.text = s.text;
      _isChecklistMode = s.isChecklistMode;
      if (_isChecklistMode) {
        _clearListControllers();
        for (int i = 0; i < s.listTexts.length; i++) {
          _addChecklistItem(
            i,
            s.listTexts[i],
            checked: s.listCheckStates[i],
            id: _uuidGenerator.v4(),
            requestFocus: false,
          );
        }
      }
    });
    _isRestoring = false;
  }

  Future<void> _persistData({bool pushSnapshot = true}) async {
    if (!_isDirty) {
      // No real changes: do not mark note as modified/unsynced.
      return;
    }
    if (pushSnapshot && !_isRestoring && mounted) {
      _pushSnapshot();
    }

    final List<Block> updatedBlocks = [];

    if (_isChecklistMode) {
      for (int i = 0; i < _listControllers.length; i++) {
        updatedBlocks.add(
          Block(
            id: i < _listIds.length ? _listIds[i] : 0,
            uuid: _listUuids[i],
            memoUuid: _currentMemo.uuid,
            type: BlockType.checklist,
            content: {
              'text': _listControllers[i].text,
              'checked': _listCheckStates[i],
            },
            sortOrder: i,
            isDeleted: false,
          ),
        );
      }
    } else {
      updatedBlocks.add(
        Block(
          id: _textBlockId,
          uuid: _textBlockUuid,
          memoUuid: _currentMemo.uuid,
          type: BlockType.text,
          content: {'text': _textNoteController.text},
          sortOrder: 0,
          isDeleted: false,
        ),
      );
    }

    _currentMemo = _currentMemo.copyWith(
      title: _titleController.text,
      imageAttachments: jsonEncode(_imageAttachments),
      audioAttachments: jsonEncode(_audioAttachments),
      linkAttachments: jsonEncode(_linksValues),
    );

    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    _captureOriginalState();
    final savedBlocks = await context.read<MemoProvider>().saveMemo(
      _currentMemo,
      updatedBlocks,
    );

    if (mounted) {
      setState(() {
        if (_isChecklistMode) {
          _listIds.clear();
          for (var b in savedBlocks) {
            _listIds.add(b.id);
          }
        } else {
          if (savedBlocks.isNotEmpty) {
            _textBlockId = savedBlocks.first.id;
          }
        }
      });
    }
  }

  void _promptLinkInsertion() {
    final linkTextController = TextEditingController();
    showDialog(
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      context: context,
      // ignore: use_build_context_synchronously
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addLink),
        content: TextField(
          controller: linkTextController,
          autofocus: true,
          decoration: InputDecoration(hintText: 'https://example.com'),
        ),
        actions: [
          TextButton(
            // ignore: use_build_context_synchronously
            // ignore: use_build_context_synchronously
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              if (linkTextController.text.trim().isNotEmpty) {
                setState(
                  () => _linksValues.add(linkTextController.text.trim()),
                );
                _persistData();
              }
              // ignore: use_build_context_synchronously
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }

  // ignore: use_build_context_synchronously
  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO: implementar captura de foto (Take photo)
              // ListTile(
              //   leading: Icon(Icons.camera_alt_outlined),
              //   title: Text(AppLocalizations.of(context)!.takePhoto),
              //   onTap: () => Navigator.pop(ctx),
              // ),
              // TODO: implementar seleção de imagem da galeria (Add image from gallery)
              // ListTile(
              //   leading: Icon(Icons.image_outlined),
              //   title: Text(AppLocalizations.of(context)!.addImageFromGallery),
              //   onTap: () => Navigator.pop(ctx),
              // ),
              // TODO: implementar gravação de áudio (Record audio note)
              // ListTile(
              //   leading: Icon(Icons.mic_none_outlined),
              //   title: Text(AppLocalizations.of(context)!.recordAudioNote),
              //   onTap: () => Navigator.pop(ctx),
              // ),
              ListTile(
                leading: Icon(Icons.link_outlined),
                title: Text(AppLocalizations.of(context)!.addLinkLower),
                onTap: () {
                  Navigator.pop(ctx);
                  _promptLinkInsertion();
                },
              ),
              ListTile(
                leading: Icon(Icons.check_box_outlined),
                title: Text(AppLocalizations.of(context)!.toggleCheckboxes),
                onTap: () {
                  Navigator.pop(ctx);
                  _switchMode(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ignore: use_build_context_synchronously
  void _showStyleMenu(BuildContext context) {
    // ignore: use_build_context_synchronously
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorsPalette = isDarkMode ? _darkColorsPalette : _lightColorsPalette;

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // ignore: use_build_context_synchronously
          builder: (BuildContext context, StateSetter setModalState) {
            return DefaultTabController(
              length: 2,
              child: Scaffold(
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
                      // ignore: use_build_context_synchronously
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _currentMemo = _currentMemo.copyWith(
                                colorIndex: i,
                                bgImageIndex: -1,
                              );
                            });
                            setState(() {
                              _currentMemo = _currentMemo.copyWith(
                                colorIndex: i,
                                bgImageIndex: -1,
                              );
                            });
                            _persistData();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorsPalette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _currentMemo.bgImageIndex == -1 &&
                                        _currentMemo.colorIndex == i
                                    ? Colors.blue
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300),
                                width:
                                    _currentMemo.bgImageIndex == -1 &&
                                        _currentMemo.colorIndex == i
                                    ? 3
                                    : 1,
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
                      itemCount: _bgImagesPalette.length,
                      // ignore: use_build_context_synchronously
                      itemBuilder: (context, i) {
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _currentMemo = _currentMemo.copyWith(
                                bgImageIndex: i,
                              );
                            });
                            setState(() {
                              _currentMemo = _currentMemo.copyWith(
                                bgImageIndex: i,
                              );
                            });
                            _persistData();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _currentMemo.bgImageIndex == i
                                    ? Colors.blue
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300),
                                width: _currentMemo.bgImageIndex == i ? 3 : 1,
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
              ),
            );
          },
        );
      },
    );
  }

  List<_SearchRegion> _getSearchRegions() {
    final regions = <_SearchRegion>[];
    if (_isChecklistMode) {
      for (int i = 0; i < _listControllers.length; i++) {
        regions.add(_SearchRegion(
          _listControllers[i],
          _listFocusNodes[i],
          _listControllers[i].text,
        ));
      }
    } else {
      regions.add(_SearchRegion(_textNoteController, _textFocusNode, _textNoteController.text));
    }
    return regions;
  }

  List<_Match> _findMatches(String query) {
    final result = <_Match>[];
    if (query.isEmpty) return result;
    final lowerQuery = query.toLowerCase();
    for (int r = 0; r < _getSearchRegions().length; r++) {
      final text = _getSearchRegions()[r].text.toLowerCase();
      int start = 0;
      while (true) {
        final idx = text.indexOf(lowerQuery, start);
        if (idx == -1) break;
        result.add(_Match(r, idx, idx + query.length));
        start = idx + 1;
      }
    }
    return result;
  }

  void _jumpToMatch(_Match match) {
    final region = _getSearchRegions()[match.regionIndex];
    region.controller.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    region.focusNode?.requestFocus();
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
      _searchQueryController.clear();
      _searchMatches = [];
      _searchMatchIndex = -1;
    });
    // Small delay to let the layout render before requesting focus
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _deactivateSearch() {
    setState(() {
      _isSearchActive = false;
      _searchQueryController.clear();
      _searchMatches = [];
      _searchMatchIndex = -1;
    });
    // Returns focus to the text editor
    if (_isChecklistMode && _listFocusNodes.isNotEmpty) {
      _listFocusNodes.last.requestFocus();
    } else {
      _textFocusNode.requestFocus();
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchMatches = _findMatches(query);
      _searchMatchIndex = _searchMatches.isNotEmpty ? 0 : -1;
      if (_searchMatchIndex != -1) {
        _jumpToMatch(_searchMatches[_searchMatchIndex]);
      }
    });
  }

  // ---------- Options menu (three dots) ----------
  Future<void> _showOptionsMenu() async {
    // ignore: use_build_context_synchronously
    // ignore: use_build_context_synchronously
    final provider = context.read<MemoProvider>();

    final String? action = await showModalBottomSheet<String>(
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.search_outlined),
              title: Text(AppLocalizations.of(context)!.findInNote),
              onTap: () => Navigator.pop(ctx, 'find'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text(AppLocalizations.of(context)!.delete),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text(AppLocalizations.of(context)!.send),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: Icon(Icons.content_copy_outlined),
              title: Text(AppLocalizations.of(context)!.makeCopy),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: Icon(Icons.access_time_outlined),
              title: Text(AppLocalizations.of(context)!.lastEdited),
              subtitle: Text(
                '${_currentMemo.updatedAt.day}/${_currentMemo.updatedAt.month}/${_currentMemo.updatedAt.year} '
                '${_currentMemo.updatedAt.hour.toString().padLeft(2, '0')}:${_currentMemo.updatedAt.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'find') {
      _activateSearch();
    } else if (action == 'delete') {
      // ignore: use_build_context_synchronously
      // ignore: use_build_context_synchronously
      final confirmed = await showDialog<bool>(
        // ignore: use_build_context_synchronously
        // ignore: use_build_context_synchronously
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteNote),
          content: Text(AppLocalizations.of(context)!.noteWillBeMovedToTrash),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
       if (confirmed == true) {
         // ignore: use_build_context_synchronously
         final navigator = Navigator.of(context);
         await provider.deleteMemo(widget.memo.uuid);
         await _persistData();
         if (mounted) navigator.pop();
       }
    } else if (action == 'share') {
      final textToShare = '''
${_titleController.text}

${_isChecklistMode ? _listControllers.map((c) => '${_listCheckStates[_listControllers.indexOf(c)] ? '☑' : '☐'} ${c.text}').join('\n') : _textNoteController.text}
''';
      await SharePlus.instance.share(
        ShareParams(
          text: textToShare.trim(),
          title: _titleController.text.isNotEmpty ? _titleController.text : AppLocalizations.of(context)!.note,
        ),
      );
    } else if (action == 'copy') {
      await provider.duplicateMultiple([widget.memo.uuid]);
      // ignore: use_build_context_synchronously
      final navigator = Navigator.of(context);
                 await _persistData();
                 if (mounted) navigator.pop();
    }
  }

  @override
  // ignore: use_build_context_synchronously
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ignore: use_build_context_synchronously
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColorsPalette = isDarkMode
        ? _darkColorsPalette
        : _lightColorsPalette;

    final Decoration noteBackgroundDecoration = _currentMemo.bgImageIndex != -1
        ? BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_bgImagesPalette[_currentMemo.bgImageIndex]),
              fit: BoxFit.cover,
            ),
          )
        : BoxDecoration(color: activeColorsPalette[_currentMemo.colorIndex]);

    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final hintColor = isDarkMode ? Colors.white38 : Colors.black38;
    final iconColor = isDarkMode ? Colors.white70 : Colors.black87;
    final footerBgColor = isDarkMode
        ? Color(0xFF1E1E1E).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    return Container(
      decoration: noteBackgroundDecoration,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          // Reject only brand-new notes that were never edited and are still empty.
          // Notes that were edited and then cleared are kept (persisted normally).
          if (widget.isNew && !_isDirty && _isEmpty()) {
            await context.read<MemoProvider>().rejectEmptyMemo(widget.memo.uuid);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.emptyNoteRejected,
                  ),
                ),
              );
              Navigator.of(context).pop();
            }
            return;
          }
          // Ensures data is saved before leaving the screen
          await _persistData();
          // ignore: use_build_context_synchronously
          final navigator = Navigator.of(context);
                 await _persistData();
                 if (mounted) navigator.pop();
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: iconColor),
              onPressed: () async {
                if (widget.isNew && !_isDirty && _isEmpty()) {
                  await context.read<MemoProvider>().rejectEmptyMemo(widget.memo.uuid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.emptyNoteRejected,
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                  return;
                }
                await _persistData();
                // ignore: use_build_context_synchronously
                final navigator = Navigator.of(context);
                 await _persistData();
                 if (mounted) navigator.pop();
              },
            ),
          actions: [
            // TODO: implementar fixar nota (pin)
            // IconButton(
            //   icon: Icon(Icons.push_pin_outlined, color: iconColor),
            //   onPressed: () {},
            // ),
            // TODO: implementar notificação/lembrete (notification)
            // IconButton(
            //   icon: Icon(Icons.notification_add_outlined, color: iconColor),
            //   onPressed: () {},
            // ),
            IconButton(
              icon: Icon(Icons.archive_outlined, color: iconColor),
              onPressed: () async {
                // ignore: use_build_context_synchronously
                // ignore: use_build_context_synchronously
                await context.read<MemoProvider>().archiveMemoStatus(widget.memo.uuid, true);
                // ignore: use_build_context_synchronously
                final navigator = Navigator.of(context);
                 await _persistData();
                 if (mounted) navigator.pop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_imageAttachments.isNotEmpty) _buildImagesPreview(),
            if (_linksValues.isNotEmpty || _audioAttachments.isNotEmpty)
              _buildMetadataWidgets(),
            Padding(
              padding: EdgeInsets.only(left: 16.0, right: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.title,
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: hintColor),
                      ),
                      onChanged: (_) => _persistData(),
                    ),
                  ),
                  if (_isChecklistMode)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: iconColor),
                      onSelected: (value) {
                        if (value == 'clear_checklist') _switchMode(false);
                      },
                      // ignore: use_build_context_synchronously
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'clear_checklist',
                          child: Text(AppLocalizations.of(context)!.clearCheckboxes),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: _isChecklistMode
                    ? _buildChecklistLayout(textColor, hintColor, isDarkMode)
                    : _buildTextLayout(textColor, hintColor),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                height: 50,
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  color: footerBgColor,
                  border: Border(
                    top: BorderSide(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: _isSearchActive
                    ? _buildSearchToolbar(isDarkMode, footerBgColor)
                    : _buildBottomToolbar(isDarkMode, footerBgColor),
              ),
            ),
          ],
        ),
      ),
    ), // Closes WillPopScope
  ); // Closes Container
  }

  Widget _buildBottomToolbar(bool isDarkMode, Color footerBgColor) {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: footerBgColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.add_box_outlined,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            // ignore: use_build_context_synchronously
            onPressed: () => _showAttachmentMenu(context),
          ),
          IconButton(
            icon: Icon(
              Icons.palette_outlined,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            // ignore: use_build_context_synchronously
            onPressed: () => _showStyleMenu(context),
          ),
          // TODO: implementar formatação de texto (negrito, itálico, etc.)
          // IconButton(
          //   icon: Icon(
          //     Icons.text_format_outlined,
          //     color: isDarkMode ? Colors.white60 : Colors.black54,
          //   ),
          //   // ignore: use_build_context_synchronously
          //   onPressed: () => _showStyleMenu(context),
          // ),
          Spacer(),
          IconButton(
            icon: Icon(
              Icons.undo,
              color: _canUndo
                  ? (isDarkMode ? Colors.white60 : Colors.black54)
                  : Colors.grey,
            ),
            onPressed: _canUndo ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo,
              color: _canRedo
                  ? (isDarkMode ? Colors.white60 : Colors.black54)
                  : Colors.grey,
            ),
            onPressed: _canRedo ? _redo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchToolbar(bool isDarkMode, Color footerBgColor) {
    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final hintColor = isDarkMode ? Colors.white38 : Colors.black38;

    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: footerBgColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey('search_field'),
              controller: _searchQueryController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: textColor, fontSize: 16),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.findText,
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                prefixIcon: Icon(Icons.search_outlined, size: 20, color: hintColor),
                suffixIcon: _searchQueryController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.highlight_remove, size: 18),
                        color: hintColor,
                        onPressed: () {
                          _searchQueryController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                _performSearch(value);
                // Restore focus after rebuild to avoid cursor jumping
                Future.delayed(Duration.zero, () {
                  if (mounted && _isSearchActive) {
                    _searchFocusNode.requestFocus();
                  }
                });
              },
            ),
          ),
          if (_searchMatches.isNotEmpty) ...[
            Text(
              AppLocalizations.of(context)!.searchCounter('${_searchMatchIndex + 1}', '${_searchMatches.length}'),
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.arrow_upward, size: 18),
              color: _searchMatchIndex <= 0 ? Colors.grey : textColor,
              onPressed: _searchMatchIndex <= 0
                  ? null
                  : () {
                      setState(() {
                        _searchMatchIndex--;
                        _jumpToMatch(_searchMatches[_searchMatchIndex]);
                      });
                    },
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward, size: 18),
              color: _searchMatchIndex >= _searchMatches.length - 1
                  ? Colors.grey
                  : textColor,
              onPressed: _searchMatchIndex >= _searchMatches.length - 1
                  ? null
                  : () {
                      setState(() {
                        _searchMatchIndex++;
                        _jumpToMatch(_searchMatches[_searchMatchIndex]);
                      });
                    },
            ),
          ],
          IconButton(
            icon: Icon(Icons.close, size: 20),
            color: isDarkMode ? Colors.white60 : Colors.black54,
            onPressed: _deactivateSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTextLayout(Color textColor, Color hintColor) {
    return TextField(
      key: ValueKey('text_input_${_textBlockId}_$_textBlockUuid'),
      textCapitalization: TextCapitalization.sentences,
      controller: _textNoteController,
      focusNode: _textFocusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: TextStyle(fontSize: 16, color: textColor),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.note,
        border: InputBorder.none,
        hintStyle: TextStyle(color: hintColor),
      ),
      onChanged: (_) => _persistData(),
    );
  }

  Widget _buildChecklistLayout(
    Color textColor,
    Color hintColor,
    bool isDarkMode,
  ) {
    return ListView.builder(
      itemCount: _listControllers.length,
      // ignore: use_build_context_synchronously
      itemBuilder: (context, index) {
        final isChecked = _listCheckStates[index];
        final blockId = index < _listIds.length ? _listIds[index] : 0;
        final blockUuid = index < _listUuids.length ? _listUuids[index] : '';

        return Padding(
          key: ValueKey('item_row_${blockId}_$blockUuid'),
          padding: EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isChecked,
                  activeColor: Colors.grey,
                  onChanged: (val) {
                    setState(() {
                      _listCheckStates[index] = val ?? false;
                    });
                    _persistData();
                  },
                ),
              ),
              SizedBox(width: 8.0),
              Expanded(
                child: TextField(
                  key: ValueKey('input_${blockId}_$blockUuid'),
                  controller: _listControllers[index],
                  focusNode: _listFocusNodes[index],
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 16,
                    color: isChecked
                        ? (isDarkMode ? Colors.white24 : Colors.black38)
                        : textColor,
                    decoration: isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.listItem,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                    hintStyle: TextStyle(color: hintColor),
                  ),
                  onSubmitted: (_) {
                    setState(
                      () => _addChecklistItem(
                        index + 1,
                        '',
                        id: _uuidGenerator.v4(),
                      ),
                    );
                    _persistData();
                  },
                  onChanged: (_) => _persistData(),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.clear,
                  size: 18,
                  color: isDarkMode ? Colors.white38 : Colors.black26,
                ),
                onPressed: () => _removeChecklistItem(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagesPreview() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(8),
        itemCount: _imageAttachments.length,
        // ignore: use_build_context_synchronously
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_imageAttachments[index]),
                    height: 90,
                    width: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _imageAttachments.removeAt(index));
                      _persistData();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadataWidgets() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          ..._linksValues.map(
            (l) => Chip(
              avatar: Icon(Icons.link, size: 14),
              label: Text(l, style: TextStyle(fontSize: 12)),
              onDeleted: () {
                setState(() => _linksValues.remove(l));
                _persistData();
              },
            ),
          ),
          ..._audioAttachments.map(
            (a) => Chip(
              avatar: Icon(Icons.mic, size: 14),
              label: Text(
                AppLocalizations.of(context)!.voiceRecording,
                style: TextStyle(fontSize: 12),
              ),
              onDeleted: () {
                setState(() => _audioAttachments.remove(a));
                _persistData();
              },
            ),
          ),
        ],
      ),
    );
  }
}
