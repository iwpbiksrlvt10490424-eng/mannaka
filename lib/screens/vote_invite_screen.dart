import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import 'voting_screen.dart';

class VoteInviteScreen extends StatelessWidget {
  const VoteInviteScreen({super.key, required this.sessionId, required this.hostName});
  final String sessionId;
  final String hostName;

  @override
  Widget build(BuildContext context) {
    final link = 'mannaka://vote?session=$sessionId&voter=';
    final shareText = '【Aima】お店を一緒に選んでください！\n\nリンクをタップして投票してね\n$link\n（24時間有効）';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('投票リンクをシェア'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  const Icon(Icons.how_to_vote_rounded, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text('投票セッションを作成しました！', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'LINEで友達にリンクを送って\n一緒にお店を選びましょう',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  // セッションID表示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'コード: $sessionId',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Builder(
                builder: (btnCtx) => ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final box = btnCtx.findRenderObject() as RenderBox?;
                    Share.share(
                      shareText,
                      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
                    );
                  },
                  icon: const Icon(Icons.ios_share, size: 20),
                  label: const Text('LINEでシェアする', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VotingScreen(sessionId: sessionId, voterName: null),
                  ),
                ),
                icon: const Icon(Icons.bar_chart_rounded, size: 20),
                label: const Text('投票結果をリアルタイムで見る', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
