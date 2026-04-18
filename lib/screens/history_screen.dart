import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restaurant.dart';
import '../models/visited_restaurant.dart';
import '../providers/history_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../theme/app_theme.dart';
import 'restaurant_detail_screen.dart';

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
    final visited = ref.watch(visitedRestaurantsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('履歴',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.divider),
              TabBar(
                controller: _tab,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '検索履歴'),
                  Tab(text: '行ったお店'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _SearchHistoryTab(history: history),
          _VisitedTab(visited: visited),
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
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (entry.restaurants.isEmpty) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => _HistoryRestaurantSheet(
                  entry: entry,
                ),
              );
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー行
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${entry.meetingPoint.stationName}駅エリア',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Text(_formatDate(entry.createdAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textTertiary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(entry.participantNames.join('、'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    // お店リスト
                    if (entry.restaurants.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...entry.restaurants.take(3).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              r.category,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                            if (r.rating > 0) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.star_rounded,
                                  size: 11, color: AppColors.star),
                              const SizedBox(width: 2),
                              Text(
                                r.rating.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
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

// ─── 行ったお店タブ ─────────────────────────────────────────────────────────────


class _VisitedTab extends ConsumerWidget {
  const _VisitedTab({required this.visited});
  final List<VisitedRestaurant> visited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (visited.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_rounded,
                  size: 44, color: Colors.green.shade400),
            ),
            const SizedBox(height: 24),
            const Text('まだ行ったお店がないみたい',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('行ったお店を記録すると、ここに残るよ',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visited.length,
      itemBuilder: (ctx, i) {
        final entry = visited[i];
        return _VisitedCard(entry: entry);
      },
    );
  }
}

class _VisitedCard extends StatelessWidget {
  const _VisitedCard({required this.entry});
  final VisitedRestaurant entry;

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
                  _formatDate(entry.visitedAt),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            if (entry.groupNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  children: [
                    const TextSpan(
                        text: 'グループ：',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: entry.groupNames.join('、')),
                  ],
                ),
              ),
            ],
            if (entry.nearestStation.isNotEmpty) ...[
              const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

// ─── 検索履歴 → お店一覧シート ──────────────────────────────────────────────────

class _HistoryRestaurantSheet extends StatelessWidget {
  const _HistoryRestaurantSheet({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final r = entry;
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                '${r.meetingPoint.stationName}駅エリア',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r.participantNames.join('、'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ...r.restaurants.map((rest) => _RestaurantRow(
                restaurant: rest,
                groupNames: r.participantNames,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RestaurantDetailScreen(
                      restaurant: Restaurant(
                        id: 'hist_${rest.name}',
                        name: rest.name,
                        stationIndex: r.meetingPoint.stationIndex,
                        category: rest.category,
                        rating: rest.rating,
                        reviewCount: 0,
                        priceLabel: '',
                        priceAvg: 0,
                        tags: const [],
                        emoji: '',
                        description: '',
                        distanceMinutes: 0,
                        address: rest.address,
                        openHours: '',
                        lat: rest.lat,
                        lng: rest.lng,
                        hotpepperUrl: rest.hotpepperUrl,
                        imageUrl: rest.imageUrl,
                      ),
                      groupNames: r.participantNames,
                    ),
                  ));
                },
              )),
        ],
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({
    required this.restaurant,
    required this.groupNames,
    required this.onTap,
  });
  final HistoryRestaurant restaurant;
  final List<String> groupNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    restaurant.category,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            if (restaurant.rating > 0) ...[
              Icon(Icons.star_rounded, size: 12, color: AppColors.star),
              const SizedBox(width: 2),
              Text(
                restaurant.rating.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
