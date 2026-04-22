import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';

// ─── データ定義 ────────────────────────────────────────────────────────────────

class _AreaCard {
  const _AreaCard({
    required this.area,
    required this.copy,
    required this.reason,
    required this.tags,
    required this.emoji,
  });
  final String area;
  final String copy;
  final String reason;
  final List<String> tags;
  final String emoji;
}

class _SceneData {
  const _SceneData({
    required this.label,
    required this.icon,
    required this.color,
    required this.areas,
  });
  final String label;
  final IconData icon;
  final Color color;
  final List<_AreaCard> areas;
}

const _scenes = [
  _SceneData(
    label: '女子会',
    icon: Icons.people_alt_rounded,
    color: Color(0xFFEC4899),
    areas: [
      _AreaCard(
        area: '表参道',
        emoji: '🌸',
        copy: '女子会の絶対王道エリア',
        reason: 'フォトジェニックなカフェ・フレンチ・デザートの名店が密集。「インスタ映え」を求めるなら迷わずここ。',
        tags: ['カフェ', 'フレンチ', 'スイーツ'],
      ),
      _AreaCard(
        area: '自由が丘',
        emoji: '🍰',
        copy: 'スイーツの聖地で気分UP',
        reason: 'パティスリーやヨーロッパ風の街並みが女子会に最適。おしゃれな雑貨屋も多く、食事前後に散策できる。',
        tags: ['スイーツ', 'カフェ', '雑貨'],
      ),
      _AreaCard(
        area: '中目黒',
        emoji: '🌸',
        copy: '目黒川沿いのムード最高',
        reason: '隠れ家レストランと人気カフェが多く、話のネタになる店が見つかりやすい。落ち着いて話せる雰囲気。',
        tags: ['カフェ', 'ダイニング', 'イタリアン'],
      ),
    ],
  ),
  _SceneData(
    label: '合コン',
    icon: Icons.celebration_rounded,
    color: Color(0xFF8B5CF6),
    areas: [
      _AreaCard(
        area: '恵比寿',
        emoji: '🥂',
        copy: '雰囲気が自然と盛り上がる',
        reason: '高感度なレストランとバーが揃い、初対面でも話しやすい空気感。ディナー後のはしご酒もしやすい立地。',
        tags: ['イタリアン', 'ワインバー', 'フレンチ'],
      ),
      _AreaCard(
        area: '六本木',
        emoji: '🌃',
        copy: '非日常感がテンションを上げる',
        reason: '夜景が見えるレストランやラウンジが充実。「いつもと違う場所」という特別感がムードを作る。',
        tags: ['夜景', 'バー', 'ダイニング'],
      ),
      _AreaCard(
        area: '銀座',
        emoji: '✨',
        copy: '大人の合コンはここ一択',
        reason: '落ち着いた個室和食や鉄板焼きが豊富。「ちゃんとした場所で会いたい」という印象を与えられる。',
        tags: ['和食', '個室', '鉄板焼き'],
      ),
    ],
  ),
  _SceneData(
    label: '誕生日',
    icon: Icons.cake_rounded,
    color: Color(0xFFF59E0B),
    areas: [
      _AreaCard(
        area: '新宿',
        emoji: '🎂',
        copy: '個室・サプライズ対応が最多',
        reason: '大箱の個室居酒屋からフレンチまで選択肢が圧倒的。サプライズ演出に慣れているお店が多い。',
        tags: ['個室', '居酒屋', 'フレンチ'],
      ),
      _AreaCard(
        area: '渋谷',
        emoji: '🎉',
        copy: 'ハプニングが楽しい誕生日に',
        reason: '多様な価格帯とジャンルから選べる。誕生日ケーキのデリバリー対応店が多く、サプライズがしやすい。',
        tags: ['ダイニング', '個室', 'バー'],
      ),
      _AreaCard(
        area: '赤坂',
        emoji: '🎁',
        copy: '特別な日だから上質な空間で',
        reason: '落ち着いた高級感のある店が揃い、誕生日を「大人の祝い事」にしたいときにぴったり。',
        tags: ['懐石', 'フレンチ', '個室'],
      ),
    ],
  ),
  _SceneData(
    label: 'ランチ',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFF10B981),
    areas: [
      _AreaCard(
        area: '銀座',
        emoji: '🍱',
        copy: 'ランチコスパが東京最強',
        reason: '夜は高価なフレンチや和食も昼は2,000円前後で楽しめる。時間を忘れてゆっくり話せる上品な空間。',
        tags: ['フレンチ', '和食', 'イタリアン'],
      ),
      _AreaCard(
        area: '表参道',
        emoji: '🥗',
        copy: 'ヘルシーランチが充実',
        reason: 'サラダ・玄米・ビーガン系の人気店が多く、健康意識の高いメンバーでの集まりに最適。',
        tags: ['カフェ', 'ヘルシー', 'サラダ'],
      ),
      _AreaCard(
        area: '御茶ノ水',
        emoji: '📚',
        copy: 'コスパ◎ 落ち着いて話せる',
        reason: '学生・社会人が交差するエリアで、手頃なランチが豊富。昼時でも席に余裕があることが多い。',
        tags: ['カフェ', '定食', 'カレー'],
      ),
    ],
  ),
  _SceneData(
    label: '歓迎会',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFF3B82F6),
    areas: [
      _AreaCard(
        area: '新橋',
        emoji: '🍺',
        copy: '歓迎会の鉄板エリア',
        reason: 'サラリーマンの聖地として大人数対応の居酒屋が揃う。飲み放題コースが充実していて幹事が楽。',
        tags: ['居酒屋', '個室', '飲み放題'],
      ),
      _AreaCard(
        area: '新宿',
        emoji: '🎊',
        copy: 'どんな人数にも対応できる',
        reason: '10名〜50名超の大宴会場から少人数個室まで選択肢が圧倒的。予算帯も幅広い。',
        tags: ['居酒屋', '和食', '個室'],
      ),
      _AreaCard(
        area: '池袋',
        emoji: '🥳',
        copy: '北部・西部エリアの人に最適',
        reason: '幹事が人数調整しやすいチェーン系個室居酒屋が多く、予算管理がしやすい。アクセスも抜群。',
        tags: ['居酒屋', '飲み放題', '個室'],
      ),
    ],
  ),
  _SceneData(
    label: 'デート',
    icon: Icons.favorite_rounded,
    color: Color(0xFFEF4444),
    areas: [
      _AreaCard(
        area: '中目黒',
        emoji: '💕',
        copy: '東京で一番デートに向いてる',
        reason: '目黒川沿いの散歩→カフェ→ディナーという黄金コースがある。距離が縮まりやすい雰囲気。',
        tags: ['カフェ', 'ダイニング', '散歩'],
      ),
      _AreaCard(
        area: '恵比寿',
        emoji: '🌹',
        copy: '大人デートの定番',
        reason: 'ガーデンプレイスを中心に洗練されたレストランが揃う。「さりげなく上品」なデートがしやすい。',
        tags: ['フレンチ', 'イタリアン', 'ワイン'],
      ),
      _AreaCard(
        area: '表参道',
        emoji: '👫',
        copy: 'ショッピング→ディナーの王道',
        reason: 'ウィンドウショッピングから始めてディナーへ流れるデートに最適。話のネタに困らない街。',
        tags: ['カフェ', 'ショッピング', 'フレンチ'],
      ),
    ],
  ),
];

// ─── 画面 ──────────────────────────────────────────────────────────────────────

class SceneAreaScreen extends StatefulWidget {
  const SceneAreaScreen({super.key, this.onStartSearch});
  final VoidCallback? onStartSearch;

  @override
  State<SceneAreaScreen> createState() => _SceneAreaScreenState();
}

class _SceneAreaScreenState extends State<SceneAreaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _scenes.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.divider,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'シーン別おすすめエリア',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'エリアを選んでお店探しのヒントに',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          tabs: _scenes
              .map((s) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 15),
                        const SizedBox(width: 4),
                        Text(s.label),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _scenes
            .map((scene) => _SceneTab(
                  scene: scene,
                  onStartSearch: widget.onStartSearch,
                ))
            .toList(),
      ),
    );
  }
}

// ─── タブコンテンツ ────────────────────────────────────────────────────────────

class _SceneTab extends StatelessWidget {
  const _SceneTab({required this.scene, this.onStartSearch});
  final _SceneData scene;
  final VoidCallback? onStartSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        // シーン説明ヘッダー
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scene.color.withValues(alpha: 0.12),
                scene.color.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scene.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scene.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(scene.icon, color: scene.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scene.label}におすすめのエリア',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scene.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'このエリアでお店を探してみましょう',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // エリアカード一覧
        ...scene.areas.asMap().entries.map((e) {
          final rank = e.key + 1;
          final area = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AreaCardWidget(
              rank: rank,
              area: area,
              scene: scene,
              onStartSearch: onStartSearch,
            ),
          );
        }),
      ],
    );
  }
}

// ─── エリアカード ──────────────────────────────────────────────────────────────

class _AreaCardWidget extends StatelessWidget {
  const _AreaCardWidget({
    required this.rank,
    required this.area,
    required this.scene,
    this.onStartSearch,
  });
  final int rank;
  final _AreaCard area;
  final _SceneData scene;
  final VoidCallback? onStartSearch;

  Future<void> _share(BuildContext context) async {
    HapticFeedback.lightImpact();
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      '${area.emoji} ${scene.label}するなら「${area.area}」がおすすめ！\n'
      '${area.copy}\n\n'
      '${area.tags.map((t) => '#$t').join(' ')}\n'
      '#Aimachi #${scene.label} #${area.area}',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー部
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: scene.color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // ランクバッジ
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: rankColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${area.area}エリア',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                // シェアボタン
                GestureDetector(
                  onTap: () => _share(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scene.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ios_share_rounded,
                            size: 13, color: scene.color),
                        const SizedBox(width: 3),
                        Text(
                          'シェア',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scene.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // コピー・理由
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // キャッチコピー
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: scene.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      area.copy,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scene.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 理由
                Text(
                  area.reason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          // タグ
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: area.tags
                  .map((tag) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.divider, width: 1),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // このエリアで探すボタン
          if (onStartSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    onStartSearch!();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: scene.color.withValues(alpha: 0.08),
                    foregroundColor: scene.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'このエリアで探す',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scene.color,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}
