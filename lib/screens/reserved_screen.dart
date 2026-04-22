import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reserved_restaurant.dart';
import '../models/visited_restaurant.dart';
import '../providers/reserved_restaurants_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/manual_restaurant_add_sheet.dart';

class ReservedScreen extends ConsumerStatefulWidget {
  const ReservedScreen({super.key});

  @override
  ConsumerState<ReservedScreen> createState() => _ReservedScreenState();
}

class _ReservedScreenState extends ConsumerState<ReservedScreen> {
  @override
  Widget build(BuildContext context) {
    final reserved = ref.watch(reservedRestaurantsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('予約済み',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: reserved.isEmpty ? _empty() : _list(reserved),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showManualRestaurantAddSheet(context,
            initialTarget: AddTarget.reserved),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('お店を追加',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF06C755).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bookmark_rounded,
                size: 44, color: Color(0xFF06C755)),
          ),
          const SizedBox(height: 24),
          const Text('まだ予約したお店がないみたい',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('お店を決めたら、ここに残るよ',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _list(List<ReservedRestaurant> reserved) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reserved.length,
      itemBuilder: (ctx, i) {
        final entry = reserved[i];
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.red),
          ),
          onDismissed: (_) {
            HapticFeedback.lightImpact();
            ref.read(reservedRestaurantsProvider.notifier).remove(entry.id);
          },
          child: _ReservedCard(entry: entry),
        );
      },
    );
  }

}

class _ReservedCard extends ConsumerWidget {
  const _ReservedCard({required this.entry});
  final ReservedRestaurant entry;

  void _markAsVisited(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final visited = VisitedRestaurant(
      id: 'visited_${entry.id}',
      restaurantName: entry.restaurantName,
      category: entry.category,
      visitedAt: DateTime.now(),
      groupNames: entry.groupNames,
      address: entry.address,
      nearestStation: entry.nearestStation,
      hotpepperUrl: entry.hotpepperUrl,
      imageUrl: entry.imageUrl,
      lat: entry.lat,
      lng: entry.lng,
    );
    ref.read(visitedRestaurantsProvider.notifier).add(visited);
    ref.read(reservedRestaurantsProvider.notifier).remove(entry.id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('行ったお店に追加しました！'),
      backgroundColor: Color(0xFFFF6B81),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06C755).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('シェア済み ✓',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF06C755))),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.restaurantName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(entry.category,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Text(
                  _formatDate(entry.reservedAt),
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
            if (entry.groupNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.groupNames.join('、'),
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
            if (entry.nearestStation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.train_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${entry.nearestStation}駅',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
            if (entry.address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(entry.address,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (entry.lat != null && entry.lng != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                            'https://maps.google.com/maps?daddr=${entry.lat},${entry.lng}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.directions_rounded, size: 14),
                      label: const Text('道順',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A73E8),
                        side: const BorderSide(
                            color: Color(0xFF1A73E8), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                if (entry.lat != null &&
                    entry.lng != null &&
                    entry.hotpepperUrl != null)
                  const SizedBox(width: 8),
                if (entry.hotpepperUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                          Uri.parse(entry.hotpepperUrl!),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('予約ページ',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _markAsVisited(context, ref),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('決定！行った',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}
