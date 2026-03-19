import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _faqs = [
    (
      'どうやって最適なお店を提案しますか？',
      '全員の出発駅から各エリアへの移動時間を計算し、誰にとっても「ちょうどいい」お店を自動でスコアリングして提案します。予約のしやすさ・移動の公平さ・評価を総合的に判断します。',
    ),
    (
      '位置情報はどこに保存されますか？',
      '位置情報はアプリ内のみで使用し、外部サーバーには送信されません（リアルタイム位置共有機能を使う場合を除く）。',
    ),
    (
      '友達がアプリを持っていない場合は？',
      'LINEで位置共有リンクを送ると、友達はブラウザで現在地を共有できます。アプリのインストールは不要です。',
    ),
    (
      'お店が少ない・表示されない場合は？',
      'Hotpepper APIキーが設定されているか確認してください。未設定の場合は代替データベースを使用しますが、件数が少なくなります。',
    ),
    (
      'お気に入り駅の使い方は？',
      '探す画面で駅を選択するとお気に入りに自動保存されます。次回から駅入力時のリストの上部に表示され、ワンタップで選択できます。',
    ),
    (
      '予約はどうやってできますか？',
      'お店の詳細画面から「予約する」ボタンを押すとHotpepperの予約ページが開きます。',
    ),
    (
      'ホーム駅を設定するとどうなりますか？',
      '探す画面を開いたとき、「自分」の出発駅にホーム駅が自動入力されます。毎回入力する手間が省けます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('サポート'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── よくある質問 ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'よくある質問',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
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
}


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
