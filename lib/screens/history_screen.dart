import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reserved_restaurant.dart';
import '../providers/history_provider.dart';
import '../providers/reserved_restaurants_provider.dart';
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
    final reserved = ref.watch(reservedRestaurantsProvider);

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
          if (_tab.index == 1 && reserved.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClearReserved(context, ref, reserved),
              child: const Text('クリア', style: TextStyle(color: Colors.white70)),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: '検索履歴'),
            Tab(text: '予約済み'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SearchHistoryTab(history: history),
          _ReservedTab(reserved: reserved),
        ],
      ),
    );
  }

  void _confirmClearHistory(
      BuildContext context, WidgetRef ref, List history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('検索履歴を消去'),
        content: const Text('これまでの検索をすべて消します。この操作は元に戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
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

  void _confirmClearReserved(
      BuildContext context, WidgetRef ref, List reserved) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('シェア済みのお店を消去'),
        content: const Text('シェア済みのお店をすべて消します。この操作は元に戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              for (final e in reserved) {
                ref
                    .read(reservedRestaurantsProvider.notifier)
                    .remove((e as ReservedRestaurant).id);
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
              child: const Icon(Icons.travel_explore,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('まだ検索したことがないみたい',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('お店を探すと、ここに残るよ',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey.shade500)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.meetingPoint.stationName}駅',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(entry.participantNames.join('、'),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                        const SizedBox(height: 2),
                        Text(_formatDate(entry.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '平均${entry.meetingPoint.averageMinutes.toStringAsFixed(0)}分',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                      ),
                      Text(entry.meetingPoint.fairnessLabel,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
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

// ─── 予約済みタブ ─────────────────────────────────────────────────────────────

class _ReservedTab extends ConsumerWidget {
  const _ReservedTab({required this.reserved});
  final List<ReservedRestaurant> reserved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reserved.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF06C755).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bookmark_rounded,
                  size: 44, color: Color(0xFF06C755)),
            ),
            const SizedBox(height: 24),
            const Text('まだシェアしたお店がないみたい',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('LINEで集合場所を送ると、ここに残るよ',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reserved.length,
      itemBuilder: (ctx, i) {
        final entry = reserved[i];
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
            ref.read(reservedRestaurantsProvider.notifier).remove(entry.id);
          },
          child: _ReservedCard(entry: entry),
        );
      },
    );
  }
}

class _ReservedCard extends StatelessWidget {
  const _ReservedCard({required this.entry});
  final ReservedRestaurant entry;

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
                      // 予約済みバッジ
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06C755).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('シェア済み ✓',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF06C755))),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.restaurantName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(entry.category,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Text(
                  _formatDate(entry.reservedAt),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            if (entry.nearestStation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.train_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${entry.nearestStation}駅',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
            if (entry.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(entry.address,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (entry.lat != null && entry.lng != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                            'https://maps.google.com/maps?daddr=${entry.lat},${entry.lng}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.directions_rounded, size: 14),
                      label: const Text('道順',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        side: const BorderSide(
                            color: Color(0xFF1A73E8), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                if (entry.lat != null &&
                    entry.lng != null &&
                    entry.hotpepperUrl != null)
                  const SizedBox(width: 8),
                if (entry.hotpepperUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                          Uri.parse(entry.hotpepperUrl!),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('予約ページ',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side:
                            BorderSide(color: AppColors.primary, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}
