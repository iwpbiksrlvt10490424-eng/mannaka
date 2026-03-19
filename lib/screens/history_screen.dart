import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/history_provider.dart';
import '../providers/visit_log_provider.dart';
import '../models/visit_log.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final logs = ref.watch(visitLogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('履歴',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          if (_tab.index == 0 && history.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearHistory(context, ref, history),
              child: const Text('クリア', style: TextStyle(color: Colors.white70)),
            ),
          if (_tab.index == 1 && logs.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearLogs(context, ref, logs),
              child: const Text('クリア', style: TextStyle(color: Colors.white70)),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '検索履歴'),
            Tab(text: '飲食記録'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SearchHistoryTab(history: history),
          _VisitLogTab(logs: logs),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref, List history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('履歴を削除'),
        content: const Text('すべての履歴を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              for (final e in history) {
                ref.read(historyProvider.notifier).remove(e.id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _confirmClearLogs(BuildContext context, WidgetRef ref, List logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('飲食記録を削除'),
        content: const Text('すべての飲食記録を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              for (final l in logs) {
                ref.read(visitLogProvider.notifier).remove((l as VisitLog).id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}

// ─── 検索履歴タブ ─────────────────────────────────────────────────────────────

class _SearchHistoryTab extends ConsumerWidget {
  const _SearchHistoryTab({required this.history});
  final List history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text('まだ記録がありません',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('お店を探すと、ここに記録されます',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (ctx, i) {
        final entry = history[i];
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.red),
          ),
          onDismissed: (_) {
            HapticFeedback.lightImpact();
            ref.read(historyProvider.notifier).remove(entry.id);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.meetingPoint.stationName}駅',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(entry.participantNames.join('、'),
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(_formatDate(entry.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '平均${entry.meetingPoint.averageMinutes.toStringAsFixed(0)}分',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      Text(entry.meetingPoint.fairnessLabel,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

// ─── 飲食記録タブ ─────────────────────────────────────────────────────────────

class _VisitLogTab extends ConsumerWidget {
  const _VisitLogTab({required this.logs});
  final List<VisitLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant,
                size: 44,
                color: Color(0xFFE67E22),
              ),
            ),
            const SizedBox(height: 24),
            const Text('飲食記録がありません',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('お店の詳細画面から記録できます',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final log = logs[i];
        return Dismissible(
          key: ValueKey(log.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.red),
          ),
          onDismissed: (_) {
            HapticFeedback.lightImpact();
            ref.read(visitLogProvider.notifier).remove(log.id);
          },
          child: _VisitLogCard(log: log, ref: ref),
        );
      },
    );
  }
}

class _VisitLogCard extends StatelessWidget {
  const _VisitLogCard({required this.log, required this.ref});
  final VisitLog log;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.restaurantName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(log.category,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            const SizedBox(width: 8),
                            _StarRating(rating: log.userRating),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(log.visitedAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                      if (log.hotpepperUrl != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(log.hotpepperUrl!),
                              mode: LaunchMode.externalApplication),
                          child: Text('予約ページ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (log.memo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(log.memo,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    int selectedRating = log.userRating ?? 0;
    final memoController = TextEditingController(text: log.memo);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(log.restaurantName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('評価', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text('メモ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: memoController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '感想を入力...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            TextButton(
              onPressed: () {
                ref.read(visitLogProvider.notifier).updateRating(
                      log.id,
                      selectedRating,
                      memoController.text.trim(),
                    );
                Navigator.pop(ctx);
              },
              child:
                  const Text('保存', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    ).then((_) => memoController.dispose());
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}


class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});
  final int? rating;

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Text('未評価', style: TextStyle(fontSize: 11, color: Colors.grey.shade400));
    }
    return Row(
      children: List.generate(5, (i) => Icon(
        i < rating! ? Icons.star_rounded : Icons.star_outline_rounded,
        color: const Color(0xFFF59E0B),
        size: 14,
      )),
    );
  }
}
