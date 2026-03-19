import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voting_service.dart';
import '../theme/app_theme.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key, required this.sessionId, this.voterName});
  final String sessionId;
  final String? voterName; // null = host (watching only)

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? _votedFor; // 投票済みのrestaurantId
  bool _voting = false;
  String? _selectedForDecision; // ホストが決定用に選択中のrestaurantId
  bool _postFrameScheduled = false;

  Future<void> _vote(String restaurantId, String restaurantName) async {
    if (_votedFor != null || widget.voterName == null) return;
    setState(() => _voting = true);
    HapticFeedback.mediumImpact();
    try {
      await VotingService.vote(
        sessionId: widget.sessionId,
        restaurantId: restaurantId,
        voterName: widget.voterName!,
      );
      if (!mounted) return;
      setState(() {
        _votedFor = restaurantId;
        _voting = false;
      });
    } catch (e) {
      debugPrint('VotingScreen: vote failed - ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _voting = false);
      final message = e is ArgumentError
          ? e.message?.toString() ?? '入力値が正しくありません'
          : '投票に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _confirmDecision(String restaurantId, String restaurantName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('お店を決定', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('「$restaurantName」に決定しますか？\n全員に通知されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('決定する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await VotingService.closeSession(
        sessionId: widget.sessionId,
        decidedRestaurantId: restaurantId,
        decidedRestaurantName: restaurantName,
      );
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$restaurantNameに決定しました！'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('VotingScreen: closeSession failed - ${e.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('エラーが発生しました'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(widget.voterName == null ? 'みんなの投票結果' : 'お店を選んでね'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: VotingService.watchSession(widget.sessionId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('投票セッションが見つかりません'));
          }
          final rawList = (data['candidates'] as List?) ?? [];
          final candidates = rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final hostName = data['hostName'] as String? ?? '';
          final isHost = widget.voterName == null;
          final status = data['status'] as String? ?? 'open';
          final decidedName = data['decidedRestaurantName'] as String?;

          // セッションがクローズされた場合
          if (status == 'closed' && decidedName != null) {
            return _buildClosedView(decidedName);
          }

          // 最多票を計算
          final int maxVotes = candidates.fold(0, (m, c) => ((c['votes'] as int?) ?? 0) > m ? ((c['votes'] as int?) ?? 0) : m);

          // ホストの場合、最多票のお店をデフォルト選択（build() 副作用禁止 → addPostFrameCallback）
          if (isHost && _selectedForDecision == null && maxVotes > 0 && !_postFrameScheduled) {
            final topCandidate = candidates.firstWhere((c) => ((c['votes'] as int?) ?? 0) == maxVotes);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _postFrameScheduled = false;
              if (mounted) setState(() { _selectedForDecision = topCandidate['id'] as String?; });
            });
            _postFrameScheduled = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.how_to_vote_rounded, size: 32, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      isHost ? '$hostNameさんが投票を作成しました' : '$hostNameさんからの投票依頼',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHost ? 'みんなの投票をリアルタイムで確認できます' : '行きたいお店を1つ選んでください',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 候補カード
              ...candidates.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                final id = (c['id'] as String?) ?? '';
                final name = (c['name'] as String?) ?? '';
                final votes = (c['votes'] as int?) ?? 0;
                final isLeading = votes == maxVotes && maxVotes > 0;
                final isMyVote = _votedFor == id;
                final hasVoted = _votedFor != null;
                final totalVotes = candidates.fold(0, (s, cv) => s + ((cv['votes'] as int?) ?? 0));
                final isSelectedForDecision = isHost && _selectedForDecision == id;

                return GestureDetector(
                  onTap: () {
                    if (isHost) {
                      // ホストは決定用の選択を切り替え
                      setState(() => _selectedForDecision = id);
                      HapticFeedback.selectionClick();
                    } else if (!hasVoted && !_voting) {
                      _vote(id, name);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelectedForDecision
                            ? AppColors.primary
                            : isMyVote
                                ? AppColors.primary
                                : isLeading
                                    ? const Color(0xFFFFB800)
                                    : Colors.transparent,
                        width: isSelectedForDecision || isMyVote || isLeading ? 2 : 0,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // 順位バッジ
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isLeading && maxVotes > 0
                                    ? const Color(0xFFFFB800)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text('${i + 1}', style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: isLeading && maxVotes > 0 ? Colors.white : AppColors.primary,
                                )),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                    Text('${(c['category'] as String?) ?? ''}  ·  ${(c['priceStr'] as String?) ?? ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (isSelectedForDecision)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                              if (isLeading && maxVotes > 0 && !isSelectedForDecision)
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB800), size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 投票バー
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalVotes == 0 ? 0 : votes / totalVotes,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isMyVote ? AppColors.primary : const Color(0xFFFFB800),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$votes票', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: isMyVote ? AppColors.primary : AppColors.textSecondary,
                              )),
                              if (isMyVote)
                                const Row(children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text('投票済み', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ]),
                              if (!isHost && !hasVoted)
                                Text('タップして投票', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              if (isHost && isSelectedForDecision)
                                const Text('決定候補', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // ホスト用「このお店に決定！」ボタン
              if (isHost) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _selectedForDecision != null
                            ? '「${_getNameById(candidates, _selectedForDecision!)}」を決定しますか？'
                            : 'お店を選択してください',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '候補をタップして変更できます',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _selectedForDecision != null
                              ? () => _confirmDecision(
                                  _selectedForDecision!,
                                  _getNameById(candidates, _selectedForDecision!),
                                )
                              : null,
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const Text('このお店に決定！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _getNameById(List<Map<String, dynamic>> candidates, String id) {
    final c = candidates.firstWhere((c) => c['id'] == id, orElse: () => {'name': ''});
    return c['name'] as String? ?? '';
  }

  Widget _buildClosedView(String decidedName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded, size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('決定しました！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                decidedName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'に決定しました',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('閉じる', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
