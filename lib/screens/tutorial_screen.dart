import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// 既存ユーザー向けの「使い方」画面。オンボーディングと同じ内容を
/// いつでも再確認できるようにするための読み物型チュートリアル。
/// 各項目は「何ができるか / どこにあるか」を 1 対で示す。
class TutorialScreen extends ConsumerWidget {
  const TutorialScreen({super.key});

  static const _sections = <_Section>[
    _Section(
      icon: Icons.search_rounded,
      title: 'まずは駅を入力',
      body: '参加者の最寄り駅を入れるだけ。\n'
          'みんなにちょうどいい集合駅を自動で提案します。',
      where: '「探す」タブ',
    ),
    _Section(
      icon: Icons.gps_fixed_rounded,
      title: '現在地で最寄り駅を自動入力',
      body: '位置情報を ON にすると、\n'
          '自分の最寄り駅が自動で入ります。',
      where: 'マイページ > 位置情報の設定',
    ),
    _Section(
      icon: Icons.event_available_rounded,
      title: '日付と予約時間を決める',
      body: 'その時間に開いているお店だけを提案。\n'
          '日曜は赤・土曜は青で分かりやすく表示。',
      where: '「探す」画面の日付バー',
    ),
    _Section(
      icon: Icons.add_circle_outline_rounded,
      title: '候補のカードに「+」で追加',
      body: 'お店カードの右上「+」をタップすると候補に入ります。\n'
          '駅タブを跨いでも選択は保持されます。',
      where: '検索結果画面',
    ),
    _Section(
      icon: Icons.chat_rounded,
      title: 'まとめてLINEで送る',
      body: '下部の「N件をLINEで送る」で一気に共有。\n'
          'グループを選んで送ることもできます。',
      where: '検索結果画面の下部バー',
    ),
    _Section(
      icon: Icons.public_rounded,
      title: 'アプリ未インストールの相手も見れる',
      body: 'LINE 本文に Web ページの URL が付きます。\n'
          '相手はタップするだけで候補を閲覧できます。',
      where: '送信時に自動付与',
    ),
    _Section(
      icon: Icons.bookmark_rounded,
      title: 'あとで送るなら保存',
      body: '忙しいときは「保存」をタップ。\n'
          'マイページの「保存した候補」からあとで送れます。',
      where: 'マイページ > 保存した候補',
    ),
    _Section(
      icon: Icons.check_circle_rounded,
      title: '予約済み・行ったお店を記録',
      body: '予約したお店・行ったお店を手動で追加して\n'
          'グループ単位で履歴を振り返れます。',
      where: '予約済み / 行ったお店 画面の「+」',
    ),
    _Section(
      icon: Icons.filter_list_rounded,
      title: '条件で絞り込み',
      body: 'ジャンル・予算・個室・飲み放題・予約可能・\n'
          'チェーン店除外などで候補を絞り込み可能。',
      where: '検索結果画面 右上の「条件を変更」',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('使い方'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _SectionCard(section: _sections[i]),
      ),
    );
  }
}

class _Section {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.where,
  });
  final IconData icon;
  final String title;
  final String body;
  final String where;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text(section.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    )),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        section.where,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
