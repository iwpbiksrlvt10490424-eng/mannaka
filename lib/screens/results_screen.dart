import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/history_provider.dart';
import '../models/meeting_point.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import '../services/midpoint_service.dart';
import '../utils/share_utils.dart';
import 'restaurant_detail_screen.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with TickerProviderStateMixin {
  TabController? _tab;
  int _tabCount = 0;

  void _rebuildTab(
      int count, List<MeetingPoint> results, SearchNotifier notifier) {
    if (_tabCount == count) return;
    _tab?.dispose();
    _tabCount = count;
    _tab = TabController(length: count, vsync: this);
    _tab!.addListener(() {
      if (_tab!.indexIsChanging) return;
      final idx = _tab!.index;
      if (idx < results.length) {
        notifier.selectMeetingPointAndFetch(results[idx]);
      }
    });
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final results = state.results;
    final tabCount = results.isEmpty ? 1 : min(5, results.length);

    // タブ数が変わったら即座に再構築（フレームをまたぐと不一致エラーになる）
    if (_tabCount != tabCount) {
      _rebuildTab(tabCount, results, notifier);
    }

    final tab = _tab!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        title: const Text(
          'どのお店で会おう',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (state.selectedMeetingPoint != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ShareUtils.shareToLine(state);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06C755),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LINE\nでシェア',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                ShareUtils.share(context, state);
              },
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(historyProvider.notifier).add(
                      state.participants.map((p) => p.name).toList(),
                      state.selectedMeetingPoint!,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('履歴に保存しました'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
            ),
          ],
        ],
        bottom: (!state.isCalculating && results.isNotEmpty)
            ? TabBar(
                controller: tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textTertiary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                tabs: results.take(5).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return Tab(
                    height: 44,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i == 0) ...[
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                        ] else ...[
                          Text('${i + 1}位 ',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                        Text(p.stationName),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: Column(
        children: [
          // エラーバナー
          if (state.errorMessage != null)
            Material(
              color: Colors.red.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(state.errorMessage!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.red.shade700)),
                    ),
                    GestureDetector(
                      onTap: () {
                        final selected = state.selectedMeetingPoint;
                        if (selected != null &&
                            !state.restaurantCache
                                .containsKey(selected.stationIndex)) {
                          notifier.selectMeetingPointAndFetch(selected);
                        } else {
                          notifier.calculate();
                        }
                      },
                      child: Text('もう一度試す',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700)),
                    ),
                  ],
                ),
              ),
            ),
          // メインコンテンツ
          Expanded(
            child: state.isCalculating
                ? const _SkeletonTab()
                : results.isEmpty
                    ? _EmptyState(onReset: () {})
                    : TabBarView(
                        controller: tab,
                        children: results.take(5).toList().map((point) {
                          return _MeetingPointTab(
                            key: ValueKey(point.stationIndex),
                            point: point,
                            state: state,
                            notifier: notifier,
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── 集合候補タブ ─────────────────────────────────────────────────────────────

class _MeetingPointTab extends StatefulWidget {
  const _MeetingPointTab({
    super.key,
    required this.point,
    required this.state,
    required this.notifier,
  });
  final MeetingPoint point;
  final SearchState state;
  final SearchNotifier notifier;

  @override
  State<_MeetingPointTab> createState() => _MeetingPointTabState();
}

class _MeetingPointTabState extends State<_MeetingPointTab> {
  String? _selectedCategory;

  List<Restaurant> get _restaurants {
    final state = widget.state;
    final idx = widget.point.stationIndex;

    List<Restaurant> base;
    if (state.selectedMeetingPoint?.stationIndex == idx) {
      base = state.hotpepperRestaurants;
    } else if (state.restaurantCache.containsKey(idx)) {
      base = state.restaurantCache[idx]!;
    } else {
      return [];
    }

    // centroid がある場合は MidpointService.scoreRestaurants で正しくスコアリング
    if (state.hasCentroid) {
      final scored = MidpointService.scoreRestaurants(
        participants: state.participants,
        centroidLat: state.centroidLat!,
        centroidLng: state.centroidLng!,
        baseRestaurants: base,
        category: _selectedCategory,
      );
      return scored.map((s) => s.restaurant).toList();
    }

    // centroid なしのフォールバック（通常は発生しない）
    if (_selectedCategory != null) {
      base = base.where((r) => r.category == _selectedCategory).toList();
    }
    return [...base]..sort((a, b) {
        if (a.isReservable != b.isReservable) return a.isReservable ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });
  }

  bool get _isLoading {
    final state = widget.state;
    final idx = widget.point.stationIndex;
    return state.isCalculating ||
        (state.selectedMeetingPoint?.stationIndex == idx &&
            state.hotpepperRestaurants.isEmpty &&
            !state.restaurantCache.containsKey(idx));
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final restaurants = _restaurants;
    final categories = MidpointService.getAllCategories();

    return Column(
      children: [
        // ─ 駅ヘッダー ──────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.train_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${point.stationName}駅エリア',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '平均 ${point.averageMinutes.toStringAsFixed(0)}分 · 最大 ${point.maxMinutes}分',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _FairnessChip(score: point.fairnessScore),
            ],
          ),
        ),
        const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),

        // ─ ジャンルフィルター ────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          child: SizedBox(
            height: 44,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent
                ],
                stops: [0.0, 0.04, 0.96, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _filterChip('すべて', _selectedCategory == null,
                      () => setState(() => _selectedCategory = null)),
                  ...categories.map((c) => _filterChip(
                        c,
                        _selectedCategory == c,
                        () => setState(() =>
                            _selectedCategory =
                                _selectedCategory == c ? null : c),
                      )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),

        // ─ レストランリスト ──────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const _SkeletonTab()
              : restaurants.isEmpty
                  ? _EmptyState(
                      onReset: () => setState(() => _selectedCategory = null))
                  : Stack(
                      children: [
                        ListView.builder(
                          padding:
                              const EdgeInsets.only(top: 12, bottom: 32),
                          itemCount: restaurants.length,
                          itemBuilder: (ctx, i) {
                            final r = restaurants[i];
                            return i == 0
                                ? _HeroCard(
                                    restaurant: r,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RestaurantDetailScreen(
                                                restaurant: r),
                                      ),
                                    ),
                                  )
                                : _CompactCard(
                                    restaurant: r,
                                    rank: i + 1,
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RestaurantDetailScreen(
                                                restaurant: r),
                                      ),
                                    ),
                                  );
                          },
                        ),
                        if (widget.state.isCalculating)
                          Positioned.fill(
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.7),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 12),
                                    Text('みんなに合うお店を探してます...',
                                        style: TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ─── フェアネスチップ ──────────────────────────────────────────────────────────

class _FairnessChip extends StatelessWidget {
  const _FairnessChip({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final (label, color) = score >= 0.85
        ? ('みんな均等', AppColors.success)
        : score >= 0.65
            ? ('ほぼ公平', const Color(0xFF2563EB))
            : ('少し差あり', AppColors.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── ヒーローカード（1位） ────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.restaurant, required this.onTap});
  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final catBg = AppColors.getCategoryBg(r.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                    ? Image.network(
                        r.imageUrl!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imageFallback(catBg, 56),
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _imageFallback(catBg, 56),
                      )
                    : _imageFallback(catBg, 56),
              ),
            ),
            // コンテンツ
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // おすすめラベル
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: r.isReservable
                          ? AppColors.primaryLight
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          r.isReservable
                              ? Icons.check_circle_outline_rounded
                              : Icons.emoji_events_rounded,
                          size: 12,
                          color: r.isReservable
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          r.isReservable ? '予約可能 · No.1' : 'おすすめ No.1',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: r.isReservable
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 店名
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // カテゴリ · 価格 · 評価
                  Row(
                    children: [
                      Text(r.category,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const Text('  ·  ',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)),
                      Text(r.priceStr,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      if (r.rating > 0) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.star_rounded,
                            color: AppColors.star, size: 14),
                        const SizedBox(width: 2),
                        Text(r.ratingStr,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // CTAボタン
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '詳しく見る',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _imageFallback(Color bg, double iconSize) => Container(
      color: bg,
      child: Center(
        child: Icon(Icons.restaurant_menu_outlined,
            size: iconSize, color: Colors.white.withValues(alpha: 0.6)),
      ),
    );

// ─── コンパクトカード（2位以降） ─────────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard(
      {required this.restaurant, required this.rank, required this.onTap});
  final Restaurant restaurant;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final catBg = AppColors.getCategoryBg(r.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 写真
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                    ? Image.network(
                        r.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imageFallback(catBg, 32),
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : _imageFallback(catBg, 32),
                      )
                    : _imageFallback(catBg, 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ランク
                  Text(
                    '$rank位',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rank == 2
                          ? const Color(0xFF9E9E9E)
                          : rank == 3
                              ? const Color(0xFF8B5E3C)
                              : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 店名 + 評価
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (r.rating > 0)
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: AppColors.star, size: 13),
                            const SizedBox(width: 2),
                            Text(r.ratingStr,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.category}  ·  ${r.priceStr}  ·  徒歩${r.distanceMinutes}分',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (r.isReservable)
                        _SmallBadge('予約可', AppColors.success),
                      if (r.hasPrivateRoom) ...[
                        const SizedBox(width: 4),
                        _SmallBadge('個室', const Color(0xFF7C3AED)),
                      ],
                      if (r.isFemalePopular) ...[
                        const SizedBox(width: 4),
                        _SmallBadge('女性人気', AppColors.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── 小バッジ ─────────────────────────────────────────────────────────────────

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── スケルトンローディング ────────────────────────────────────────────────────

class _SkeletonTab extends StatefulWidget {
  const _SkeletonTab();

  @override
  State<_SkeletonTab> createState() => _SkeletonTabState();
}

class _SkeletonTabState extends State<_SkeletonTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, i) => _SkeletonCard(opacity: _anim.value),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.opacity});
  final double opacity;

  Widget _box(double w, double h, {double radius = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(80, 80, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(40, 12),
                const SizedBox(height: 6),
                _box(160, 16),
                const SizedBox(height: 6),
                _box(120, 12),
                const SizedBox(height: 6),
                _box(80, 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 空状態 ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu_outlined,
                  size: 36, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('このエリアでは見つかりませんでした',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('ジャンルを広げるか、出発駅を変えてみてください',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ジャンルを絞り込み解除',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── フィルターチップ ─────────────────────────────────────────────────────────

Widget _filterChip(String label, bool sel, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? AppColors.primaryLight : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: sel ? AppColors.primary : AppColors.divider,
            width: sel ? 1.5 : 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? AppColors.primary : AppColors.textSecondary),
      ),
    ),
  );
}
