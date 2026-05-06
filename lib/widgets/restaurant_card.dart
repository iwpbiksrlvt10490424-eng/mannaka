import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../theme/app_theme.dart';

/// 標準的なレストランカード（Retty/Tabelog スタイル）
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.scored,
    this.rank,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final ScoredRestaurant? scored;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final categoryBg = AppColors.getCategoryBg(restaurant.category);

    return Semantics(
      label: '${restaurant.name}、${restaurant.category}、${restaurant.priceStr}、徒歩${restaurant.distanceMinutes}分',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 写真エリア（80x80） ──────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: restaurant.imageUrl != null &&
                          restaurant.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: restaurant.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              _photoFallback(categoryBg),
                          errorWidget: (context, url, error) =>
                              _photoFallback(categoryBg),
                        )
                      : _photoFallback(categoryBg),
                ),
              ),
              const SizedBox(width: 12),

              // ─── テキスト情報 ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ランク表示（1〜3位のみ）
                    if (rank != null && rank! <= 3) ...[
                      Text(
                        '${rank!}位',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rank == 1
                              ? const Color(0xFFB8860B)
                              : rank == 2
                                  ? const Color(0xFF6B6B6B)
                                  : const Color(0xFF8B5E3C),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    // 店名
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 予約可否バッジ
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (restaurant.isReservable &&
                            restaurant.hotpepperUrl != null)
                          _badge('ホットペッパーで予約できます',
                              const Color(0xFFE67E22))
                        else if (restaurant.sourceApi == 'google_places')
                          _badge('Googleマップより（予約不可）',
                              const Color(0xFF4285F4))
                        else
                          _badge('要問合せ', Colors.grey.shade600),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // カテゴリ · 価格 · 距離
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${restaurant.category}  ·  ${restaurant.priceStr}  ·  徒歩${restaurant.distanceMinutes}分',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (restaurant.isOpenNow(DateTime.now())) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('営業中', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    // 評価（ある場合のみ）
                    if (restaurant.hasRating && restaurant.rating! > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: AppColors.star, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            restaurant.ratingStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (restaurant.reviewCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${restaurant.reviewCount}件',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    // 予約可・個室バッジ
                    if (restaurant.hasPrivateRoom || restaurant.isReservable) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (restaurant.isReservable) ...[
                            const Icon(Icons.event_available_rounded,
                                size: 12, color: AppColors.success),
                            const SizedBox(width: 2),
                            const Text(
                              '予約可',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.success),
                            ),
                            if (restaurant.hasPrivateRoom)
                              const SizedBox(width: 8),
                          ],
                          if (restaurant.hasPrivateRoom) ...[
                            const Icon(Icons.door_back_door_outlined,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            const Text(
                              '個室',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // 右矢印
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Widget _photoFallback(Color bg) {
  return Container(
    width: 80,
    height: 80,
    color: const Color(0xFFEEEEEE),
    child: Center(
      child: Text(
        'NO\nIMAGE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          height: 1.3,
        ),
      ),
    ),
  );
}
