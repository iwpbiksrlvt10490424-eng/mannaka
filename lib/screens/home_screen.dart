import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';

typedef NavigateCallback = void Function(int tabIndex, {Occasion? occasion});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onNavigate});
  final NavigateCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── ヘッダー ───────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🗺️', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      const Text(
                        'まんなか',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'みんなが集まりやすい\n場所を見つけよう',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // メインCTA
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onNavigate?.call(1);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.search_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '集合場所を探す',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── コンテンツ ──────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                children: [
                  // 目的別ショートカット
                  const Text(
                    '何の集まり？',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _OccasionRow(onNavigate: onNavigate),
                  const SizedBox(height: 28),

                  // 最近の検索
                  if (history.isEmpty)
                    _EmptyState()
                  else ...[
                    const Text(
                      '最近の検索',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...history.take(5).map((e) => _HistoryCard(entry: e)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 目的別ショートカット ────────────────────────────────────────────────────

class _OccasionRow extends StatelessWidget {
  const _OccasionRow({this.onNavigate});
  final NavigateCallback? onNavigate;

  static const _items = [
    (Occasion.girlsNight, '女子会', '👑', Color(0xFFFF4E8C)),
    (Occasion.birthday, '誕生日', '🎂', Color(0xFFA855F7)),
    (Occasion.lunch, 'ランチ', '🥗', Color(0xFF10B981)),
    (Occasion.mixer, '合コン', '🥂', Color(0xFF3B82F6)),
    (Occasion.welcome, '歓迎会', '🎉', Color(0xFFF59E0B)),
    (Occasion.date, 'デート', '💕', Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final (occasion, label, emoji, color) = _items[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onNavigate?.call(1, occasion: occasion);
            },
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 空状態 ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          const Text(
            'はじめてみよう！',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '参加者の最寄り駅を入力するだけで\n全員に公平な集合場所を自動計算します',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 履歴カード ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(entry.meetingPoint.stationEmoji,
                style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.meetingPoint.stationName}駅',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.participantNames.join('・'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '平均${entry.meetingPoint.averageMinutes.toStringAsFixed(0)}分',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _fairnessColor(entry.meetingPoint.fairnessScore)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.meetingPoint.fairnessLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _fairnessColor(entry.meetingPoint.fairnessScore),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _fairnessColor(double score) {
    if (score >= 0.85) return const Color(0xFF10B981);
    if (score >= 0.65) return const Color(0xFF3B82F6);
    return const Color(0xFFF59E0B);
  }
}
