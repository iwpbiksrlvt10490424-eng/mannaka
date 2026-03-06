import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/meeting_point_card.dart';
import '../widgets/restaurant_card.dart';
import '../theme/app_theme.dart';
import '../services/midpoint_service.dart';
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
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: selected != null
                ? Row(
                    children: [
                      Text(selected.stationEmoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(
                        '${selected.stationName}駅',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ],
                  )
                : const Text('結果'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: selected == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref.read(historyProvider.notifier).add(
                          state.participants.map((p) => p.name).toList(),
                          selected,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('履歴に保存しました')),
                        );
                      },
              ),
            ],
            bottom: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '集合場所'),
                Tab(text: 'レストラン'),
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
                ...state.results.asMap().entries.map((e) => MeetingPointCard(
                  point: e.value,
                  rank: e.key + 1,
                  isSelected: selected?.stationIndex == e.value.stationIndex,
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
                    onCategory: notifier.setRestaurantCategory,
                    onFemaleFriendly: notifier.setFemaleFriendly,
                    onPrivateRoom: notifier.setPrivateRoom,
                  ),
                  Expanded(
                    child: state.restaurants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🍽️', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  '条件に合うお店が見つかりません',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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

class _RestaurantFilter extends StatelessWidget {
  const _RestaurantFilter({
    required this.stationIndex,
    required this.selectedCategory,
    required this.showFemaleFriendly,
    required this.showPrivateRoom,
    required this.onCategory,
    required this.onFemaleFriendly,
    required this.onPrivateRoom,
  });

  final int stationIndex;
  final String? selectedCategory;
  final bool showFemaleFriendly;
  final bool showPrivateRoom;
  final void Function(String?) onCategory;
  final void Function(bool) onFemaleFriendly;
  final void Function(bool) onPrivateRoom;

  @override
  Widget build(BuildContext context) {
    final categories = MidpointService.getCategories(stationIndex);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'すべて',
                  selected: selectedCategory == null,
                  onTap: () => onCategory(null),
                ),
                ...categories.map((c) => _Chip(
                  label: c,
                  selected: selectedCategory == c,
                  onTap: () => onCategory(selectedCategory == c ? null : c),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _FilterToggle(
                label: '女性に人気',
                icon: Icons.favorite_rounded,
                active: showFemaleFriendly,
                onTap: () => onFemaleFriendly(!showFemaleFriendly),
              ),
              const SizedBox(width: 8),
              _FilterToggle(
                label: '個室あり',
                icon: Icons.meeting_room_rounded,
                active: showPrivateRoom,
                onTap: () => onPrivateRoom(!showPrivateRoom),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
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
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
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
          color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.primary : Colors.grey.shade500),
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
