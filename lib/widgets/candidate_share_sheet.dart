import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import 'line_icon.dart';

/// 選択した候補お店を LINE でシェアするためのボトムシート。
///
/// 設計方針:
/// - LINE 本文は **冒頭「Aimachiで検索したお店を共有します」** → 日時 → 参加者
///   → 駅ごとの候補（各駅 最大3件、番号付き）→ Aimachi 誘導 の構成。
/// - ユーザーが複数エリアで候補を選んだ場合、駅ごとに束ねて表示する。
/// - グループ選択 UI は要望により撤去（記録用途が不明確なため）。
class CandidateShareSheet extends ConsumerStatefulWidget {
  const CandidateShareSheet({
    super.key,
    required this.groupedCandidates,
  });

  /// 駅名 → その駅で選ばれた候補の順序付きリスト。
  final Map<String, List<ScoredRestaurant>> groupedCandidates;

  @override
  ConsumerState<CandidateShareSheet> createState() =>
      _CandidateShareSheetState();
}

class _CandidateShareSheetState extends ConsumerState<CandidateShareSheet> {
  bool _sharing = false;

  int get _totalCount =>
      widget.groupedCandidates.values.fold(0, (a, b) => a + b.length);

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    final state = ref.read(searchProvider);
    try {
      final categories = widget.groupedCandidates.values
          .expand((l) => l)
          .map((sr) => sr.restaurant.category)
          .toSet()
          .toList();
      await AnalyticsService.logLineShareInitiated(
        candidateCount: _totalCount,
        categories: categories,
        hasWebUrl: false,
        groupNames: const [],
      );

      await ShareUtils.shareGroupedCandidatesToLine(
        state,
        widget.groupedCandidates,
      );
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
            const SizedBox(height: 6),
            const Text(
              '上位3件だけLINEで共有されます。\nそれ以上見る場合は相手にアプリのダウンロードをお願いします。',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            // 駅ごとのプレビュー
            ...widget.groupedCandidates.entries.map((e) {
              final top = e.value.take(3).toList();
              final extra = e.value.length - top.length;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('${e.key}駅周辺',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < top.length; i++)
                      Text(
                        '${i + 1}. ${top[i].restaurant.name}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (extra > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '…ほか$extra件は Aimachi で',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
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
  required Map<String, List<ScoredRestaurant>> groupedCandidates,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        CandidateShareSheet(groupedCandidates: groupedCandidates),
  );
}
