// lib/ui/widgets/memo_card.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../providers/memo_provider.dart';

class MemoCard extends StatelessWidget {
  final Memo memo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MemoCard({
    super.key,
    required this.memo,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Paleta de cores claras (tons suaves/pastel)
    final List<Color> lightColorsPalette = [
      Colors.white,
      Colors.red.shade50,
      Colors.orange.shade50,
      Colors.yellow.shade50,
      Colors.green.shade50,
      Colors.teal.shade50,
      Colors.blue.shade50,
      Colors.indigo.shade50,
      Colors.purple.shade50,
      Colors.pink.shade50,
      Colors.brown.shade50,
      Colors.blueGrey.shade50,
      Colors.amber.shade100,
      Colors.lightGreen.shade100,
      Colors.cyan.shade50,
      const Color(0xFFF5F5F5),
    ];

    // Paleta de cores escuras (tons profundos, dessaturados e suaves para o Dark Mode)
    final List<Color> darkColorsPalette = [
      const Color(0xFF1E1E1E), // Fundo base escuro
      const Color(0xFF3B1A1A), // Vermelho escuro suave
      const Color(0xFF3D2C1E), // Laranja escuro suave
      const Color(0xFF3D361E), // Amarelo/Âmbar escuro suave
      const Color(0xFF1E3322), // Verde escuro suave
      const Color(0xFF1E3331), // Teal escuro suave
      const Color(0xFF1E2A3B), // Azul escuro suave
      const Color(0xFF261E3B), // Índigo escuro suave
      const Color(0xFF331E3B), // Roxo escuro suave
      const Color(0xFF3B1E32), // Rosa escuro suave
      const Color(0xFF2E2621), // Castanho escuro suave
      const Color(0xFF252B2E), // Azul-acinzentado escuro suave
      const Color(0xFF3B2E1E), // Âmbar profundo suave
      const Color(0xFF27331E), // Verde-lima escuro suave
      const Color(0xFF1E3338), // Ciano escuro suave
      const Color(0xFF2C2C2C), // Cinzento escuro secundário
    ];

    final colorsPalette = isDarkMode ? darkColorsPalette : lightColorsPalette;

    final cardColor = isSelected
        ? (isDarkMode ? const Color(0xFF4A3810) : Colors.amber.shade50)
        : (memo.colorIndex < colorsPalette.length
              ? colorsPalette[memo.colorIndex]
              : (isDarkMode ? const Color(0xFF1E1E1E) : Colors.white));

    final textColor = isDarkMode ? Colors.white70 : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white60 : Colors.black45;
    final mutedTextColor = isDarkMode ? Colors.white38 : Colors.black38;

    List<String> images = [];
    try {
      images = List<String>.from(jsonDecode(memo.imageAttachments));
    } catch (_) {}

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? Colors.amber.shade400 : Colors.amber.shade700)
                : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelected) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.check_circle,
                      color: isDarkMode
                          ? Colors.amber.shade400
                          : Colors.amber.shade800,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (memo.title.isNotEmpty) ...[
                        Text(
                          memo.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                      FutureBuilder<List<Block>>(
                        future: context.read<MemoProvider>().loadBlocks(
                          memo.uuid,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final blocks = snapshot.data!;
                          final isChecklist = blocks.any(
                            (b) => b.type == BlockType.checklist,
                          );
                          if (isChecklist) {
                            final sortedBlocks = List<Block>.from(blocks)
                              ..sort(
                                (a, b) => a.sortOrder.compareTo(b.sortOrder),
                              );
                            final hasMoreThanEight = sortedBlocks.length > 8;
                            final visibleBlocks = sortedBlocks.take(8).toList();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...visibleBlocks.map((block) {
                                    final checked =
                                        block.content['checked'] as bool? ??
                                        false;
                                    final text =
                                        block.content['text']?.toString() ?? '';
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          checked
                                              ? Icons.check_box_outlined
                                              : Icons.check_box_outline_blank,
                                          size: 14,
                                          color: checked
                                              ? mutedTextColor
                                              : subtitleColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            text.isEmpty
                                                ? 'Item de lista'
                                                : text,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: checked
                                                  ? mutedTextColor
                                                  : textColor,
                                              decoration: checked
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                  if (hasMoreThanEight)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 20.0,
                                        top: 2.0,
                                      ),
                                      child: Text(
                                        '...',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          } else {
                            final contentText = blocks
                                .map((b) => b.content['text']?.toString() ?? '')
                                .join('\n');
                            if (contentText.trim().isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final lines = contentText.split('\n');
                            final hasMoreThanEight = lines.length > 8;
                            final visibleText = hasMoreThanEight
                                ? '${lines.take(8).join('\n')}\n...'
                                : contentText;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                visibleText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                  height: 1.3,
                                ),
                                maxLines: 9,
                                overflow: TextOverflow.clip,
                              ),
                            );
                          }
                        },
                      ),
                      if (images.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.image, size: 13, color: subtitleColor),
                            const SizedBox(width: 4),
                            Text(
                              'Anexos de imagem (${images.length})',
                              style: TextStyle(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Atualizado: ${_formatDate(memo.updatedAt)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
