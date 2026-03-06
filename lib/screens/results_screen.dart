import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/meeting_point_card.dart';
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

  void _showShareModal(BuildContext context, SearchState state) {
    final text = ShareUtils.buildMeetingPointText(state);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareModal(shareText: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final selected = state.selectedMeetingPoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: selected != null
                ? Row(
                    children: [
                      Text(selected.stationEmoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        '${selected.stationName}駅',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ],
                  )
                : const Text('結果'),
            actions: [
              // Share button
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'シェア',
                onPressed: selected == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _showShareModal(context, state);
                      },
              ),
              // Save to history
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: '保存',
                onPressed: selected == null
                    ? null
                    : () {
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
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            // Tab 1: Meeting points
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (state.occasion != Occasion.none)
                  _OccasionBanner(occasion: state.occasion),
                ...state.results.asMap().entries.map((e) => MeetingPointCard(
                      point: e.value,
                      rank: e.key + 1,
                      isSelected:
                          selected?.stationIndex == e.value.stationIndex,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        notifier.selectMeetingPoint(e.value);
                        _tab.animateTo(1);
                      },
                    )),
              ],
            ),
            // Tab 2: Restaurants
            if (selected == null)
              const Center(child: Text('集合場所を選んでください'))
            else
              Column(
                children: [
                  _RestaurantFilter(
                    stationIndex: selected.stationIndex,
                    selectedCategory: state.restaurantCategory,
                    showFemaleFriendly: state.showFemaleFriendly,
                    showPrivateRoom: state.showPrivateRoom,
                    timeSlot: state.timeSlot,
                    maxBudget: state.maxBudget,
                    onCategory: notifier.setRestaurantCategory,
                    onFemaleFriendly: notifier.setFemaleFriendly,
                    onPrivateRoom: notifier.setPrivateRoom,
                    onTimeSlot: notifier.setTimeSlot,
                    onMaxBudget: notifier.setMaxBudget,
                  ),
                  Expanded(
                    child: state.restaurants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🍽️',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  '条件に合うお店が見つかりません',
                                  style:
                                      TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    notifier.setFemaleFriendly(false);
                                    notifier.setPrivateRoom(false);
                                    notifier.setRestaurantCategory(null);
                                    notifier.setMaxBudget(0);
                                  },
                                  child: const Text('フィルターをリセット'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: state.restaurants.length,
                            itemBuilder: (ctx, i) => RestaurantCard(
                              restaurant: state.restaurants[i],
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RestaurantDetailScreen(
                                    restaurant: state.restaurants[i],
                                  ),
                                ),
                              ),
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
}

class _OccasionBanner extends StatelessWidget {
  const _OccasionBanner({required this.occasion});
  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(occasion.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            '${occasion.label}に最適な集合場所',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Share Modal ──────────────────────────────────────────────────────────────

class _ShareModal extends StatefulWidget {
  const _ShareModal({required this.shareText});
  final String shareText;

  @override
  State<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<_ShareModal> {
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.shareText));
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
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.ios_share_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('みんなにシェアする',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.shareText,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _copy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _copied ? null : AppColors.primaryGradient,
                color: _copied ? const Color(0xFF10B981) : null,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _copied ? 'コピーしました！LINEに貼り付けてね' : 'コピーしてLINEで送る',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restaurant Filter ────────────────────────────────────────────────────────

class _RestaurantFilter extends StatefulWidget {
  const _RestaurantFilter({
    required this.stationIndex,
    required this.selectedCategory,
    required this.showFemaleFriendly,
    required this.showPrivateRoom,
    required this.timeSlot,
    required this.maxBudget,
    required this.onCategory,
    required this.onFemaleFriendly,
    required this.onPrivateRoom,
    required this.onTimeSlot,
    required this.onMaxBudget,
  });

  final int stationIndex;
  final String? selectedCategory;
  final bool showFemaleFriendly;
  final bool showPrivateRoom;
  final TimeSlot timeSlot;
  final int maxBudget;
  final void Function(String?) onCategory;
  final void Function(bool) onFemaleFriendly;
  final void Function(bool) onPrivateRoom;
  final void Function(TimeSlot) onTimeSlot;
  final void Function(int) onMaxBudget;

  @override
  State<_RestaurantFilter> createState() => _RestaurantFilterState();
}

class _RestaurantFilterState extends State<_RestaurantFilter> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final categories = MidpointService.getCategories(widget.stationIndex);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _Chip(
                  label: 'すべて',
                  selected: widget.selectedCategory == null,
                  onTap: () => widget.onCategory(null),
                ),
                ...categories.map((c) => _Chip(
                      label: c,
                      selected: widget.selectedCategory == c,
                      onTap: () =>
                          widget.onCategory(widget.selectedCategory == c ? null : c),
                    )),
              ],
            ),
          ),
          // Toggle row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _FilterToggle(
                  label: '女性に人気',
                  icon: Icons.favorite_rounded,
                  active: widget.showFemaleFriendly,
                  onTap: () => widget.onFemaleFriendly(!widget.showFemaleFriendly),
                ),
                const SizedBox(width: 8),
                _FilterToggle(
                  label: '個室あり',
                  icon: Icons.meeting_room_rounded,
                  active: widget.showPrivateRoom,
                  onTap: () => widget.onPrivateRoom(!widget.showPrivateRoom),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _showAdvanced
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            size: 14,
                            color: _showAdvanced
                                ? AppColors.primary
                                : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text('詳細',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _showAdvanced
                                  ? AppColors.primary
                                  : Colors.grey.shade600,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Advanced filters
          if (_showAdvanced) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time slot
                  Row(
                    children: TimeSlot.values.map((t) {
                      final isSelected = widget.timeSlot == t;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onTimeSlot(t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${t.emoji} ${t.label}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Budget slider
                  Row(
                    children: [
                      Text(
                        '予算上限: ${widget.maxBudget == 0 ? "制限なし" : "¥${_fmt(widget.maxBudget)}"}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.15),
                      inactiveTrackColor: Colors.grey.shade200,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: widget.maxBudget.toDouble(),
                      min: 0,
                      max: 8000,
                      divisions: 16,
                      onChanged: (v) => widget.onMaxBudget(v.round()),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle(
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
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
