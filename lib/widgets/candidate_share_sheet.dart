import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_group.dart';
import '../models/scored_restaurant.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/search_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import 'line_icon.dart';

/// 選択した候補お店をLINEでシェアするためのボトムシート。
/// - グループを任意で選択（記録用）
/// - Firestore /public_shares/{shareId} に候補を保存し、
///   Web 共有URLを組み立てて LINE 本文に載せる（アプリ未インストール者も閲覧可）
/// - 共有開始を Firebase Analytics に記録
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

  /// Firestore に候補を保存し、Web 共有用の URL を返す。
  /// 失敗時は null を返し、LINE テキストにはリンクを付けない。
  Future<String?> _createPublicShareDoc(SearchState state) async {
    try {
      // Firestore rules が `request.auth != null` を要求するため、
      // 書き込み前に匿名認証を済ませておく（初回タップでも permission-denied を防ぐ）。
      await ensureUid();
      final point = state.selectedMeetingPoint;
      if (point == null) return null;
      final data = {
        'createdAt': FieldValue.serverTimestamp(),
        'stationName': point.stationName,
        'date': state.selectedDate?.toIso8601String(),
        'meetingTime': state.selectedMeetingTime == null
            ? null
            : '${state.selectedMeetingTime!.hour.toString().padLeft(2, '0')}:'
                '${state.selectedMeetingTime!.minute.toString().padLeft(2, '0')}',
        'participantTimes': point.participantTimes,
        'candidates': widget.candidates.map((sr) {
          final r = sr.restaurant;
          return {
            'name': r.name,
            'category': r.category,
            'priceStr': r.priceStr,
            'rating': r.rating,
            'address': r.address,
            'lat': r.lat,
            'lng': r.lng,
            'imageUrl': r.imageUrl,
            'hotpepperUrl': r.hotpepperUrl,
            'isReservable': r.isReservable,
          };
        }).toList(),
        'groupNames': _groupNamesFromSelection(ref.read(groupProvider)),
      };
      final doc = await FirebaseFirestore.instance
          .collection('public_shares')
          .add(data);
      // Firebase Hosting にデプロイされた静的ページが /s/<id> で閲覧可能。
      // デプロイ前でも文字列としては生成でき、デプロイ後にリンクが有効になる。
      // Firebase プロジェクト 'mannnaka' にデプロイされた Hosting URL
      return 'https://mannnaka.web.app/s/${doc.id}';
    } catch (e) {
      return null;
    }
  }

  List<String> _groupNamesFromSelection(List<SavedGroup> all) {
    return all
        .where((g) => _selectedGroupIds.contains(g.id))
        .map((g) => g.name)
        .toList();
  }

  Future<void> _share() async {
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    final state = ref.read(searchProvider);
    try {
      // Firestore に保存 → Web URL を取得
      final shareUrl = await _createPublicShareDoc(state);

      // Analytics: 共有開始イベント
      final categories = widget.candidates
          .map((sr) => sr.restaurant.category)
          .toSet()
          .toList();
      final groups = _groupNamesFromSelection(ref.read(groupProvider));
      await AnalyticsService.logLineShareInitiated(
        candidateCount: widget.candidates.length,
        categories: categories,
        hasWebUrl: shareUrl != null,
        groupNames: groups,
      );

      // LINE 起動
      await ShareUtils.shareCandidatesToLine(
        state,
        widget.candidates,
        shareUrl: shareUrl,
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
    final groups = ref.watch(groupProvider);

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
            Text(
              'LINEで候補をシェア',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.candidates.length}件の候補を送ります。アプリ未インストールの相手にも Webページで共有できます。',
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
