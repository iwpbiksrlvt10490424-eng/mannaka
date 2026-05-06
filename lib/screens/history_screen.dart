import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/secrets.dart';
import '../models/restaurant.dart';
import '../models/visited_restaurant.dart';
import '../providers/history_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../theme/app_theme.dart';
import '../utils/photo_ref.dart';
import '../widgets/manual_restaurant_add_sheet.dart';
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
      floatingActionButton: _tab.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showManualRestaurantAddSheet(context,
                  initialTarget: AddTarget.visited),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('お店を追加',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
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
                    // 1 位の店の写真をカード上部に 5 枚スワイプで表示（予約済みと同形式）
                    if (entry.restaurants.isNotEmpty &&
                        entry.restaurants.first.photoRefs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: _VisitedPhotoCarousel(
                              urls: PhotoRef.listToUrls(
                                entry.restaurants.first.photoRefs,
                                googleApiKey: Secrets.placesApiKey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // ヘッダー: 駅 + 日付
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.train_rounded,
                              size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.meetingPoint.stationName}駅周辺で検索',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        Text(_formatDate(entry.createdAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(entry.participantNames.join('・'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    // 候補要約: 最初の店 + 件数（履歴は再利用の入口、店舗の縦並びでなく要約）
                    // タップした店だけが残る新仕様により、件数は通常 1〜5 件。
                    if (entry.restaurants.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _candidatesSummary(entry.restaurants),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  /// 候補要約: 「○○ 他 N 件」形式（履歴カードが縦に伸びるのを防ぐ）。
  /// 1 件のみなら店名だけ、複数なら「先頭店 他 N 件」。
  String _candidatesSummary(List<HistoryRestaurant> restaurants) {
    if (restaurants.isEmpty) return '';
    final first = restaurants.first.name;
    if (restaurants.length == 1) return first;
    return '$first 他 ${restaurants.length - 1} 件';
  }
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
            // 5 枚スワイプ写真プレビュー（予約済みカードと同形式）
            if (entry.photoRefs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: _VisitedPhotoCarousel(
                      urls: PhotoRef.listToUrls(entry.photoRefs,
                          googleApiKey: Secrets.placesApiKey),
                    ),
                  ),
                ),
              ),
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
    // 履歴 1 件あたり最大 10 店 + 写真カルーセルで縦長になるため、
    // SizedBox で固定高さを与えてから Column + Expanded で内部をスクロール可能にする。
    // mainAxisSize.min と Expanded は同時使用で layout 矛盾を起こすので max（デフォルト）。
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: sheetHeight,
      child: Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
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
                '${r.meetingPoint.stationName}駅',
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
          // 店リストを Expanded + SingleChildScrollView でスクロール可能に
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: r.restaurants
                    .map((rest) => _RestaurantRow(
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
                                  imageUrls: PhotoRef.listToUrls(
                                    rest.photoRefs,
                                    googleApiKey: Secrets.placesApiKey,
                                  ),
                                ),
                                groupNames: r.participantNames,
                              ),
                            ));
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
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
    final photoUrls = PhotoRef.listToUrls(
      restaurant.photoRefs,
      googleApiKey: Secrets.placesApiKey,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 詳細画面を開く前に 5 枚スワイプで写真を確認できる。
            if (photoUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _RowPhotoCarousel(urls: photoUrls),
                  ),
                ),
              ),
            Row(
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
                if ((restaurant.rating ?? 0) > 0) ...[
                  Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                  const SizedBox(width: 2),
                  Text(
                    restaurant.rating!.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 履歴行用の小型 PageView 写真カルーセル。
/// 詳細画面の _PhotoCarousel と違いインジケータがコンパクト。
class _RowPhotoCarousel extends StatefulWidget {
  const _RowPhotoCarousel({required this.urls});
  final List<String> urls;

  @override
  State<_RowPhotoCarousel> createState() => _RowPhotoCarouselState();
}

class _RowPhotoCarouselState extends State<_RowPhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return CachedNetworkImage(
        imageUrl: widget.urls.first,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: Colors.grey.shade100),
        errorWidget: (_, __, ___) =>
            Container(color: Colors.grey.shade200),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.urls[i],
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: Colors.grey.shade100),
            errorWidget: (_, __, ___) =>
                Container(color: Colors.grey.shade200),
          ),
        ),
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_index + 1} / ${widget.urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 行ったお店カード用の小型 PageView 写真カルーセル。
/// 予約済みカードの _ReservedPhotoCarousel と同じ見た目。
class _VisitedPhotoCarousel extends StatefulWidget {
  const _VisitedPhotoCarousel({required this.urls});
  final List<String> urls;

  @override
  State<_VisitedPhotoCarousel> createState() => _VisitedPhotoCarouselState();
}

class _VisitedPhotoCarouselState extends State<_VisitedPhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return CachedNetworkImage(
        imageUrl: widget.urls.first,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey.shade100),
        errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
      );
    }
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.urls[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade100),
            errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
          ),
        ),
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_index + 1} / ${widget.urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
