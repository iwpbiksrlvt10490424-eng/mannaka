import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_share_draft.dart';
import '../providers/saved_share_drafts_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import '../widgets/line_icon.dart';

/// 保存された LINE 共有の下書き一覧。あとで送りたいユーザー向け。
/// LINE 本文には上位 5 件を入れる（1 回で送れる上限）。
class SavedDraftsScreen extends ConsumerWidget {
  const SavedDraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(savedShareDraftsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('保存した候補'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: draftsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _errorUi(ref),
        data: (drafts) => drafts.isEmpty
            ? _empty()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DraftCard(draft: drafts[i]),
              ),
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 56, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text('保存した候補はありません',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            SizedBox(height: 6),
            Text(
              '結果画面で候補を選んで「保存」すると、\nここから後でまとめて LINE に送れます',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorUi(WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('読み込みに失敗しました',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text(
              '保存した候補を読み込めませんでした。\nしばらく経ってからもう一度開いてください',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(savedShareDraftsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({required this.draft});
  final SavedShareDraft draft;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final d = widget.draft;
      await AnalyticsService.logLineShareInitiated(
        candidateCount: d.candidates.length,
        categories: d.candidates.map((c) => c.category).toSet().toList(),
        hasWebUrl: false,
        groupNames: const [],
      );
      final text = _buildText(d);
      final ok = await ShareUtils.launchLineWithText(text);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LINE が見つかりませんでした。インストール後に再度お試しください'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// LINE 本文。1 回で送れるのは上位 5 件まで。
  String _buildText(SavedShareDraft d) {
    final top = d.candidates.take(5).toList();
    final extra = d.candidates.length - top.length;

    final sb = StringBuffer();
    sb.writeln('🍽 お店の候補を共有します');
    sb.writeln('');
    sb.writeln('📍 ${d.stationName}駅周辺');
    if (d.date.isNotEmpty || d.meetingTime.isNotEmpty) {
      final parts = <String>[];
      if (d.date.isNotEmpty) {
        try {
          final dt = DateTime.parse(d.date);
          parts.add('${dt.month}/${dt.day}');
        } catch (_) {}
      }
      if (d.meetingTime.isNotEmpty) parts.add(d.meetingTime);
      sb.writeln('🗓 ${parts.join(' ')}');
    }
    if (d.participantTimes.isNotEmpty) {
      final line = d.participantTimes.entries
          .map((e) => '${e.key} ${e.value}分')
          .join(' / ');
      sb.writeln('⏱ $line');
    }
    sb.writeln('');
    sb.writeln('候補のお店（${d.candidates.length}件）');
    for (var i = 0; i < top.length; i++) {
      final c = top[i];
      sb.writeln('');
      sb.writeln('${i + 1}. ${c.name}');
      final meta = <String>[c.category, c.priceStr];
      if ((c.rating ?? 0) > 0) meta.add('★${c.rating!.toStringAsFixed(1)}');
      sb.writeln('  ${meta.join(' / ')}');
      // Hotpepper 由来なら固定長の公式ページURL、無ければ Google 検索にフォールバック。
      sb.writeln('  ${ShareUtils.shortStoreUrl(c.hotpepperUrl, c.name, d.stationName, lat: c.lat, lng: c.lng)}');
    }
    sb.writeln('');
    if (extra > 0) {
      sb.writeln('1回で送れるのは5件までです');
    }
    sb.writeln(ShareUtils.lineDownloadCta);
    sb.write(ShareUtils.appStoreUrl);
    return sb.toString();
  }

  Future<void> _delete() async {
    HapticFeedback.lightImpact();
    await ref
        .read(savedShareDraftsProvider.notifier)
        .remove(widget.draft.id);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final when =
        '${d.createdAt.month}/${d.createdAt.day} ${d.createdAt.hour.toString().padLeft(2, '0')}:${d.createdAt.minute.toString().padLeft(2, '0')} 保存';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${d.stationName}駅 · ${d.candidates.length}件',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(when,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          // LINE で送れる上限の 5 件まで全件表示。各候補に写真サムネを横付け。
          // 過去は take(3) + 「ほか X 件」だったが、ユーザー観点では「保存した候補が
          // 全部見えない」状態だったので 5 件全部見せる方針に変更。
          for (final c in d.candidates.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: c.imageUrl != null && c.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: c.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: Colors.grey.shade100),
                              errorWidget: (_, __, ___) =>
                                  Container(color: Colors.grey.shade200),
                            )
                          : Container(color: Colors.grey.shade200),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06C755),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sending)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const LineIcon(
                              size: 16,
                              filled: false,
                              iconColor: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          _sending ? '送信中…' : 'LINEで送る',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.textTertiary,
                onPressed: _delete,
                tooltip: '削除',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
