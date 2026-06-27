// lib/ui/widgets/memo_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kmemo/database/database.dart';
import '../../providers/memo_provider.dart';
import '../screens/memo_detail_screen.dart';

class MemoCard extends StatelessWidget {
  final Memo memo;
  const MemoCard({super.key, required this.memo});

  @override
  Widget build(BuildContext context) {
    final String displayTitle = memo.title.trim().isEmpty
        ? 'Sem título'
        : memo.title;
    final String timeString = '${memo.updatedAt.day}/${memo.updatedAt.month}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemoDetailScreen(memo: memo),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: memo.title.trim().isEmpty
                            ? Colors.black38
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: Colors.black38,
                ),
                onPressed: () => _showDeleteDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Apagar nota?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text('Esta ação não pode ser revertida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black45),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MemoProvider>().deleteMemo(memo.uuid);
            },
            child: const Text(
              'Apagar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
