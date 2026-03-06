import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/history_provider.dart';
import '../models/meeting_point.dart';
import '../widgets/restaurant_card.dart';
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
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final selected = state.selectedMeetingPoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('集合場所の候補',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (selected != null) ...[
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showShare(context, state);
              },
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(historyProvider.notifier).add(
                      state.participants.map((p) => p.name).toList(),
                      selected,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('履歴に保存しました'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(text: '集合場所'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('レストラン'),
                  if (state.restaurants.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${state.restaurants.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ─── Tab 1: 集合場所 ────────────────────────
          _MeetingPointTab(
            results: state.results,
            selected: selected,
            onSelect: (point) {
              HapticFeedback.lightImpact();
              notifier.selectMeetingPoint(point);
              _tab.animateTo(1);
            },
            occasion: state.occasion,
          ),

          // ─── Tab 2: レストラン ───────────────────────
          if (selected == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('👈', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('集合場所タブで場所を選んでください',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            _RestaurantTab(
              state: state,
              notifier: notifier,
            ),
        ],
      ),
    );
  }

  void _showShare(BuildContext context, SearchState state) {
    final text = ShareUtils.buildMeetingPointText(state);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(text: text),
    );
  }
}

// ─── 集合場所タブ ─────────────────────────────────────────────────────────────

class _MeetingPointTab extends StatelessWidget {
  const _MeetingPointTab({
    required this.results,
    required this.selected,
    required this.onSelect,
    required this.occasion,
  });

  final List<MeetingPoint> results;
  final MeetingPoint? selected;
  final void Function(MeetingPoint) onSelect;
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('結果が見つかりませんでした'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (occasion != Occasion.none)
          _OccasionBanner(occasion: occasion),
        // ベスト候補（大きく表示）
        _BestPickCard(
          point: results.first,
          isSelected: selected?.stationIndex == results.first.stationIndex,
          onTap: () => onSelect(results.first),
        ),
        if (results.length > 1) ...[
          const SizedBox(height: 20),
          const Text(
            '他の候補',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...results.skip(1).toList().asMap().entries.map((e) {
            final point = e.value;
            return _AlternativeCard(
              point: point,
              rank: e.key + 2,
              isSelected: selected?.stationIndex == point.stationIndex,
              onTap: () => onSelect(point),
            );
          }),
        ],
      ],
    );
  }
}

// ─── ベスト候補カード（大） ───────────────────────────────────────────────────

class _BestPickCard extends StatelessWidget {
  const _BestPickCard({
    required this.point,
    required this.isSelected,
    required this.onTap,
  });
  final MeetingPoint point;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🏆 おすすめ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    point.fairnessLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(point.stationEmoji,
                    style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${point.stationName}駅',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '平均 ${point.averageMinutes.toStringAsFixed(0)}分 ·'
                      ' 最大 ${point.maxMinutes}分',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 参加者の時間
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: point.participantTimes.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${e.key} ${e.value}分',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'このエリアのレストランを見る →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 代替候補カード（小） ─────────────────────────────────────────────────────

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.point,
    required this.rank,
    required this.isSelected,
    required this.onTap,
  });
  final MeetingPoint point;
  final int rank;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(point.stationEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${point.stationName}駅',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '平均 ${point.averageMinutes.toStringAsFixed(0)}分 · ${point.fairnessLabel}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              children: point.participantTimes.entries.take(3).map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${e.value}分',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── レストランタブ ───────────────────────────────────────────────────────────

class _RestaurantTab extends StatefulWidget {
  const _RestaurantTab({required this.state, required this.notifier});
  final SearchState state;
  final SearchNotifier notifier;

  @override
  State<_RestaurantTab> createState() => _RestaurantTabState();
}

class _RestaurantTabState extends State<_RestaurantTab> {
  bool _showBudget = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = widget.notifier;
    final selected = state.selectedMeetingPoint!;
    final categories = MidpointService.getCategories(selected.stationIndex);

    return Column(
      children: [
        // フィルターバー
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              // カテゴリ
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip('すべて', state.restaurantCategory == null,
                        () => notifier.setRestaurantCategory(null)),
                    ...categories.map((c) => _chip(
                          c,
                          state.restaurantCategory == c,
                          () => notifier.setRestaurantCategory(
                              state.restaurantCategory == c ? null : c),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // フィルタートグル行
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToggleChip(
                      label: '女性に人気',
                      icon: Icons.favorite_rounded,
                      active: state.showFemaleFriendly,
                      onTap: () => notifier
                          .setFemaleFriendly(!state.showFemaleFriendly),
                    ),
                    const SizedBox(width: 6),
                    _ToggleChip(
                      label: '個室あり',
                      icon: Icons.meeting_room_rounded,
                      active: state.showPrivateRoom,
                      onTap: () =>
                          notifier.setPrivateRoom(!state.showPrivateRoom),
                    ),
                    const SizedBox(width: 6),
                    _ToggleChip(
                      label: 'ランチ',
                      icon: Icons.wb_sunny_outlined,
                      active: state.timeSlot == TimeSlot.lunch,
                      onTap: () => notifier.setTimeSlot(
                          state.timeSlot == TimeSlot.lunch
                              ? TimeSlot.all
                              : TimeSlot.lunch),
                    ),
                    const SizedBox(width: 6),
                    _ToggleChip(
                      label: 'ディナー',
                      icon: Icons.nightlight_round,
                      active: state.timeSlot == TimeSlot.dinner,
                      onTap: () => notifier.setTimeSlot(
                          state.timeSlot == TimeSlot.dinner
                              ? TimeSlot.all
                              : TimeSlot.dinner),
                    ),
                    const SizedBox(width: 6),
                    _ToggleChip(
                      label: '予算',
                      icon: Icons.attach_money_rounded,
                      active: state.maxBudget > 0,
                      onTap: () =>
                          setState(() => _showBudget = !_showBudget),
                    ),
                  ],
                ),
              ),
              if (_showBudget) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '上限: ${state.maxBudget == 0 ? "制限なし" : "¥${_fmt(state.maxBudget)}"}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    thumbColor: AppColors.primary,
                    overlayColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    inactiveTrackColor: Colors.grey.shade200,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: state.maxBudget.toDouble(),
                    min: 0,
                    max: 8000,
                    divisions: 16,
                    onChanged: (v) => notifier.setMaxBudget(v.round()),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        ),
        // リスト
        Expanded(
          child: state.restaurants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🍽️', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text('条件に合うお店がありません',
                          style:
                              TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          notifier.setFemaleFriendly(false);
                          notifier.setPrivateRoom(false);
                          notifier.setRestaurantCategory(null);
                          notifier.setMaxBudget(0);
                          notifier.setTimeSlot(TimeSlot.all);
                        },
                        child: const Text('フィルターをリセット'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: state.restaurants.length,
                  itemBuilder: (ctx, i) => RestaurantCard(
                    restaurant: state.restaurants[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                            restaurant: state.restaurants[i]),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _fmt(int n) =>
      n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';
}

Widget _chip(String label, bool selected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade700,
        ),
      ),
    ),
  );
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? AppColors.primary : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 目的バナー ───────────────────────────────────────────────────────────────

class _OccasionBanner extends StatelessWidget {
  const _OccasionBanner({required this.occasion});
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(occasion.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '${occasion.label}に最適な場所を表示中',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── シェアシート ─────────────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.text});
  final String text;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const Text('友達にシェアする',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('コピーしてLINEやSNSに貼り付けてください',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(widget.text,
                style: const TextStyle(fontSize: 12, height: 1.6)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _copied ? const Color(0xFF10B981) : null,
                gradient: _copied ? null : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: _copy,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _copied ? '✓ コピーしました！LINEに貼り付けてね' : 'コピーしてLINEで送る',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
