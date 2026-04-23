import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_group.dart';
import '../models/scored_restaurant.dart';
import '../providers/group_provider.dart';
import '../providers/search_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import 'line_icon.dart';

/// 選択した候補お店を LINE でシェアするためのボトムシート。
/// - グループを任意で選択（記録用）
/// - LINE 本文には上位 3 件を順序付きで含める
/// - 4 件以上あるときは「続きは Aimachi で」アプリ誘導を末尾に付ける
/// - Web 共有ページは廃止（相手はアプリで見る前提）
class CandidateShareSheet extends ConsumerStatefulWidget {
  const CandidateShareSheet({
    super.key,
    required this.candidates,
  });

  final List<ScoredRestaurant> candidates;

  @override
  ConsumerState<CandidateShareSheet> createState() =>
      _CandidateShareSheetState();
}

class _CandidateShareSheetState extends ConsumerState<CandidateShareSheet> {
  final Set<String> _selectedGroupIds = {};
  bool _sharing = false;

  List<String> _groupNamesFromSelection(List<SavedGroup> all) {
    return all
        .where((g) => _selectedGroupIds.contains(g.id))
        .map((g) => g.name)
        .toList();
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    final state = ref.read(searchProvider);
    try {
      final categories = widget.candidates
          .map((sr) => sr.restaurant.category)
          .toSet()
          .toList();
      final groups = _groupNamesFromSelection(ref.read(groupProvider));
      await AnalyticsService.logLineShareInitiated(
        candidateCount: widget.candidates.length,
        categories: categories,
        hasWebUrl: false,
        groupNames: groups,
      );

      await ShareUtils.shareCandidatesToLine(state, widget.candidates);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('共有の準備に失敗しました'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final groups = ref.watch(groupProvider);

    final visibleCount = widget.candidates.length > 3 ? 3 : widget.candidates.length;
    final extra = widget.candidates.length - visibleCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'LINEで候補をシェア',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              extra > 0
                  ? '上位 $visibleCount 件を順番に送ります。\n残り $extra 件は Aimachi で見られます（アプリ誘導を文末に自動付与）。'
                  : '$visibleCount 件を送ります。',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            if (groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'グループは未登録です（このまま共有できます）',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              )
            else ...[
              const Text('どのグループに送りますか（任意）',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: groups.map((g) {
                  final selected = _selectedGroupIds.contains(g.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedGroupIds.remove(g.id);
                      } else {
                        _selectedGroupIds.add(g.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) ...[
                            const Icon(Icons.check,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const LineIcon(
                        size: 22, filled: false, iconColor: Colors.white),
                label: Text(
                  _sharing ? '準備中…' : 'LINEで送る',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06C755),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showCandidateShareSheet(
  BuildContext context, {
  required List<ScoredRestaurant> candidates,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CandidateShareSheet(candidates: candidates),
  );
}
