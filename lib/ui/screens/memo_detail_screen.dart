// lib/ui/screens/memo_detail_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';

/// Captura de estado do editor para suporte a desfazer/refazer.
class _MemoEditorSnapshot {
  final String title;
  final String text;
  final bool isChecklistMode;
  final List<String> listTexts;
  final List<bool> listCheckStates;

  const _MemoEditorSnapshot({
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

// ---------- Regiões e resultados de busca ----------
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

  const MemoDetailScreen({super.key, required this.memo});

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

  // Foco do campo de texto (modo nota corrida)
  late FocusNode _textFocusNode;

  // Foco do campo de pesquisa
  late FocusNode _searchFocusNode;

  // Estado da pesquisa inline
  final TextEditingController _searchQueryController = TextEditingController();
  int _searchMatchIndex = -1;
  List<_Match> _searchMatches = [];

  // Histórico de desfazer/refazer
  final List<_MemoEditorSnapshot> _history = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 50;

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

  // Controladores do Modo Texto e Lista Sequencial
  late TextEditingController _textNoteController;
  final List<TextEditingController> _listControllers = [];
  final List<FocusNode> _listFocusNodes = [];
  final List<bool> _listCheckStates = [];

  // Abordagem Joplin: IDs estáticos e persistentes por elemento
  final List<String> _listUuids = [];
  final List<int> _listIds = [];
  late String _textBlockUuid;
  int _textBlockId = 0;

  // Listas de Anexos Locais
  List<String> _imageAttachments = [];
  List<String> _audioAttachments = [];
  List<String> _linksValues = [];

  final _uuidGenerator = const Uuid();

  // Paleta de cores claras (tons suaves/pastel)
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
    const Color(0xFFF5F5F5),
  ];

  // Paleta de cores escuras (tons profundos e suaves para o Dark Mode)
  final List<Color> _darkColorsPalette = [
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

  // Lista de 16 caminhos de imagens predefinidas (assets da app)
  final List<String> _bgImagesPalette = List.generate(
    16,
    (i) => 'assets/backgrounds/bg_$i.png',
  );

  @override
  void initState() {
    super.initState();
    _currentMemo = widget.memo;
    _titleController = TextEditingController(text: _currentMemo.title);
    _textNoteController = TextEditingController();
    _textFocusNode = FocusNode();
    _searchFocusNode = FocusNode();

    // ID fixo para o bloco de texto caso a nota se mantenha em texto corrido
    _textBlockUuid = '${_currentMemo.uuid}_text_fixed';
    _loadMemoData();
  }

  @override
  void dispose() {
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
    _persistData();
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

  // Captura os blocos persistidos e sincroniza os IDs reais do SQLite
  void _pushSnapshot() {
    if (_isRestoring || !mounted) return;

    final snapshot = _MemoEditorSnapshot.fromEditor(this);

    // Evita duplicatas consecutivas do mesmo estado
    if (_historyIndex >= 0 &&
        _history[_historyIndex].title == snapshot.title &&
        _history[_historyIndex].text == snapshot.text &&
        _history[_historyIndex].isChecklistMode == snapshot.isChecklistMode &&
        _history[_historyIndex].listTexts == snapshot.listTexts &&
        _history[_historyIndex].listCheckStates == snapshot.listCheckStates) {
      return;
    }

    // Descarta o histórico futuro quando um novo estado é criado
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(snapshot);
    _historyIndex = _history.length - 1;

    // Limita o tamanho do histórico
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
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Link'),
        content: TextField(
          controller: linkTextController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://exemplo.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (linkTextController.text.trim().isNotEmpty) {
                setState(
                  () => _linksValues.add(linkTextController.text.trim()),
                );
                _persistData();
              }
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tirar foto'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Adicionar imagem da galeria'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.mic_none_outlined),
                title: const Text('Gravar nota de áudio'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.link_outlined),
                title: const Text('Adicionar link'),
                onTap: () {
                  Navigator.pop(ctx);
                  _promptLinkInsertion();
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined),
                title: const Text('Alternar para Caixas de verificação'),
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

  void _showStyleMenu(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorsPalette = isDarkMode ? _darkColorsPalette : _lightColorsPalette;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DefaultTabController(
              length: 2,
              child: Scaffold(
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
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _bgImagesPalette.length,
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
    // Pequeno atraso para dar tempo do layout renderizar antes de pedir foco
    Future.delayed(const Duration(milliseconds: 100), () {
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
    // Devolve foco ao editor de texto
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

  // ---------- Menu de opções (três pontos) ----------
  Future<void> _showOptionsMenu() async {
    final provider = context.read<MemoProvider>();

    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search_outlined),
              title: const Text('Localizar na nota'),
              onTap: () => Navigator.pop(ctx, 'find'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Enviar'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Fazer copia'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Última edição'),
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

    if (action == 'find') {
      _activateSearch();
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar nota'),
          content: const Text('Esta nota será movida para a lixeira. Deseja continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await provider.deleteMemo(widget.memo.uuid);
        if (mounted) Navigator.pop(context);
      }
    } else if (action == 'share') {
      final textToShare = '''
${_titleController.text}

${_isChecklistMode ? _listControllers.map((c) => '${_listCheckStates[_listControllers.indexOf(c)] ? '☑' : '☐'} ${c.text}').join('\n') : _textNoteController.text}
''';
      await SharePlus.instance.share(
        ShareParams(
          text: textToShare.trim(),
          title: _titleController.text.isNotEmpty ? _titleController.text : 'Nota',
        ),
      );
    } else if (action == 'copy') {
      await provider.duplicateMultiple([widget.memo.uuid]);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        ? const Color(0xFF1E1E1E).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);

    return Container(
      decoration: noteBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: iconColor),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.push_pin_outlined, color: iconColor),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.notification_add_outlined, color: iconColor),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.archive_outlined, color: iconColor),
              onPressed: () async {
                await context.read<MemoProvider>().archiveMemoStatus(widget.memo.uuid, true);
                if (mounted) Navigator.pop(context);
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
              padding: const EdgeInsets.only(left: 16.0, right: 4.0),
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
                        hintText: 'Título',
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
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'clear_checklist',
                          child: Text('Limpar caixas de verificação'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _isChecklistMode
                    ? _buildChecklistLayout(textColor, hintColor, isDarkMode)
                    : _buildTextLayout(textColor, hintColor),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
    );
  }

  Widget _buildBottomToolbar(bool isDarkMode, Color footerBgColor) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
            onPressed: () => _showAttachmentMenu(context),
          ),
          IconButton(
            icon: Icon(
              Icons.palette_outlined,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            onPressed: () => _showStyleMenu(context),
          ),
          IconButton(
            icon: Icon(
              Icons.text_format_outlined,
              color: isDarkMode ? Colors.white60 : Colors.black54,
            ),
            onPressed: () => _showStyleMenu(context),
          ),
          const Spacer(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
              key: const ValueKey('search_field'),
              controller: _searchQueryController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: textColor, fontSize: 16),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Localizar texto',
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                prefixIcon: Icon(Icons.search_outlined, size: 20, color: hintColor),
                suffixIcon: _searchQueryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.edit, size: 18),
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
                // Restaurar foco após rebuild para evitar que o cursor salte
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
              '${_searchMatchIndex + 1} de ${_searchMatches.length}',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
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
              icon: const Icon(Icons.arrow_downward, size: 18),
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
            icon: const Icon(Icons.close, size: 20),
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
        hintText: 'Nota',
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
      itemBuilder: (context, index) {
        final isChecked = _listCheckStates[index];
        final blockId = index < _listIds.length ? _listIds[index] : 0;
        final blockUuid = index < _listUuids.length ? _listUuids[index] : '';

        return Padding(
          key: ValueKey('item_row_${blockId}_$blockUuid'),
          padding: const EdgeInsets.symmetric(vertical: 2.0),
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
              const SizedBox(width: 8.0),
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
                    hintText: 'Item de lista',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
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
        padding: const EdgeInsets.all(8),
        itemCount: _imageAttachments.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
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
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          ..._linksValues.map(
            (l) => Chip(
              avatar: const Icon(Icons.link, size: 14),
              label: Text(l, style: const TextStyle(fontSize: 12)),
              onDeleted: () {
                setState(() => _linksValues.remove(l));
                _persistData();
              },
            ),
          ),
          ..._audioAttachments.map(
            (a) => Chip(
              avatar: const Icon(Icons.mic, size: 14),
              label: const Text(
                'Gravação de voz',
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
