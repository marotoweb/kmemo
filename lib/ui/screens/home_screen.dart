// lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/memo_provider.dart';
import '../widgets/memo_card.dart';
import 'memo_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final memoProvider = context.watch<MemoProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 40,
                  bottom: 16,
                ),
                child: Text(
                  'kMemo',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            if (memoProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (memoProvider.memos.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Nenhuma nota guardada.',
                    style: TextStyle(color: Colors.black38, fontSize: 16),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final memo = memoProvider.memos[index];
                    return MemoCard(memo: memo);
                  }, childCount: memoProvider.memos.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newMemo = await context.read<MemoProvider>().createMemo(
            title: '',
          );
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MemoDetailScreen(memo: newMemo),
              ),
            );
          }
        },
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }
}
