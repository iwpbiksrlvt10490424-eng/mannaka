import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top image-like header
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _categoryColor(restaurant.category).withValues(alpha: 0.15),
                    _categoryColor(restaurant.category).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(restaurant.emoji,
                          style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _categoryColor(restaurant.category)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            restaurant.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _categoryColor(restaurant.category),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (restaurant.isFemalePopular)
                          _BadgeSmall(
                              label: '女性に人気', color: AppColors.primary),
                        if (restaurant.hasPrivateRoom)
                          _BadgeSmall(
                              label: '個室あり', color: AppColors.secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber.shade400, size: 15),
                          const SizedBox(width: 2),
                          Text(restaurant.ratingStr,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(
                            ' (${_fmt(restaurant.reviewCount)})',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.description,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _InfoPill(
                        icon: Icons.attach_money_rounded,
                        label: restaurant.priceStr,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      _InfoPill(
                        icon: Icons.directions_walk_rounded,
                        label: '徒歩${restaurant.distanceMinutes}分',
                        color: AppColors.primary,
                      ),
                      if (restaurant.isLunchAvailable) ...[
                        const SizedBox(width: 6),
                        _InfoPill(
                          icon: Icons.wb_sunny_outlined,
                          label: 'ランチ',
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    return switch (category) {
      '和食' => const Color(0xFFEF4444),
      '洋食' => const Color(0xFF3B82F6),
      'イタリアン' => const Color(0xFF10B981),
      '中華' => const Color(0xFFF59E0B),
      '居酒屋' => const Color(0xFF8B5CF6),
      'カフェ' => const Color(0xFFEC4899),
      '焼肉' => const Color(0xFFEF4444),
      'フレンチ' => const Color(0xFF6366F1),
      _ => AppColors.primary,
    };
  }

  String _fmt(int n) =>
      n >= 1000 ? '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}' : '$n';
}

class _BadgeSmall extends StatelessWidget {
  const _BadgeSmall({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
