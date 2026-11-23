// lib/ui/screens/memo_detail_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../services/docx_export_service.dart';
import '../../database/database.dart';
import '../../models/background_images.dart';
import '../../models/note_palette.dart';
import '../../providers/memo_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/image_attachment_service.dart';
import '../../services/link_preview_service.dart';
import '../../services/media_picker.dart';
import 'package:kmemo/l10n/app_localizations.dart';
import '../cloud_export.dart';
import '../widgets/app_snackbar.dart';
import '../share_actions.dart';
import 'sync_settings_screen.dart';

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

// Inline search tints. Every match is tinted; the one the arrows are on uses a
// stronger colour. Both are painted behind the glyphs, so the text stays
// readable in light, dark and over a background image.
const Color _kSearchMatchTint = Color(0x66FFC107); // amber, 40 %
const Color _kSearchCurrentTint = Color(0xBFFF8F00); // orange, 75 %

/// Text controller that tints ranges of its text.
///
/// Only the checklist items use it: their field paints its own opaque text, so
/// a background style is visible. The running-note body cannot use it, because
/// its field paints transparent text: the tint would cover the glyphs of the
/// [Text.rich] layer below. That layer tints its own spans instead.
class _SearchHighlightController extends TextEditingController {
  _SearchHighlightController({super.text});

  List<TextRange> _matches = const [];
  TextRange? _current;

  void setMatches(List<TextRange> matches, TextRange? current) {
    _matches = matches;
    _current = current;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (_matches.isEmpty || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    // Keep the composition underline: an IME that is converting a word still
    // has to show it while the matches are tinted.
    final composing =
        withComposing && value.isComposingRangeValid ? value.composing : null;
    final points = <int>{0, text.length};
    for (final r in _matches) {
      points.add(r.start);
      points.add(r.end);
    }
    if (composing != null) {
      points.add(composing.start);
      points.add(composing.end);
    }
    final sorted = points.where((p) => p >= 0 && p <= text.length).toList()
      ..sort();
    final spans = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (end <= start) continue;
      var segmentStyle = style ?? const TextStyle();
      final current = _current;
      if (current != null && current.start <= start && end <= current.end) {
        segmentStyle =
            segmentStyle.copyWith(backgroundColor: _kSearchCurrentTint);
      } else if (_matches.any((r) => r.start <= start && end <= r.end)) {
        segmentStyle = segmentStyle.copyWith(backgroundColor: _kSearchMatchTint);
      }
      if (composing != null &&
          composing.start <= start &&
          end <= composing.end) {
        segmentStyle = segmentStyle.copyWith(
          decoration: TextDecoration.underline,
        );
      }
      spans.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}

class MemoDetailScreen extends StatefulWidget {
  final Memo memo;
  final bool isNew;

  /// Injected by tests; the app uses the platform implementations.
  final MediaPicker? mediaPicker;
  final ImageAttachmentService? imageAttachmentService;

  const MemoDetailScreen({
    super.key,
    required this.memo,
    this.isNew = false,
    this.mediaPicker,
    this.imageAttachmentService,
  });

  @override
  State<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends State<MemoDetailScreen> {
  late Memo _currentMemo;
  late TextEditingController _titleController;
  bool _isChecklistMode = false;
  bool _isLoading = true;
  bool _isRestoring = false;
  bool _isImportingImage = false;
  bool _isSearchActive = false;

  late final MediaPicker _mediaPicker;
  late final ImageAttachmentService _imageAttachmentService;

  // Focus of the text field (running note mode)
  late FocusNode _textFocusNode;

  // Focus of the search field
  late FocusNode _searchFocusNode;

  // Inline search state
  final TextEditingController _searchQueryController = TextEditingController();
  // Typing is debounced and ignored while the IME is composing: searching on
  // every keystroke jumped to the result, took the focus out of the field and
  // broke the composition (reported for Japanese input).
  Timer? _searchDebounce;

  /// The query the marks on screen belong to.
  ///
  /// An IME can commit a finished composition without changing the text, and
  /// `onChanged` is not called for that, so the marks would keep the previous
  /// query (with Japanese input the field showed the committed word while the
  /// previous one was still tinted).
  String _lastSearchedQuery = '';
  int _searchMatchIndex = -1;
  List<_Match> _searchMatches = [];

  /// The match the arrows are on, or null when there is no query or no match.
  _Match? get _currentMatch {
    if (_searchMatchIndex < 0 || _searchMatchIndex >= _searchMatches.length) {
      return null;
    }
    return _searchMatches[_searchMatchIndex];
  }

  // Scrolls the running-note body so the match in focus is visible.
  final ScrollController _textScrollController = ScrollController();
  final GlobalKey _bodyTextKey = GlobalKey();

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

  // Link previews shown below the text body.
  final Map<String, LinkPreview?> _linkPreviews = {};
  final Set<String> _linkPreviewLoading = {};
  final Set<String> _linkPreviewRemoved = {};
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;

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
        if (_listUuids[i] != (o['uuid'] as String? ?? '')) return true;
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

  @override
  void initState() {
    super.initState();
    _currentMemo = widget.memo;
    _mediaPicker = widget.mediaPicker ?? MediaPicker();
    _imageAttachmentService =
        widget.imageAttachmentService ?? ImageAttachmentService();
    _titleController = TextEditingController(text: _currentMemo.title);
    _textNoteController = TextEditingController();
    _textFocusNode = FocusNode();
    _searchFocusNode = FocusNode();
    _searchQueryController.addListener(_onSearchValueChanged);

    // Fixed id for the text block when the note stays in running text mode
    _textBlockUuid = '${_currentMemo.uuid}_text_fixed';
    _loadMemoData();
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
    _searchDebounce?.cancel();
    _searchQueryController.removeListener(_onSearchValueChanged);
    _searchQueryController.dispose();
    _textScrollController.dispose();
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
    // The attachment paths are relative; resolve them before the first frame.
    // Tests, and any platform without a path provider, still show the legacy
    // absolute paths.
    try {
      await _imageAttachmentService.ensureBaseDir();
    } catch (_) {
      // Keep going: there is nothing to resolve.
    }

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
            _SearchHighlightController(
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
    _restoreLinkPreviews();
  }

  /// Loads cached previews (no network) and the removed-card state for this note.
  Future<void> _restoreLinkPreviews() async {
    final removed = await LinkPreviewService.loadRemoved(_currentMemo.uuid);
    final urls = LinkPreviewService.extractUrls(_textNoteController.text);
    final cached = <String, LinkPreview>{};
    for (final url in urls) {
      final preview = await LinkPreviewService.loadCached(url);
      if (preview != null) cached[url] = preview;
    }
    if (!mounted) return;
    setState(() {
      _linkPreviewRemoved
        ..clear()
        ..addAll(removed);
      _linkPreviews.addAll(cached);
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
    final controller = _SearchHighlightController(text: text);
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

  void _reorderChecklistItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _listControllers.length ||
        newIndex < 0 ||
        newIndex > _listControllers.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    setState(() {
      final controller = _listControllers.removeAt(oldIndex);
      _listControllers.insert(newIndex, controller);

      final focusNode = _listFocusNodes.removeAt(oldIndex);
      _listFocusNodes.insert(newIndex, focusNode);

      final checked = _listCheckStates.removeAt(oldIndex);
      _listCheckStates.insert(newIndex, checked);

      final uuid = _listUuids.removeAt(oldIndex);
      _listUuids.insert(newIndex, uuid);

      final id = _listIds.removeAt(oldIndex);
      _listIds.insert(newIndex, id);
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

  /// Shows the add/edit link dialog. When [replaceStart]/[replaceEnd] are
  /// given, the URL in that range is replaced (edit mode) instead of inserted.
  void _promptLinkInsertion({
    String? initialUrl,
    int? replaceStart,
    int? replaceEnd,
  }) {
    final linkTextController = TextEditingController(text: initialUrl ?? '');
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
              final url = linkTextController.text.trim();
              if (url.isNotEmpty) {
                final text = _textNoteController.text;
                if (replaceStart != null && replaceEnd != null) {
                  final start = replaceStart.clamp(0, text.length);
                  final end = replaceEnd.clamp(start, text.length);
                  _textNoteController.text =
                      '${text.substring(0, start)}$url${text.substring(end)}';
                  _textNoteController.selection =
                      TextSelection.collapsed(offset: start + url.length);
                } else {
                  final sel = _textNoteController.selection;
                  final start = sel.start >= 0 ? sel.start : text.length;
                  final end = sel.end >= 0 ? sel.end : text.length;
                  final needsBreak =
                      start > 0 && !text.substring(0, start).endsWith('\n');
                  final prefix = needsBreak ? '\n' : '';
                  _textNoteController.text =
                      '${text.substring(0, start)}$prefix$url\n${text.substring(end)}';
                  _textNoteController.selection = TextSelection.collapsed(
                    offset: start + prefix.length + url.length + 1,
                  );
                }
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
              if (_mediaPicker.supportsCamera)
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined),
                  title: Text(AppLocalizations.of(context)!.takePhoto),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSourceKind.camera);
                  },
                ),
              ListTile(
                leading: Icon(Icons.image_outlined),
                title: Text(AppLocalizations.of(context)!.addImageFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSourceKind.gallery);
                },
              ),
              // TODO: implement audio recording (Record audio note)
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

  /// Imports one photo picked from the camera or the gallery.
  ///
  /// The photo is validated and re-encoded by [ImageAttachmentService]; the
  /// resize decision comes from the image settings, and "ask" shows the
  /// confirmation dialog only for a photo larger than the maximum side.
  Future<void> _pickImage(ImageSourceKind source) async {
    if (_isImportingImage) return;
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.read<ThemeProvider>();

    String? picked;
    try {
      picked = await _mediaPicker.pick(source);
    } catch (_) {
      if (mounted) _showImageError(l10n.imageAttachFailed);
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _isImportingImage = true);
    try {
      final probe = await _imageAttachmentService.probe(picked);
      final maxSide = themeProvider.imageMaxSide;
      final tooBig = probe.width > maxSide || probe.height > maxSide;
      var resize = false;

      if (tooBig) {
        switch (themeProvider.imageResizeMode) {
          case ImageResizeMode.always:
            resize = true;
          case ImageResizeMode.never:
            resize = false;
          case ImageResizeMode.ask:
            final answer = await _askResize(probe, maxSide);
            if (answer == null) return;
            resize = answer;
        }
      }

      final imported = await _imageAttachmentService.import(
        sourcePath: picked,
        memoUuid: _currentMemo.uuid,
        maxSide: maxSide,
        resize: resize,
      );
      if (!mounted) return;
      setState(() => _imageAttachments.add(imported.relativePath));
      await _persistData();
    } on ImageAttachmentException catch (error) {
      if (!mounted) return;
      _showImageError(switch (error.error) {
        ImageAttachmentError.tooLarge => l10n.imageTooLarge,
        ImageAttachmentError.unsupported => l10n.imageUnsupported,
        ImageAttachmentError.unreadable => l10n.imageAttachFailed,
      });
    } catch (_) {
      if (mounted) _showImageError(l10n.imageAttachFailed);
    } finally {
      if (mounted) setState(() => _isImportingImage = false);
    }
  }

  /// True resizes, false keeps the resolution, null cancels the import.
  Future<bool?> _askResize(ImageProbe probe, int maxSide) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.resizeImageTitle),
          content: Text(
            l10n.resizeImageBody(
              '${probe.width}',
              '${probe.height}',
              '$maxSide',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.resizeImageKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.resizeImageConfirm),
            ),
          ],
        );
      },
    );
  }

  void _showImageError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(buildAppSnackBar(context, message: message));
  }

  void _openImage(String stored) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(
          child: Image.file(File(_imageAttachmentService.resolve(stored))),
        ),
      ),
    );
  }

  // ignore: use_build_context_synchronously
  void _showStyleMenu(BuildContext context) {
    // ignore: use_build_context_synchronously
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorsPalette = isDarkMode ? kDarkNotePalette : _lightColorsPalette;

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
                      itemCount: noteBackgroundNumbers.length,
                      // ignore: use_build_context_synchronously
                      itemBuilder: (context, i) {
                        final number = noteBackgroundNumbers[i];
                        final isBgSelected =
                            normalizedBackgroundImageIndex(
                              _currentMemo.bgImageIndex,
                            ) ==
                            number;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _currentMemo = _currentMemo.copyWith(
                                bgImageIndex: number,
                              );
                            });
                            setState(() {
                              _currentMemo = _currentMemo.copyWith(
                                bgImageIndex: number,
                              );
                            });
                            _persistData();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isBgSelected
                                    ? Colors.blue
                                    : (isDarkMode
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300),
                                width: isBgSelected ? 3 : 1,
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

  /// Puts [index] in focus and scrolls it into view.
  ///
  /// The caret stays in the search field: moving the focus to the note body on
  /// every arrow ended the IME composition and made the field unusable while
  /// typing. The tint marks the match now, not the text selection.
  void _selectMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return;
    setState(() => _searchMatchIndex = index);
    _applyChecklistHighlights();
    _revealMatch(_searchMatches[index]);
  }

  void _selectNextMatch() {
    if (_searchMatches.isEmpty) return;
    _selectMatch((_searchMatchIndex + 1) % _searchMatches.length);
  }

  /// Tints the matches of the checklist items. The running-note body tints its
  /// own spans in [_bodySpans].
  void _applyChecklistHighlights() {
    for (var i = 0; i < _listControllers.length; i++) {
      final controller = _listControllers[i];
      if (controller is! _SearchHighlightController) continue;
      final ranges = <TextRange>[
        for (final m in _searchMatches)
          if (m.regionIndex == i) TextRange(start: m.start, end: m.end),
      ];
      final current = _currentMatch;
      controller.setMatches(
        _isSearchActive ? ranges : const [],
        _isSearchActive && current != null && current.regionIndex == i
            ? TextRange(start: current.start, end: current.end)
            : null,
      );
    }
  }

  void _revealMatch(_Match match) {
    if (_isChecklistMode) {
      // The checklist is a lazy list: bring the item in when the field that
      // owns the match is already built.
      if (match.regionIndex >= _listFocusNodes.length) return;
      final itemContext = _listFocusNodes[match.regionIndex].context;
      if (itemContext != null) {
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 200),
          alignment: 0.5,
        );
      }
      return;
    }
    final render = _bodyTextKey.currentContext?.findRenderObject();
    if (render is! RenderParagraph || !_textScrollController.hasClients) return;
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: match.start, extentOffset: match.end),
    );
    if (boxes.isEmpty) return;
    final rect = boxes.first.toRect();
    final reveal =
        RenderAbstractViewport.of(render).getOffsetToReveal(render, 0.0);
    final target = (reveal.offset + rect.top - 120).clamp(
      0.0,
      _textScrollController.position.maxScrollExtent,
    );
    _textScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
      _searchQueryController.clear();
      _searchMatches = [];
      _searchMatchIndex = -1;
    });
    _applyChecklistHighlights();
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
    _applyChecklistHighlights();
    // Returns focus to the text editor
    if (_isChecklistMode && _listFocusNodes.isNotEmpty) {
      _listFocusNodes.last.requestFocus();
    } else {
      _textFocusNode.requestFocus();
    }
  }

  /// Schedules the search for [query] after a short pause.
  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _performSearch(query);
    });
  }

  /// Catches the end of an IME composition.
  ///
  /// Committing a conversion can leave the text unchanged, and `onChanged` is
  /// not called in that case. Without this the marks stayed on the previous
  /// query while the field already showed the committed one.
  void _onSearchValueChanged() {
    if (!_isSearchActive) return;
    final value = _searchQueryController.value;
    if (value.composing.isValid) return;
    if (value.text == _lastSearchedQuery) return;
    _scheduleSearch(value.text);
  }

  /// Recomputes the matches and tints them, leaving the caret in the field.
  ///
  /// Searching on every keystroke used to jump to the first result and move the
  /// focus to the note body, which ended the IME composition and made the field
  /// unusable for languages that need conversion (Japanese was reported). The
  /// matches are tinted in place now, and only Enter or the arrows move between
  /// them.
  void _performSearch(String query) {
    _lastSearchedQuery = query;
    setState(() {
      _searchMatches = _findMatches(query);
      _searchMatchIndex = _searchMatches.isNotEmpty ? 0 : -1;
    });
    _applyChecklistHighlights();
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
              leading: Icon(Icons.cloud_upload_outlined),
              title: Text(
                CloudExportLabels.of(
                  AppLocalizations.of(context)!,
                  provider.storage,
                ).action,
              ),
              onTap: () => Navigator.pop(ctx, 'copyToCloud'),
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
      final shared = await shareTextOrCopy(
        text: textToShare.trim(),
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : AppLocalizations.of(context)!.note,
      );
      if (!shared && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          buildAppSnackBar(
            context,
            message: AppLocalizations.of(context)!.copiedToClipboard,
          ),
        );
      }
    } else if (action == 'copy') {
      await provider.duplicateMultiple([widget.memo.uuid]);
      // ignore: use_build_context_synchronously
      final navigator = Navigator.of(context);
                 await _persistData();
                 if (mounted) navigator.pop();
    } else if (action == 'copyToCloud') {
      await _exportToRemoteStorage();
    }
  }

  /// Generates a .docx file from the note content and uploads it to the remote
  /// storage that sync is configured with (kDrive or WebDAV).
  Future<void> _exportToRemoteStorage() async {
    final provider = context.read<MemoProvider>();
    final l10n = AppLocalizations.of(context)!;
    final storage = provider.storage;
    final labels = CloudExportLabels.of(l10n, storage);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (storage == null || !storage.isConfigured) {
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: labels.notConfigured,
          actionLabel: l10n.settings,
          onAction: () => navigator.push(
            MaterialPageRoute(builder: (_) => SyncSettingsScreen()),
          ),
        ),
      );
      return;
    }

    final blocks = await provider.loadBlocks(widget.memo.uuid);
    if (!mounted) return;
    final textContent = blocks
        .map((b) => b.content['text']?.toString() ?? '')
        .join('\n');
    final docTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : l10n.note;

    final docxBytes = DocxExportService.buildDocx(
      sections: [DocxSection(title: docTitle, body: textContent)],
    );
    debugPrint('[DocxExport] Generated docx size: ${docxBytes.length} bytes');

    final fileName = DocxExportService.safeFileName(docTitle);

    try {
      await storage.uploadFile(fileName: fileName, bytes: docxBytes);
      if (!mounted) return;
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: labels.successMessage(l10n, storage),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        buildAppSnackBar(
          context,
          message: '${labels.failure}: $e',
          duration: const Duration(seconds: 5),
        ),
      );
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
        ? kDarkNotePalette
        : _lightColorsPalette;

    final bgImagePath = noteBackgroundImagePath(_currentMemo.bgImageIndex);
    final Decoration noteBackgroundDecoration = bgImagePath != null
        ? BoxDecoration(
            image: DecorationImage(
              image: AssetImage(bgImagePath),
              fit: BoxFit.cover,
              // Darken the image so the light text stays readable.
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.38),
                BlendMode.darken,
              ),
            ),
          )
        : BoxDecoration(color: activeColorsPalette[_currentMemo.colorIndex]);

    // With a background image, the image is darkened by a scrim (see the
    // decoration below) and the text is always light.
    final textColor = bgImagePath != null
        ? Colors.white70
        : (isDarkMode ? Colors.white70 : Colors.black87);
    final hintColor = bgImagePath != null
        ? Colors.white38
        : (isDarkMode ? Colors.white38 : Colors.black38);
    final iconColor = bgImagePath != null
        ? Colors.white70
        : (isDarkMode ? Colors.white70 : Colors.black87);
    final footerBgColor = isDarkMode
        ? Color(0xFF1E1E1E).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.9);
    final autoWrap = context.watch<ThemeProvider>().autoWrap;
    final strikethroughChecked = context.watch<ThemeProvider>().strikethroughChecked;

    // Keep a comfortable line length on wide windows: a note body stretched
    // across a 1100 px desktop window is hard to read. Phones are narrower
    // than the target width, so nothing changes there.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sideInset = screenWidth > 900 ? (screenWidth - 860) / 2 : 0.0;

    return Container(
      decoration: noteBackgroundDecoration,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          // Dismiss any pending snackbars (e.g. link preview removed) before leaving.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          // Reject only brand-new notes that were never edited and are still empty.
          // Notes that were edited and then cleared are kept (persisted normally).
          if (widget.isNew && !_isDirty && _isEmpty()) {
            await context.read<MemoProvider>().rejectEmptyMemo(widget.memo.uuid);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                buildAppSnackBar(
                  context,
                  message: AppLocalizations.of(context)!.emptyNoteRejected,
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
                      buildAppSnackBar(
                        context,
                        message: AppLocalizations.of(context)!.emptyNoteRejected,
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
            IconButton(
              tooltip: _currentMemo.isPinned
                  ? AppLocalizations.of(context)!.unpin
                  : AppLocalizations.of(context)!.pin,
              icon: Icon(
                _currentMemo.isPinned
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color: iconColor,
              ),
              onPressed: () async {
                final pinned = !_currentMemo.isPinned;
                setState(() {
                  _currentMemo = _currentMemo.copyWith(isPinned: pinned);
                });
                await context.read<MemoProvider>().setPinnedMultiple(
                  [_currentMemo.uuid],
                  pinned,
                );
              },
            ),
            // TODO: implement notification/reminder (notification)
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
            if (_isImportingImage)
              const LinearProgressIndicator(minHeight: 2),
            if (_imageAttachments.isNotEmpty) _buildImagesPreview(),
            if (_linksValues.isNotEmpty || _audioAttachments.isNotEmpty)
              _buildMetadataWidgets(),
            Padding(
              padding: EdgeInsets.only(
                left: 16.0 + sideInset,
                right: 4.0 + sideInset,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: autoWrap ? null : 1,
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
                padding: EdgeInsets.symmetric(horizontal: 16.0 + sideInset),
                child: _isChecklistMode
                    ? _buildChecklistLayout(textColor, hintColor, isDarkMode, autoWrap, strikethroughChecked)
                    : _buildTextLayout(
                        textColor,
                        hintColor,
                        hasBackgroundImage: bgImagePath != null,
                      ),
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
          // TODO: implement text formatting (bold, italic, etc.)
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
                // Leave the composing text alone: an IME that is converting a
                // word must finish before the matches are recomputed. The end
                // of the conversion arrives through the controller listener.
                if (_searchQueryController.value.composing.isValid) return;
                _scheduleSearch(value);
              },
              onSubmitted: (_) => _selectNextMatch(),
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
                  : () => _selectMatch(_searchMatchIndex - 1),
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward, size: 18),
              color: _searchMatchIndex >= _searchMatches.length - 1
                  ? Colors.grey
                  : textColor,
              onPressed: _searchMatchIndex >= _searchMatches.length - 1
                  ? null
                  : () => _selectMatch(_searchMatchIndex + 1),
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

  Future<void> _fetchLinkPreview(String url) async {
    if (_linkPreviewLoading.contains(url) || _linkPreviews.containsKey(url)) {
      return;
    }
    setState(() => _linkPreviewLoading.add(url));
    final preview = await LinkPreviewService.fetchAndCache(url);
    if (!mounted) return;
    setState(() {
      _linkPreviews[url] = preview;
      _linkPreviewLoading.remove(url);
    });
  }

  void _persistRemovedPreviews() {
    LinkPreviewService.saveRemoved(_currentMemo.uuid, Set.of(_linkPreviewRemoved));
  }

  void _removeLinkPreview(String url) {
    setState(() => _linkPreviewRemoved.add(url));
    _persistRemovedPreviews();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = messenger.showSnackBar(
      buildAppSnackBar(
        context,
        message: l10n.linkPreviewRemoved,
        duration: Duration(seconds: 8),
        actionLabel: l10n.undo,
        onAction: () {
          messenger.hideCurrentSnackBar();
          setState(() => _linkPreviewRemoved.remove(url));
          _persistRemovedPreviews();
        },
      ),
    );
    Future.delayed(Duration(seconds: 8), () {
      try {
        controller.close();
      } catch (_) {}
    });
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!_linkPreviews.containsKey(url) && !_linkPreviewLoading.contains(url)) {
      _fetchLinkPreview(url);
    }
  }

  void _previewLink(String url) {
    final wasRemoved = _linkPreviewRemoved.remove(url);
    if (wasRemoved) _persistRemovedPreviews();
    // If a preview was removed (or cached), force a re-fetch so it shows again.
    if (_linkPreviews.containsKey(url)) {
      _linkPreviews.remove(url);
    }
    _fetchLinkPreview(url);
  }

  /// Builds the visible body text: links are underlined and, while the inline
  /// search is open, every match is tinted (the one in focus more strongly).
  ///
  /// This is the only layer painted with real colours; the field above it has a
  /// transparent style, so a background there would hide the glyphs.
  List<InlineSpan> _bodySpans(String text, TextStyle linkStyle) {
    final links = <TextRange>[
      for (final m in LinkPreviewService.matches(text))
        TextRange(start: m.start, end: m.end),
    ];
    final matches = _isSearchActive
        ? [for (final m in _searchMatches) if (m.regionIndex == 0) m]
        : const <_Match>[];
    if (links.isEmpty && matches.isEmpty) {
      return [TextSpan(text: text)];
    }
    final current = _currentMatch;
    final points = <int>{0, text.length};
    for (final r in links) {
      points.add(r.start);
      points.add(r.end);
    }
    for (final m in matches) {
      points.add(m.start);
      points.add(m.end);
    }
    final sorted = points.where((p) => p >= 0 && p <= text.length).toList()
      ..sort();
    final spans = <InlineSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (end <= start) continue;
      final isLink = links.any((r) => r.start <= start && end <= r.end);
      _Match? match;
      for (final m in matches) {
        if (m.start <= start && end <= m.end) {
          match = m;
          break;
        }
      }
      TextStyle? style = isLink ? linkStyle : null;
      if (match != null) {
        final isCurrent = current != null &&
            current.regionIndex == match.regionIndex &&
            current.start == match.start &&
            current.end == match.end;
        style = (style ?? const TextStyle()).copyWith(
          backgroundColor: isCurrent ? _kSearchCurrentTint : _kSearchMatchTint,
        );
      }
      spans.add(TextSpan(text: text.substring(start, end), style: style));
    }
    return spans;
  }

  /// Finds the live [EditableTextState] of the body field below [element].
  EditableTextState? _findEditableState(Element element, String text) {
    EditableTextState? found;
    void visit(Element el) {
      if (el is StatefulElement && el.state is EditableTextState) {
        final state = el.state as EditableTextState;
        if (state.widget.controller.text == text) {
          found = state;
          return;
        }
      }
      if (found == null) el.visitChildren(visit);
    }

    element.visitChildren(visit);
    return found;
  }

  /// Maps a tap to a character offset using the body field's own render
  /// object, so the hit test matches exactly what the field draws.
  /// Runs after a tap on the body. The field has already moved the caret to
  /// the tapped position, so the caret is the source of truth for the hit.
  void _handleBodyTap(Element bodyElement, Offset globalPosition) {
    final text = _textNoteController.text;
    final selection = _textNoteController.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final caret = selection.baseOffset;
    final editable = _findEditableState(bodyElement, text);
    if (editable == null) return;
    final render = editable.renderEditable;
    final local = render.globalToLocal(globalPosition);
    final caretRect = render.getLocalRectForCaret(TextPosition(offset: caret));

    // Ignore taps that are not next to the caret (e.g. far right of a line).
    if ((local.dx - caretRect.left).abs() > 16) return;
    if ((local.dy - caretRect.center.dy).abs() > caretRect.height / 2) return;

    // The character the caret follows is the one that was tapped.
    final index = caret - 1;
    for (final m in LinkPreviewService.matches(text)) {
      if (index >= m.start && index < m.end) {
        _showLinkMenu(globalPosition, m.group(0)!, m.start, m.end);
        return;
      }
    }
  }

  Future<void> _showLinkMenu(
    Offset globalPosition,
    String url,
    int start,
    int end,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final showLinkPreviews =
        context.read<ThemeProvider>().showLinkPreviews;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (showLinkPreviews)
          PopupMenuItem(value: 'preview', child: Text(l10n.previewLink)),
        PopupMenuItem(value: 'open', child: Text(l10n.openLinkShort)),
        PopupMenuItem(value: 'edit', child: Text(l10n.editLink)),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'preview') {
      _previewLink(url);
    } else if (choice == 'open') {
      _openLink(url);
    } else if (choice == 'edit') {
      _promptLinkInsertion(
        initialUrl: url,
        replaceStart: start,
        replaceEnd: end,
      );
    }
  }

  Widget _buildTextLayout(
    Color textColor,
    Color hintColor, {
    required bool hasBackgroundImage,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final showLinkPreviews =
        context.watch<ThemeProvider>().showLinkPreviews;
    // Shared style and forced strut so the underlined overlay and the
    // editable field lay out every line at exactly the same height.
    // Explicit letter/word spacing so the transparent TextField and the
    // Text.rich overlay use identical glyph metrics. Without this, the field
    // inherits bodyLarge (letterSpacing 0.5) while the overlay inherits
    // bodyMedium (0.25), and the cursor drifts right as the line grows.
    final bodyStyle = TextStyle(
      fontSize: 16,
      height: 1.3,
      letterSpacing: 0,
      wordSpacing: 0,
      color: textColor,
    );
    final bodyStrut = StrutStyle.fromTextStyle(bodyStyle, forceStrutHeight: true);
    // The field lays its text out in a width reduced by the cursor width plus a
    // 1 px gap (RenderEditable._caretMargin). The visible layer below must
    // reserve exactly the same space: otherwise a word that fits in those
    // pixels is wrapped by the field but not by the overlay, and moving the
    // caret at that point jumps a whole line while the word is still drawn on
    // the previous one.
    const double bodyCursorWidth = 2.0;
    const double bodyCaretGap = 1.0;
    final linkStyle = TextStyle(
      decoration: TextDecoration.underline,
      // Over a background image (or in dark mode) the regular blue is too
      // dark; use a light blue that stands out on the scrimmed image.
      color: (hasBackgroundImage || isDarkMode)
          ? Colors.lightBlue.shade200
          : Colors.blue.shade700,
    );
    final text = _textNoteController.text;
    final urls = LinkPreviewService.extractUrls(text)
        .where((u) => !_linkPreviewRemoved.contains(u))
        .toList();

    return LayoutBuilder(
      builder: (viewportContext, viewport) => SingleChildScrollView(
        controller: _textScrollController,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Stack(
            children: [
              // Background: only receives taps on the empty area below the
              // text. Taps on the text field are handled by the field itself,
              // so the cursor is placed instead of selecting text.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _textFocusNode.requestFocus(),
                ),
              ),
              Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (bodyContext, constraints) {
              return Listener(
                onPointerDown: (e) {
                  _pointerDownPosition = e.position;
                  _pointerDownTime = DateTime.now();
                },
                onPointerUp: (e) {
                  final down = _pointerDownPosition;
                  final time = _pointerDownTime;
                  if (down == null || time == null) return;
                  final moved = (e.position - down).distance > 12;
                  final quick =
                      DateTime.now().difference(time) <
                      const Duration(milliseconds: 400);
                  if (!moved && quick) {
                    final position = e.position;
                    final bodyElement = bodyContext as Element;
                    Future.delayed(Duration.zero, () {
                      if (mounted) _handleBodyTap(bodyElement, position);
                    });
                  }
                },
                child: Stack(
                  children: [
                    IgnorePointer(
                      child: Padding(
                        // Same space the field keeps for the caret, so both
                        // layers wrap at the same points.
                        padding: const EdgeInsets.only(
                          right: bodyCursorWidth + bodyCaretGap,
                        ),
                        child: Text.rich(
                          key: _bodyTextKey,
                          TextSpan(
                            style: bodyStyle,
                            children: _bodySpans(text, linkStyle),
                          ),
                          strutStyle: bodyStrut,
                        ),
                      ),
                    ),
                    TextField(
                      key: ValueKey(
                        'text_input_${_textBlockId}_$_textBlockUuid',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      controller: _textNoteController,
                      focusNode: _textFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      cursorColor: textColor,
                      cursorWidth: bodyCursorWidth,
                      strutStyle: bodyStrut,
                      style: bodyStyle.copyWith(color: Colors.transparent),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: AppLocalizations.of(context)!.note,
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: hintColor),
                      ),
                      onChanged: (_) {
                        _persistData();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          if (showLinkPreviews)
            ...urls.map((url) {
              return _buildLinkPreviewCard(
                url,
                _linkPreviews[url],
                _linkPreviewLoading.contains(url),
              );
            }),
        ],
      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkPreviewCard(
    String url,
    LinkPreview? preview,
    bool loading,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // The preview card uses the theme surface, not the note background, so
    // its text must use the surface colors. Using the note text color made it
    // white on the light card when the note had a background image.
    final scheme = Theme.of(context).colorScheme;
    final cardTextColor = scheme.onSurface;
    final cardHintColor = scheme.onSurfaceVariant;
    final domain = Uri.tryParse(url)?.host ?? url;
    final placeholderColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.0),
      elevation: 1,
      child: InkWell(
        onTap: () => _openLink(url),
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (preview?.localImagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(preview!.localImagePath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: placeholderColor,
                      child: Icon(Icons.link, color: cardHintColor),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.link, color: cardHintColor),
                ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview?.title ?? domain,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      preview?.siteName ?? domain,
                      style: TextStyle(fontSize: 12, color: cardHintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: cardHintColor),
                onSelected: (value) {
                  if (value == 'preview') {
                    _previewLink(url);
                  } else if (value == 'open') {
                    _openLink(url);
                  } else if (value == 'copy') {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      buildAppSnackBar(
                        context,
                        message: AppLocalizations.of(context)!.linkCopied,
                      ),
                    );
                  } else if (value == 'remove') {
                    _removeLinkPreview(url);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'preview',
                    child: Text(AppLocalizations.of(context)!.previewLink),
                  ),
                  PopupMenuItem(
                    value: 'open',
                    child: Text(AppLocalizations.of(context)!.openLink),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(AppLocalizations.of(context)!.copyLink),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(AppLocalizations.of(context)!.removePreview),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistLayout(
    Color textColor,
    Color hintColor,
    bool isDarkMode,
    bool autoWrap,
    bool strikethroughChecked,
  ) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: _listControllers.length,
      onReorder: _reorderChecklistItem,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final isChecked = _listCheckStates[index];
        final blockUuid = index < _listUuids.length ? _listUuids[index] : '';
        final rowKey = ValueKey('item_row_$blockUuid');

        return Padding(
          key: rowKey,
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
                  key: ValueKey('input_$blockUuid'),
                  controller: _listControllers[index],
                  focusNode: _listFocusNodes[index],
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: autoWrap ? null : 1,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 16,
                    color: isChecked
                        ? (isDarkMode ? Colors.white24 : Colors.black38)
                        : textColor,
                    decoration: (isChecked && strikethroughChecked)
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
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: isDarkMode ? Colors.white38 : Colors.black26,
                  ),
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
          final stored = _imageAttachments[index];
          final thumb = _imageAttachmentService.thumbnailPath(stored);
          final full = _imageAttachmentService.resolve(stored);
          final preview = File(thumb).existsSync() ? thumb : full;
          return Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _openImage(stored),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(preview),
                      height: 90,
                      width: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 90,
                        width: 90,
                        color: Colors.black26,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final removed = stored;
                      setState(() => _imageAttachments.removeAt(index));
                      await _persistData();
                      await _imageAttachmentService.delete(removed);
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
