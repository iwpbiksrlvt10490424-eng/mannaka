import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import 'line_icon.dart';

/// 選んだ候補お店を LINE で共有するボトムシート。
///
/// LINE 本文には **駅を跨いで選択順の上位 5 件のみ** を載せる。
/// 1 回で送れる上限は 5 件で、選択 UI 側でも 6 件目以降は選べない。
/// シート内のプレビューは駅ごとにまとめた形で「何を何件選んでいるか」を示す。
class CandidateShareSheet extends ConsumerStatefulWidget {
  const CandidateShareSheet({
    super.key,
    required this.selections,
  });

  /// 選択順に並んだ (駅名, ScoredRestaurant) の列。
  final List<({String station, ScoredRestaurant scored})> selections;

  @override
  ConsumerState<CandidateShareSheet> createState() =>
      _CandidateShareSheetState();
}

class _CandidateShareSheetState extends ConsumerState<CandidateShareSheet> {
  bool _sharing = false;

  int get _totalCount => widget.selections.length;

  /// プレビュー用: 駅ごとに束ねた Map を insertion order で返す。
  Map<String, List<ScoredRestaurant>> get _grouped {
    final out = <String, List<ScoredRestaurant>>{};
    for (final e in widget.selections) {
      out.putIfAbsent(e.station, () => []).add(e.scored);
    }
    return out;
  }

  Future<void> _share() async {
    if (_sharing) return;
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    final state = ref.read(searchProvider);
    try {
      final categories = widget.selections
          .map((e) => e.scored.restaurant.category)
          .toSet()
          .toList();
      await AnalyticsService.logLineShareInitiated(
        candidateCount: _totalCount,
        categories: categories,
        hasWebUrl: false,
        groupNames: const [],
      );
      await ShareUtils.shareSelectionsToLine(state, widget.selections);
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
    final grouped = _grouped;
    final sendCount = _totalCount > 5 ? 5 : _totalCount;

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
              '1回で送れるのは5件までです。\n相手にもAimachiを使ってもらえば、同じ条件で自分で探せます。',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 14),
            // 駅ごとのプレビュー（「何をどの駅で選んでいるか」だけ見せる）
            ...grouped.entries.map((e) {
              final list = e.value;
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
                        Text('${e.key}駅エリア（${list.length}件）',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final s in list)
                      Text(
                        '・${s.restaurant.name}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
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
                  _sharing ? '準備中…' : '$sendCount件をLINEで送る',
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
  required List<({String station, ScoredRestaurant scored})> selections,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => CandidateShareSheet(selections: selections),
  );
}
