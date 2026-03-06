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
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                '集合場所を探す',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            actions: [
              if (state.participants.length < 6)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    notifier.addParticipant();
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('追加'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final p = state.participants[i];
                  return ParticipantTile(
                    key: ValueKey(p.id),
                    participant: p,
                    index: i,
                    canRemove: state.participants.length > 1,
                    onNameChanged: (name) => notifier.updateParticipantName(p.id, name),
                    onStationSelected: (idx, name) => notifier.setStation(p.id, idx, name),
                    onStationCleared: () => notifier.clearStation(p.id),
                    onRemove: () => notifier.removeParticipant(p.id),
                  );
                },
                childCount: state.participants.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
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
              label: '最適な集合場所を見つける',
              icon: Icons.search_rounded,
              isLoading: state.isCalculating,
              onPressed: state.canCalculate && !state.isCalculating
                  ? () async {
                      HapticFeedback.mediumImpact();
                      await notifier.calculate();
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ResultsScreen()),
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
