import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/saved_share_draft.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_share_drafts_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/line_icon.dart';

/// 保存された LINE 共有の下書き一覧。あとで送りたいユーザー向け。
/// 各下書きは Firestore /public_shares に登録してから LINE 起動する。
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
        error: (_, __) => _empty(),
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
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({required this.draft});
  final SavedShareDraft draft;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  bool _sending = false;

  Future<String?> _createPublicShareDoc() async {
    try {
      // Firestore rules（request.auth != null）を満たすため、書込前に匿名認証を確立
      await ensureUid();
      final d = widget.draft;
      final data = {
        'createdAt': FieldValue.serverTimestamp(),
        'stationName': d.stationName,
        'date': d.date.isEmpty ? null : d.date,
        'meetingTime': d.meetingTime.isEmpty ? null : d.meetingTime,
        'participantTimes': d.participantTimes,
        'candidates': d.candidates.map((c) => c.toJson()).toList(),
      };
      final doc = await FirebaseFirestore.instance
          .collection('public_shares')
          .add(data);
      return 'https://mannnaka.web.app/s/${doc.id}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _send() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final d = widget.draft;
      final shareUrl = await _createPublicShareDoc();
      await AnalyticsService.logLineShareInitiated(
        candidateCount: d.candidates.length,
        categories: d.candidates.map((c) => c.category).toSet().toList(),
        hasWebUrl: shareUrl != null,
        groupNames: const [],
      );
      final text = _buildText(d, shareUrl);
      final encoded = Uri.encodeComponent(text);
      final uri = Uri.parse('https://line.me/R/share?text=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _buildText(SavedShareDraft d, String? shareUrl) {
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
    for (final c in d.candidates) {
      sb.writeln('');
      sb.writeln('・${c.name}');
      final meta = <String>[c.category, c.priceStr];
      if (c.rating > 0) meta.add('★${c.rating.toStringAsFixed(1)}');
      sb.writeln('  ${meta.join(' / ')}');
      if (c.lat != null && c.lng != null) {
        sb.writeln('  https://maps.google.com/maps?q=${c.lat},${c.lng}');
      }
    }
    sb.writeln('');
    if (shareUrl != null) {
      sb.writeln('🌐 Webで見る（アプリ不要）');
      sb.writeln(shareUrl);
      sb.writeln('');
    }
    sb.writeln('Aimachi（無料）');
    sb.write('https://apps.apple.com/jp/app/aimachi/id6761008332');
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
          for (final c in d.candidates.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '・${c.name}（${c.category}）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (d.candidates.length > 3)
            Text(
              '...ほか${d.candidates.length - 3}件',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
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
