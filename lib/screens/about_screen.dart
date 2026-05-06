import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// アプリについて画面。
///
/// マイページからの遷移先。商用アプリとして必要な「店舗情報の取得元」
/// 「予約は外部サイトで行う旨」「バージョン」「LINE 共有で送られる内容」
/// を一箇所に集約する。
///
/// UX critique #19 を受けて新設: 信頼感を作る情報導線が手薄だった。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.5';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('アプリについて',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: 'Aimachi',
            children: [
              _Row(label: 'バージョン', value: _appVersion),
              _Row(
                label: '提供',
                value: '個人開発',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '店舗情報について',
            body: '本アプリで表示するお店の情報（店名・住所・営業時間・写真・評価など）は、'
                '以下の外部サービスから取得しています。'
                '最新の情報は各店舗の予約ページや公式サイトでご確認ください。',
            children: [
              _Row(label: '店舗データ', value: 'Hotpepper グルメ API'),
              _Row(label: '評価・写真', value: 'Google Places API'),
              _Row(label: '駅・施設情報', value: 'OpenStreetMap'),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '予約について',
            body: '予約は外部の予約サイト（Hotpepper など）で行います。'
                'Aimachi 内では候補店舗の保存と LINE 共有ができます。'
                '予約完了の有無や予約内容は外部サイトで管理してください。',
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'LINE 共有について',
            body: '「LINE で共有」を押すと、LINE アプリを起動して友だちにメッセージを送信します。'
                'メッセージには集合駅名・候補店舗名・店舗ページへのリンクが含まれます。'
                'Aimachi が直接 LINE のサーバーと通信することはありません。',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.body, this.children = const []});
  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
