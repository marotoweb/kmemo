// lib/ui/screens/memo_detail_screen.dart
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
  final _uuidFactory = const Uuid();
  late TextEditingController _titleController;

  List<Block> _blocks = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo.title);
    _loadOrCreateBlocks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrCreateBlocks() async {
    final provider = context.read<MemoProvider>();
    final existingBlocks = await provider.getBlocksForMemo(widget.memo.uuid);

    setState(() {
      if (existingBlocks.isEmpty) {
        final firstUuid = _uuidFactory.v4();
        _blocks = [
          Block(
            id: 0,
            uuid: firstUuid,
            memoUuid: widget.memo.uuid,
            type: BlockType.text,
            content: const {'text': ''},
            sortOrder: 0,
            isDeleted: false,
          ),
        ];
      } else {
        _blocks = List.from(existingBlocks);
      }

      for (var block in _blocks) {
        final text = block.content['text']?.toString() ?? '';
        _controllers[block.uuid] = TextEditingController(text: text);
        _focusNodes[block.uuid] = FocusNode();
      }
      _isLoading = false;
    });
  }

  Block _createNewBlockInstance(BlockType type, String initialText, int order) {
    final newUuid = _uuidFactory.v4();
    _controllers[newUuid] = TextEditingController(text: initialText);
    _focusNodes[newUuid] = FocusNode();

    return Block(
      id: 0,
      uuid: newUuid,
      memoUuid: widget.memo.uuid,
      type: type,
      content: type == BlockType.checklist
          ? {'text': initialText, 'checked': false}
          : {'text': initialText},
      sortOrder: order,
      isDeleted: false,
    );
  }

  void _insertChecklistItemAt(int index, String text) {
    setState(() {
      final newBlock = _createNewBlockInstance(
        BlockType.checklist,
        text,
        index + 1,
      );
      _blocks.insert(index + 1, newBlock);

      // Reordenar os sortOrder de todos os blocos seguintes
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i] = _blocks[i].copyWith(sortOrder: i);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[newBlock.uuid]?.requestFocus();
      });
    });
  }

  void _removeChecklistItemAt(int index) {
    if (index == 0) return; // Mantém o primeiro item se for o único

    final blockToRemove = _blocks[index];
    final previousBlock = _blocks[index - 1];

    setState(() {
      _controllers[blockToRemove.uuid]?.dispose();
      _controllers.remove(blockToRemove.uuid);
      _focusNodes[blockToRemove.uuid]?.dispose();
      _focusNodes.remove(blockToRemove.uuid);
      _blocks.removeAt(index);

      // Reordenar os sortOrder
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i] = _blocks[i].copyWith(sortOrder: i);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prevFocusNode = _focusNodes[previousBlock.uuid];
        final prevController = _controllers[previousBlock.uuid];
        if (prevFocusNode != null && prevController != null) {
          prevFocusNode.requestFocus();
          // Coloca o cursor no fim do texto do item anterior
          prevController.selection = TextSelection.fromPosition(
            TextPosition(offset: prevController.text.length),
          );
        }
      });
    });
  }

  void _toggleNoteMode(bool convertToList) {
    setState(() {
      final List<Block> newBlocksList = [];

      if (convertToList) {
        final List<String> allLines = [];
        for (var block in _blocks) {
          final text =
              _controllers[block.uuid]?.text ??
              block.content['text']?.toString() ??
              '';
          if (text.contains('\n')) {
            allLines.addAll(text.split('\n'));
          } else {
            allLines.add(text);
          }
        }

        for (var controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();
        _focusNodes.clear();

        if (allLines.isEmpty ||
            (allLines.length == 1 && allLines.first.isEmpty)) {
          newBlocksList.add(
            _createNewBlockInstance(BlockType.checklist, '', 0),
          );
        } else {
          for (int i = 0; i < allLines.length; i++) {
            newBlocksList.add(
              _createNewBlockInstance(BlockType.checklist, allLines[i], i),
            );
          }
        }
      } else {
        final List<String> linesToJoin = [];
        for (var block in _blocks) {
          final text =
              _controllers[block.uuid]?.text ??
              block.content['text']?.toString() ??
              '';
          linesToJoin.add(text);
        }

        for (var controller in _controllers.values) {
          controller.dispose();
        }
        _controllers.clear();
        _focusNodes.clear();

        final combinedText = linesToJoin.join('\n');
        newBlocksList.add(
          _createNewBlockInstance(BlockType.text, combinedText, 0),
        );
      }

      _blocks = newBlocksList;
    });
  }

  Future<void> _saveAndExit() async {
    final List<Block> blocksToSave = _blocks.map((block) {
      final currentText = _controllers[block.uuid]?.text ?? '';
      final updatedContent = Map<String, dynamic>.from(block.content);
      updatedContent['text'] = currentText;
      return block.copyWith(content: updatedContent);
    }).toList();

    await context.read<MemoProvider>().saveMemoContent(
      memoUuid: widget.memo.uuid,
      title: _titleController.text,
      updatedBlocks: blocksToSave,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.black87,
                    ),
                    title: const Text(
                      'Tirar foto',
                      style: TextStyle(fontSize: 16),
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.image_outlined,
                      color: Colors.black87,
                    ),
                    title: const Text(
                      'Adicionar imagem',
                      style: TextStyle(fontSize: 16),
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.check_box_outlined,
                      color: Colors.black87,
                    ),
                    title: const Text(
                      'Caixa de verificação',
                      style: TextStyle(fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleNoteMode(true);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool hasChecklist = _blocks.any((b) => b.type == BlockType.checklist);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _saveAndExit,
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
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 0.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
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
                  ),
                ),
                if (hasChecklist)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onSelected: (value) {
                      if (value == 'clear_checklist') {
                        _toggleNoteMode(false);
                      }
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
            child: ListView.builder(
              itemCount: _blocks.length,
              itemBuilder: (context, index) {
                final block = _blocks[index];
                final isChecked = block.content['checked'] as bool? ?? false;

                final controller = _controllers[block.uuid] ??=
                    TextEditingController(
                      text: block.content['text']?.toString() ?? '',
                    );
                final focusNode = _focusNodes[block.uuid] ??= FocusNode();

                return Padding(
                  key: ValueKey('${block.uuid}_${block.type.name}'),
                  padding: const EdgeInsets.symmetric(
                    vertical: 2.0,
                    horizontal: 8.0,
                  ),
                  child: Row(
                    children: [
                      if (block.type == BlockType.checklist)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: Colors.grey,
                              onChanged: (val) {
                                // Cria uma cópia modificável do mapa atual para evitar o erro de UnmodifiableMap
                                final updatedContent =
                                    Map<String, dynamic>.from(block.content);
                                updatedContent['text'] = val;

                                // Atualiza a referência do bloco na lista em memória sem disparar rebuilds pesados
                                _blocks[index] = block.copyWith(
                                  content: updatedContent,
                                );
                              },
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: block.type == BlockType.checklist
                              ? 1
                              : null,
                          keyboardType: block.type == BlockType.checklist
                              ? TextInputType.text
                              : TextInputType.multiline,
                          textInputAction: block.type == BlockType.checklist
                              ? TextInputAction.next
                              : TextInputAction.newline,
                          style: TextStyle(
                            fontSize: 16,
                            color: isChecked ? Colors.black38 : Colors.black87,
                            decoration: isChecked
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          decoration: InputDecoration(
                            hintText: block.type == BlockType.checklist
                                ? 'Item de lista'
                                : 'Nota',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6.0,
                            ),
                            hintStyle: const TextStyle(color: Colors.black38),
                          ),
                          onChanged: (val) {
                            block.content['text'] = val;
                          },
                          onSubmitted: (val) {
                            if (block.type == BlockType.checklist) {
                              _insertChecklistItemAt(index, '');
                            }
                          },
                        ),
                      ),
                      if (_blocks.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.black26,
                          ),
                          onPressed: () {
                            _removeChecklistItemAt(index);
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
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
                    onPressed: () {},
                  ),
                  const Spacer(),
                  const Text(
                    'Editado hoje',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
