import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';

// ホーム画面から検索タブへ切り替えるためのコールバック
typedef NavigateCallback = void Function(int tabIndex, {Occasion? occasion});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onNavigate});
  final NavigateCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 11 ? 'おはようございます' : hour < 17 ? 'こんにちは' : 'こんばんは';
    final greetingEmoji = hour < 11 ? '☀️' : hour < 17 ? '🌤️' : '🌙';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🗺️', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'まんなか',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$greetingEmoji $greeting',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '今日はどんな集まり？',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2),
                  ),
                  const SizedBox(height: 20),
                  // Quick search bar
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onNavigate?.call(1);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: Colors.grey.shade400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '駅を入力して集合場所を検索...',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('検索',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 目的別クイックスタート
                  const Text('何の集まりですか？',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _OccasionGrid(onNavigate: onNavigate),
                  const SizedBox(height: 28),

                  // 統計バナー
                  _StatsBanner(historyCount: history.length),
                  const SizedBox(height: 28),

                  // 人気の集合スポット（モック）
                  const Text('人気の集合スポット',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('みんなによく選ばれる駅',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  _PopularStationsRow(),
                  const SizedBox(height: 28),

                  // 使い方ガイド
                  const Text('使い方ガイド',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const _HowToSteps(),
                  const SizedBox(height: 28),

                  // 最近の検索
                  if (history.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('最近の検索',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...history
                        .take(3)
                        .map((e) => _HistoryItem(entry: e)),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 目的別グリッド ─────────────────────────────────────────────────────────

class _OccasionGrid extends StatelessWidget {
  const _OccasionGrid({this.onNavigate});
  final NavigateCallback? onNavigate;

  static const _occasions = [
    (Occasion.girlsNight, '女子会', '👑', Color(0xFFFF4E8C)),
    (Occasion.birthday, '誕生日', '🎂', Color(0xFFA855F7)),
    (Occasion.lunch, 'ランチ会', '🥗', Color(0xFF10B981)),
    (Occasion.mixer, '合コン', '🥂', Color(0xFF3B82F6)),
    (Occasion.welcome, '歓迎会', '🎉', Color(0xFFF59E0B)),
    (Occasion.date, 'デート', '💕', Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: _occasions.map((item) {
        final (occasion, label, emoji, color) = item;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onNavigate?.call(1, occasion: occasion);
          },
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── 統計バナー ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.historyCount});
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🗾 東京15駅・41店舗対応',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  '渋谷・新宿・池袋・銀座など\n人気エリアを完全カバー',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _MiniStat(value: '15', label: '対応駅'),
              const SizedBox(height: 8),
              _MiniStat(value: '41', label: '店舗'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ─── 人気集合スポット ─────────────────────────────────────────────────────────

class _PopularStationsRow extends StatelessWidget {
  final _popular = const [
    ('渋谷', '🛍️', '女子会に◎', 4.2),
    ('新宿', '🎪', '合コン人気', 4.5),
    ('銀座', '✨', '誕生日に', 4.7),
    ('表参道', '👜', 'デートに', 4.6),
    ('恵比寿', '🌹', '女子会', 4.4),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _popular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final (name, emoji, tag, score) = _popular[i];
          return Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(tag,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_rounded,
                        color: Colors.amber.shade400, size: 11),
                    Text('$score',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── 使い方ステップ ──────────────────────────────────────────────────────────

class _HowToSteps extends StatelessWidget {
  const _HowToSteps();

  static const _steps = [
    ('1', '👥', '参加者の駅を登録', '全員の最寄り駅を選択'),
    ('2', '🎯', '目的を選んで検索', '女子会・誕生日など目的に合わせて'),
    ('3', '📍', '集合場所が決まる！', '公平さを考慮して自動計算'),
    ('4', '🍽️', 'レストランも選べる', 'フィルターで絞り込んで予約'),
    ('5', '📤', 'LINEでシェア', 'ワンタップでコピーして送信'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _steps.asMap().entries.map((e) {
        final (step, emoji, title, sub) = e.value;
        final isLast = e.key == _steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(step,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                if (!isLast)
                  Container(
                      width: 2,
                      height: 36,
                      color: AppColors.primary.withValues(alpha: 0.2)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(sub,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── 履歴アイテム ────────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(entry.meetingPoint.stationEmoji,
                style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.meetingPoint.stationName}駅',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  entry.participantNames.join('、'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                entry.meetingPoint.fairnessLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
