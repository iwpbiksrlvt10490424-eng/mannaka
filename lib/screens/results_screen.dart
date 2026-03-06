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
        title: const Text('検索結果'),
        actions: [
          if (selected != null) ...[
            IconButton(
              icon: const Icon(Icons.ios_share, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                _showShare(context, state);
              },
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border, size: 22),
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
                        borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${state.restaurants.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
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
          // ─── 集合場所タブ ──────────────────────────────────
          _MeetingTab(
            state: state,
            onSelect: (point) {
              HapticFeedback.lightImpact();
              notifier.selectMeetingPoint(point);
              _tab.animateTo(1);
            },
          ),
          // ─── レストランタブ ────────────────────────────────
          selected == null
              ? const _EmptyRestaurant()
              : _RestaurantTab(state: state, notifier: notifier),
        ],
      ),
    );
  }

  void _showShare(BuildContext context, SearchState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(text: ShareUtils.buildMeetingPointText(state)),
    );
  }
}

// ─── 集合場所タブ ─────────────────────────────────────────────────────────────

class _MeetingTab extends StatelessWidget {
  const _MeetingTab({required this.state, required this.onSelect});
  final SearchState state;
  final void Function(MeetingPoint) onSelect;

  @override
  Widget build(BuildContext context) {
    final results = state.results;
    final selected = state.selectedMeetingPoint;

    if (results.isEmpty) {
      return const Center(
          child: Text('結果が見つかりませんでした',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (state.occasion != Occasion.none) _OccasionNote(state.occasion),
        // 1位: 大カード
        _TopCard(
          point: results.first,
          onTap: () => onSelect(results.first),
        ),
        if (results.length > 1) ...[
          const SizedBox(height: 20),
          const Text(
            'その他の候補',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: results.skip(1).toList().asMap().entries.map((e) {
                final point = e.value;
                final isLast = e.key == results.length - 2;
                return _AltRow(
                  point: point,
                  rank: e.key + 2,
                  isSelected: selected?.stationIndex == point.stationIndex,
                  showDivider: !isLast,
                  onTap: () => onSelect(point),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── 1位カード（シンプル・クリーン） ─────────────────────────────────────────

class _TopCard extends StatelessWidget {
  const _TopCard({required this.point, required this.onTap});
  final MeetingPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カラーアクセントバー
          Container(
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // バッジ
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🏆 おすすめ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _FairChip(score: point.fairnessScore),
                  ],
                ),
                const SizedBox(height: 14),
                // 駅名
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(point.stationEmoji,
                        style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${point.stationName}駅',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '平均 ${point.averageMinutes.toStringAsFixed(0)}分  最大 ${point.maxMinutes}分',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 参加者タイム
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: point.participantTimes.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${e.key}  ${e.value}分',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // CTA
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'このエリアのレストランを見る',
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
    );
  }
}

// ─── 代替候補行（リストセル形式） ─────────────────────────────────────────────

class _AltRow extends StatelessWidget {
  const _AltRow({
    required this.point,
    required this.rank,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });
  final MeetingPoint point;
  final int rank;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Text(point.stationEmoji,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${point.stationName}駅',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '平均 ${point.averageMinutes.toStringAsFixed(0)}分 · ${point.fairnessLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: point.participantTimes.entries.take(3).map((e) {
                    return Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('${e.value}分',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16),
      ],
    );
  }
}

// ─── 目的ノート ───────────────────────────────────────────────────────────────

class _OccasionNote extends StatelessWidget {
  const _OccasionNote(this.occasion);
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          Text(occasion.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '${occasion.label}に最適な場所を表示中',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 公平性チップ ─────────────────────────────────────────────────────────────

class _FairChip extends StatelessWidget {
  const _FairChip({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final (label, color) = score >= 0.85
        ? ('最公平', AppColors.success)
        : score >= 0.65
            ? ('フェア', const Color(0xFF2563EB))
            : ('要確認', AppColors.warning);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
    final s = widget.state;
    final n = widget.notifier;
    final stationIdx = s.selectedMeetingPoint!.stationIndex;
    final categories = MidpointService.getCategories(stationIdx);

    return Column(
      children: [
        // フィルター
        Container(
          color: AppColors.surface,
          child: Column(
            children: [
              // カテゴリ
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  children: [
                    _filterChip(
                        '全て', s.restaurantCategory == null,
                        () => n.setRestaurantCategory(null)),
                    ...categories.map((c) => _filterChip(
                          c,
                          s.restaurantCategory == c,
                          () => n.setRestaurantCategory(
                              s.restaurantCategory == c ? null : c),
                        )),
                  ],
                ),
              ),
              const Divider(height: 1),
              // トグル
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _ToggleBtn(
                      '女性人気',
                      Icons.favorite_outline,
                      s.showFemaleFriendly,
                      () => n.setFemaleFriendly(!s.showFemaleFriendly),
                    ),
                    const SizedBox(width: 8),
                    _ToggleBtn(
                      '個室あり',
                      Icons.door_back_door_outlined,
                      s.showPrivateRoom,
                      () => n.setPrivateRoom(!s.showPrivateRoom),
                    ),
                    const SizedBox(width: 8),
                    _ToggleBtn(
                      'ランチ',
                      Icons.wb_sunny_outlined,
                      s.timeSlot == TimeSlot.lunch,
                      () => n.setTimeSlot(s.timeSlot == TimeSlot.lunch
                          ? TimeSlot.all
                          : TimeSlot.lunch),
                    ),
                    const SizedBox(width: 8),
                    _ToggleBtn(
                      'ディナー',
                      Icons.nightlight_outlined,
                      s.timeSlot == TimeSlot.dinner,
                      () => n.setTimeSlot(s.timeSlot == TimeSlot.dinner
                          ? TimeSlot.all
                          : TimeSlot.dinner),
                    ),
                    const SizedBox(width: 8),
                    _ToggleBtn(
                      s.maxBudget > 0
                          ? '〜¥${_fmt(s.maxBudget)}'
                          : '予算',
                      Icons.attach_money,
                      s.maxBudget > 0 || _showBudget,
                      () => setState(() => _showBudget = !_showBudget),
                    ),
                  ],
                ),
              ),
              if (_showBudget) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '上限: ${s.maxBudget == 0 ? "制限なし" : "¥${_fmt(s.maxBudget)}"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      overlayColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      inactiveTrackColor: AppColors.border,
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: s.maxBudget.toDouble(),
                      min: 0,
                      max: 8000,
                      divisions: 16,
                      onChanged: (v) => n.setMaxBudget(v.round()),
                    ),
                  ),
                ),
              ],
              const Divider(height: 1),
            ],
          ),
        ),
        // リスト
        Expanded(
          child: s.restaurants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🍽️',
                          style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('条件に合うお店がありません',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          n.setFemaleFriendly(false);
                          n.setPrivateRoom(false);
                          n.setRestaurantCategory(null);
                          n.setMaxBudget(0);
                          n.setTimeSlot(TimeSlot.all);
                        },
                        child: const Text('フィルターをリセット'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: s.restaurants.length,
                  itemBuilder: (ctx, i) => RestaurantCard(
                    restaurant: s.restaurants[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(
                            restaurant: s.restaurants[i]),
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
          color: sel ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn(this.label, this.icon, this.active, this.onTap);
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.divider,
              width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active
                    ? AppColors.primary
                    : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRestaurant extends StatelessWidget {
  const _EmptyRestaurant();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('←', style: TextStyle(fontSize: 32)),
          SizedBox(height: 12),
          Text('まず集合場所を選んでください',
              style: TextStyle(color: AppColors.textSecondary)),
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
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
          const Text(
            'LINEやSNSでシェア',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'コピーして貼り付けてください',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              widget.text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.7,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copy,
              icon: Icon(
                  _copied ? Icons.check : Icons.copy_outlined, size: 18),
              label: Text(
                _copied ? 'コピーしました！LINEに貼り付けてね' : 'テキストをコピーする',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _copied ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
