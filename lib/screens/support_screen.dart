import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _howToSteps = [
    (
      Icons.group_add_rounded,
      'メンバーを追加する',
      '「探す」画面で参加者の名前と出発駅を入力します。自分の出発駅はホームに設定しておくと毎回自動入力されます。',
    ),
    (
      Icons.tune_rounded,
      '好みを設定する',
      '価格帯・ジャンル・人数などの条件を選んでください。条件は後からでも変更できます。',
    ),
    (
      Icons.search_rounded,
      'お店を探す',
      '「このメンバーで探す」を押すと、全員の出発駅を考慮してちょうど良いエリアのお店を自動で提案します。',
    ),
    (
      Icons.restaurant_menu_rounded,
      'お店を決める',
      'お店一覧から気になるお店を選んで詳細を確認。予約ページへのリンクからHotpepperで予約できます。',
    ),
    (
      Icons.share_rounded,
      'LINEでシェアする',
      '予約が完了したら「LINEでシェア」でお店・住所・最寄り駅をまとめてグループに送れます。',
    ),
    (
      Icons.check_circle_outline_rounded,
      '行ったお店に記録する',
      '「予約済み」画面の「決定！行った」ボタンを押すと行ったお店に記録されます。誰と行ったかグループ名も残ります。',
    ),
  ];

  static const _faqs = [
    (
      '最適なお店はどうやって決まるの？',
      '全員の出発駅からの移動時間を計算して、誰かが極端に遠くならないよう「公平さ」を重視して自動でおすすめします。予約しやすいお店ほど上位に表示されます。',
    ),
    (
      '自分の出発駅を毎回入力したくない',
      'マイページでホーム駅を登録しておくと、「探す」画面を開いたときに自動で入力されます。位置情報ボタンを押して現在地から自動設定することもできます。',
    ),
    (
      'よく使う駅をすぐ選べるようにしたい',
      '探す画面で駅を選ぶと自動的にお気に入りとして保存され、次回から入力欄の上部に表示されます（最大3件）。',
    ),
    (
      'お店のジャンルで絞り込みたい',
      'お店一覧の上部にあるジャンルボタンをタップして絞り込めます。複数のジャンルを同時に選ぶこともできます。',
    ),
    (
      '友達がアプリを持っていなくても使える？',
      'はい。集合場所が決まったらLINEでシェアするだけで、友達はアプリなしで場所・地図を確認できます。',
    ),
    (
      '以前の検索結果をもう一度見たい',
      '「履歴」タブの検索履歴カードをタップすると、そのときの検索結果を再表示できます。',
    ),
    (
      '行ったお店の記録を消したい',
      '「履歴」→「行ったお店」タブでカードを左にスワイプすると1件ずつ削除できます。',
    ),
    (
      '予約したお店はどこで確認できる？',
      '「予約済み」タブに保存されます。お店に行ったら「決定！行った」を押すと「行ったお店」に記録が移ります。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('使い方・よくある質問',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 使い方 ────────────────────────────────────────────────────
          _sectionHeader('使い方'),
          const SizedBox(height: 8),
          ...List.generate(_howToSteps.length, (i) {
            final step = _howToSteps[i];
            return _HowToItem(
              step: i + 1,
              icon: step.$1,
              title: step.$2,
              description: step.$3,
            );
          }),

          const SizedBox(height: 28),

          // ─── よくある質問 ──────────────────────────────────────────────
          _sectionHeader('よくある質問'),
          const SizedBox(height: 8),
          ..._faqs.map((faq) => _FaqItem(q: faq.$1, a: faq.$2)),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'バージョン 1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ─── 使い方ステップアイテム ──────────────────────────────────────────────────

class _HowToItem extends StatelessWidget {
  const _HowToItem({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });
  final int step;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAQアコーディオン ────────────────────────────────────────────────────────

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text('Q',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.q,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('A',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.a,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
