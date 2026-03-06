import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Center(
                  child: Text(restaurant.emoji, style: const TextStyle(fontSize: 80)),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                restaurant.ratingStr,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Text(
                            '${restaurant.reviewCount}件のレビュー',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.description,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: restaurant.tags.map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Info card
                  _InfoCard(restaurant: restaurant),
                  const SizedBox(height: 20),
                  // Badges
                  Row(
                    children: [
                      if (restaurant.isFemalePopular)
                        _Badge(
                          icon: Icons.favorite_rounded,
                          label: '女性に人気',
                          color: AppColors.primary,
                        ),
                      if (restaurant.isFemalePopular && restaurant.hasPrivateRoom)
                        const SizedBox(width: 12),
                      if (restaurant.hasPrivateRoom)
                        _Badge(
                          icon: Icons.meeting_room_rounded,
                          label: '個室あり',
                          color: const Color(0xFF7C3AED),
                        ),
                      if (restaurant.isReservable)
                        _Badge(
                          icon: Icons.calendar_today_rounded,
                          label: '予約可',
                          color: const Color(0xFF10B981),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Reserve button
                  if (restaurant.isReservable)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${restaurant.name}の予約画面へ移動します（デモ）'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '予約する',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.restaurant_menu_rounded,
            label: 'カテゴリ',
            value: restaurant.category,
          ),
          const Divider(height: 16),
          _InfoRow(
            icon: Icons.attach_money_rounded,
            label: '目安予算',
            value: restaurant.priceStr,
          ),
          const Divider(height: 16),
          _InfoRow(
            icon: Icons.directions_walk_rounded,
            label: '駅からの距離',
            value: '徒歩${restaurant.distanceMinutes}分',
          ),
          const Divider(height: 16),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: '営業時間',
            value: restaurant.openHours,
          ),
          const Divider(height: 16),
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: '住所',
            value: restaurant.address,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
