import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ranking_entry.dart';
import '../providers/ranking_provider.dart';
import '../theme/app_theme.dart';

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── ヘッダー ───────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0.5,
            shadowColor: AppColors.divider,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: const Text(
                'まんなか指数ランキング',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              expandedTitleScale: 1,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => ref.invalidate(rankingProvider),
              ),
            ],
          ),

          // ─── コンテンツ ─────────────────────────────────────────
          rankingAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => SliverFillRemaining(
              child: _ErrorView(onRetry: () => ref.invalidate(rankingProvider)),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const SliverFillRemaining(child: _EmptyView());
              }
              return _RankingContent(entries: entries);
            },
          ),
        ],
      ),
    );
  }
}

// ─── ランキング本体 ────────────────────────────────────────────────────────

class _RankingContent extends StatelessWidget {
  const _RankingContent({required this.entries});
  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final top3 = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 16),

        // 説明テキスト
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'まんなかユーザーが最もよく集まった駅ランキング。人気エリアでお店を探してみよう！',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // まんなか指数の説明バナー
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「まんなか指数」について',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '全員の移動時間バランスが最も良かった駅の選ばれた回数です。\nこのランキングはまんなかアプリ全ユーザーの検索データに基づいています。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // シェアボタン
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ShareCardButton(entries: top3),
        ),
        const SizedBox(height: 24),

        // トップ3ポジウム
        if (top3.length >= 3) _Podium(entries: top3),
        const SizedBox(height: 24),

        // 4位以下リスト
        if (rest.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '4位以下',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          ...rest.map((e) => _RankRow(entry: e)),
        ],

        const SizedBox(height: 48),
      ]),
    );
  }
}

// ─── 表彰台（トップ3） ─────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    // 2位、1位、3位の順に並べる（表彰台形式）
    final order = [1, 0, 2];
    final heights = [96.0, 128.0, 76.0];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.primary.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: order.map((i) {
            final entry = entries[i];
            return _PodiumCell(
              entry: entry,
              podiumHeight: heights[order.indexOf(i)],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PodiumCell extends StatelessWidget {
  const _PodiumCell({required this.entry, required this.podiumHeight});
  final RankingEntry entry;
  final double podiumHeight;

  @override
  Widget build(BuildContext context) {
    final isFirst = entry.rank == 1;
    final medalColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 王冠（1位のみ）
          if (isFirst) ...[
            Icon(Icons.emoji_events_rounded,
                color: medalColor, size: 28),
            const SizedBox(height: 4),
          ],
          // 駅名
          Text(
            '${entry.stationName}駅',
            style: TextStyle(
              fontSize: isFirst ? 14 : 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          // 回数
          Text(
            '${entry.searchCount}回',
            style: TextStyle(
              fontSize: 12,
              color: medalColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // 台座
          Container(
            width: 80,
            height: podiumHeight,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border.all(
                color: medalColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: medalColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 4位以下の行 ──────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry});
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.place_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${entry.stationName}駅',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${entry.searchCount}回',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SNSシェアカードボタン ────────────────────────────────────────────────

class _ShareCardButton extends StatefulWidget {
  const _ShareCardButton({required this.entries});
  final List<RankingEntry> entries;

  @override
  State<_ShareCardButton> createState() => _ShareCardButtonState();
}

class _ShareCardButtonState extends State<_ShareCardButton> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.mediumImpact();

    // contextはawait前に取得する
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;

    try {
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: 'image/png',
        name: 'mannaka_ranking.png',
      );

      await Share.shareXFiles(
        [xFile],
        text: 'まんなか指数ランキング🏆\nみんなの集合場所といえば${widget.entries.isNotEmpty ? widget.entries.first.stationName : ''}！\n#まんなか #集合場所',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      debugPrint('ShareCard error: ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // シェア用カード（非表示だが描画は必要）
        RepaintBoundary(
          key: _repaintKey,
          child: _ShareCard(entries: widget.entries),
        ),

        // シェアボタン
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(
              _sharing ? 'シェア中...' : 'ランキングをシェアする',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── シェア用カード（画像化される） ──────────────────────────────────────

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.entries});
  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final medals = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];

    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            AppColors.primary.withValues(alpha: 0.85),
            const Color(0xFF16213e),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // タイトル
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 8),
              const Text(
                'まんなか指数ランキング',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '集合場所に一番選ばれたエリア',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),

          // トップ3
          ...entries.take(3).toList().asMap().entries.map((e) {
            final entry = e.value;
            final medalColor = medals[e.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: medalColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: medalColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${entry.rank}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: medalColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${entry.stationName}駅',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.searchCount}回',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: medalColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // フッター
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'まんなか - 集合場所を決めるアプリ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── エラー・空状態 ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'データを取得できませんでした',
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'まだランキングデータがありません',
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'アプリを使ってお店を探すとランキングが更新されます',
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
