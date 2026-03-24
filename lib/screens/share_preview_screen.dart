import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scored_restaurant.dart';
import '../models/participant.dart';
import '../providers/search_provider.dart';
import '../services/voting_service.dart';
import '../theme/app_theme.dart';
import '../utils/share_utils.dart';
import '../widgets/share_card_widget.dart';
import 'restaurant_detail_screen.dart';
import 'vote_invite_screen.dart';

class SharePreviewScreen extends ConsumerStatefulWidget {
  const SharePreviewScreen({
    super.key,
    required this.scored,
    required this.participants,
  });

  final ScoredRestaurant scored;
  final List<Participant> participants;

  @override
  ConsumerState<SharePreviewScreen> createState() =>
      _SharePreviewScreenState();
}

class _SharePreviewScreenState extends ConsumerState<SharePreviewScreen> {
  final _cardKey = GlobalKey();
  bool _isCapturing = false;
  bool _startingVote = false;
  bool _includeBackup = true;

  Future<void> _startVoting() async {
    if (_startingVote) return;
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser!;
    setState(() => _startingVote = true);
    HapticFeedback.mediumImpact();
    try {
      final state = ref.read(searchProvider);
      final top3 = state.sortedRestaurants.take(3).toList();
      final hostName = widget.participants.isNotEmpty
          ? widget.participants.first.name
          : 'ホスト';
      final sessionId = await VotingService.createSession(
        hostName: hostName,
        candidates: top3,
        hostUid: user.uid,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoteInviteScreen(sessionId: sessionId, hostName: hostName),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ArgumentError
          ? e.message?.toString() ?? '入力値が正しくありません'
          : '投票セッションの作成に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _startingVote = false);
    }
  }

  String _buildShareText(SearchState state) {
    final text = ShareUtils.buildRestaurantShareText(
      state,
      primaryScored: widget.scored,
      includeBackup: _includeBackup,
    );
    if (text.isNotEmpty) return text;

    // フォールバック：選択レストランのみ
    final r = widget.scored.restaurant;
    final names = widget.participants.map((p) => p.name).join('、');
    // TODO(release): App Store公開後に実際のApp IDに置き換える
    // '▶ App Store: https://apps.apple.com/jp/app/aima/id<実際のID>'
    return '${r.emoji} ${r.name} に決まりました！\n\n📍 ${r.address}\n参加者: $names\n\nAimaアプリで計算しました\n#Aima #グルメ';
  }

  Future<void> _shareAsImage() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aima_share.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '集合場所が決まりました！',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('シェアに失敗しました。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final r = widget.scored.restaurant;
    final names = widget.participants.map((p) => p.name).toList();
    final stationName = state.selectedMeetingPoint?.stationName ??
        widget.scored.areaLabel.replaceAll('駅エリア', '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('集合場所が決まりました！'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── シェアカードプレビュー ────────────────────────
            RepaintBoundary(
              key: _cardKey,
              child: ShareCardWidget(
                restaurant: widget.scored,
                stationName: stationName,
                participantNames: names,
              ),
            ),

            const SizedBox(height: 20),

            // ─── メインカード ──────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.ctaShadow,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.restaurant_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      r.category,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // スコアバッジ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WhiteBadge(
                          icon: Icons.star_rounded,
                          label: r.ratingStr),
                      const SizedBox(width: 10),
                      _WhiteBadge(
                          icon: Icons.attach_money_rounded,
                          label: r.priceStr),
                      if (r.isReservable) ...[
                        const SizedBox(width: 10),
                        _WhiteBadge(
                            icon: Icons.calendar_today_rounded,
                            label: '予約可'),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 情報カード ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.location_on_rounded,
                      label: '住所',
                      value: r.address),
                  const SizedBox(height: 8),
                  _InfoRow(
                      icon: Icons.access_time_rounded,
                      label: '営業時間',
                      value: r.openHours),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 参加者 ────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '参加者',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: names
                        .map((name) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF3B82F6),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: name.isNotEmpty
                                        ? Text(
                                            name[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── バックアップシェアトグル ──────────────────────
            if (state.sortedRestaurants.length > 1)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.cardShadow,
                ),
                child: SwitchListTile(
                  value: _includeBackup,
                  onChanged: (v) => setState(() => _includeBackup = v),
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'バックアップも含めてシェア',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '代替案をシェアテキストに追加',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),

            const SizedBox(height: 28),

            // ─── アクションボタン ──────────────────────────────

            // 画像でシェアボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isCapturing ? null : _shareAsImage,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.image_outlined, size: 20),
                label: Text(
                  _isCapturing ? '生成中...' : '画像でシェア',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
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

            const SizedBox(height: 12),

            // テキストでシェアボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Builder(
                builder: (btnCtx) => ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final box =
                        btnCtx.findRenderObject() as RenderBox?;
                    final origin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    await Share.share(_buildShareText(state),
                        sharePositionOrigin: origin);
                  },
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text('みんなにシェアする',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // みんなで投票するボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _startVoting,
                icon: _startingVote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_vote_rounded, size: 20),
                label: const Text('みんなで投票する',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RestaurantDetailScreen(restaurant: r),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('詳細を確認する',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _WhiteBadge extends StatelessWidget {
  const _WhiteBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
