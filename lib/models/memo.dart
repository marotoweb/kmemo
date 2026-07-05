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
    final List<Color> colorsPalette = [
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

    final cardColor = isSelected
        ? Colors.amber.shade50
        : (memo.colorIndex < colorsPalette.length
              ? colorsPalette[memo.colorIndex]
              : Colors.white);

    List<String> images = [];
    try {
      images = List<String>.from(jsonDecode(memo.imageAttachments));
    } catch (_) {}

    return Dismissible(
      key: Key(memo.uuid),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.archive_outlined, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.green.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.archive_outlined, color: Colors.white),
      ),
      onDismissed: (direction) {
        context.read<MemoProvider>().archiveMemo(memo.uuid);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nota arquivada')));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber.shade700 : Colors.grey.shade200,
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
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check_circle,
                    color: Colors.amber.shade800,
                    size: 22,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (images.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.image, size: 14, color: Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              'Anexos de imagem (${images.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Atualizado: ${_formatDate(memo.updatedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
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
