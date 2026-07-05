// lib/ui/screens/memo_detail_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';

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

  // Palete completa de 16 cores para o fundo da nota
  final List<Color> _colorsPalette = [
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

    // ID fixo para o bloco de texto caso a nota se mantenha em texto corrido
    _textBlockUuid = '${_currentMemo.uuid}_text_fixed';
    _loadMemoData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textNoteController.dispose();
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
  }) {
    final controller = TextEditingController(text: text);
    final focusNode = FocusNode();
    _listControllers.insert(index, controller);
    _listFocusNodes.insert(index, focusNode);
    _listCheckStates.insert(index, checked);
    _listUuids.insert(index, id);
    _listIds.insert(index, 0);

    if (!_isLoading) {
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
  void _persistData() async {
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
                      itemCount: _colorsPalette.length,
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
                              color: _colorsPalette[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _currentMemo.bgImageIndex == -1 &&
                                        _currentMemo.colorIndex == i
                                    ? Colors.blue
                                    : Colors.grey.shade300,
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
                                    : Colors.grey.shade300,
                                width: _currentMemo.bgImageIndex == i ? 3 : 1,
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Decoration noteBackgroundDecoration = _currentMemo.bgImageIndex != -1
        ? BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_bgImagesPalette[_currentMemo.bgImageIndex]),
              fit: BoxFit.cover,
            ),
          )
        : BoxDecoration(color: _colorsPalette[_currentMemo.colorIndex]);

    return Container(
      decoration: noteBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.push_pin_outlined, color: Colors.black87),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.notification_add_outlined,
                color: Colors.black87,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: Colors.black87),
              onPressed: () {},
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Título',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.black38),
                      ),
                      onChanged: (_) => _persistData(),
                    ),
                  ),
                  if (_isChecklistMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black87),
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
                    ? _buildChecklistLayout()
                    : _buildTextLayout(),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.add_box_outlined,
                        color: Colors.black54,
                      ),
                      onPressed: () => _showAttachmentMenu(context),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.palette_outlined,
                        color: Colors.black54,
                      ),
                      onPressed: () => _showStyleMenu(context),
                    ),
                    const Spacer(),
                    const Text(
                      'Editado recentemente',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextLayout() {
    return TextField(
      key: ValueKey('text_input_${_textBlockId}_$_textBlockUuid'),
      textCapitalization: TextCapitalization.sentences,
      controller: _textNoteController,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      decoration: const InputDecoration(
        hintText: 'Nota',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.black38),
      ),
      onChanged: (_) => _persistData(),
    );
  }

  Widget _buildChecklistLayout() {
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
                    color: isChecked ? Colors.black38 : Colors.black87,
                    decoration: isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Item de lista',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6.0),
                    hintStyle: TextStyle(color: Colors.black38),
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
                icon: const Icon(Icons.clear, size: 18, color: Colors.black26),
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
