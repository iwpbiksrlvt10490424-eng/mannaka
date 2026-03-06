import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart';
import '../widgets/participant_tile.dart';
import '../widgets/gradient_button.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header gradient
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '集合場所を探す',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '全員の駅を設定してください',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.participants.length < 6)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            notifier.addParticipant();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.person_add_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('追加',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Occasion tags
                  _OccasionRow(
                    selected: state.occasion,
                    onSelect: notifier.setOccasion,
                  ),
                ],
              ),
            ),
          ),
          // Participants
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final p = state.participants[i];
                  return ParticipantTile(
                    key: ValueKey(p.id),
                    participant: p,
                    index: i,
                    canRemove: state.participants.length > 1,
                    onNameChanged: (name) =>
                        notifier.updateParticipantName(p.id, name),
                    onStationSelected: (idx, name) =>
                        notifier.setStation(p.id, idx, name),
                    onStationCleared: () => notifier.clearStation(p.id),
                    onRemove: () => notifier.removeParticipant(p.id),
                  );
                },
                childCount: state.participants.length,
              ),
            ),
          ),
          // Time slot
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _TimeSlotRow(
                selected: state.timeSlot,
                onSelect: notifier.setTimeSlot,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!state.canCalculate)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '2人以上の駅を設定してください',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            GradientButton(
              label: state.occasion != Occasion.none
                  ? '${state.occasion.emoji} ${state.occasion.label}の場所を見つける'
                  : '最適な集合場所を見つける',
              icon: Icons.search_rounded,
              isLoading: state.isCalculating,
              onPressed: state.canCalculate && !state.isCalculating
                  ? () async {
                      HapticFeedback.mediumImpact();
                      await notifier.calculate();
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ResultsScreen()),
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OccasionRow extends StatelessWidget {
  const _OccasionRow({required this.selected, required this.onSelect});
  final Occasion selected;
  final void Function(Occasion) onSelect;

  @override
  Widget build(BuildContext context) {
    final occasions = Occasion.values.where((o) => o != Occasion.none).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: occasions.map((o) {
          final isSelected = selected == o;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onSelect(isSelected ? Occasion.none : o);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(o.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({required this.selected, required this.onSelect});
  final TimeSlot selected;
  final void Function(TimeSlot) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('時間帯',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: TimeSlot.values.map((t) {
              final isSelected = selected == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelect(t);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${t.emoji} ${t.label}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
