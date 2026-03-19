import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/restaurant.dart';
import '../models/visit_log.dart';
import '../providers/visit_log_provider.dart';
import '../services/hotpepper_service.dart';
import '../theme/app_theme.dart';

/// Google Maps ルート検索 URL を構築する。
/// destination_place_id は不要なため含めない。
String buildGoogleMapsRouteUrl(double lat, double lng) =>
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';

/// 予約 URL として許可するかを返す。https:// スキームのみ許可。
bool isReservationUrlAllowed(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https';
}

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final photos = restaurant.imageUrls.isNotEmpty
        ? restaurant.imageUrls
        : (restaurant.imageUrl != null ? [restaurant.imageUrl!] : <String>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── ヒーロー写真エリア ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: photos.isEmpty ? 160 : 240,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isEmpty
                  ? _heroFallback(restaurant)
                  : _PhotoCarousel(photos: photos),
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
                      if (restaurant.rating > 0)
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
                            if (restaurant.reviewCount > 0)
                              Text(
                                '${restaurant.reviewCount}件のレビュー',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (restaurant.description.isNotEmpty)
                    Text(
                      restaurant.description,
                      style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
                    ),
                  const SizedBox(height: 16),
                  // Tags
                  if (restaurant.tags.isNotEmpty)
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
                  // Map
                  if (restaurant.lat != null && restaurant.lng != null)
                    _MapCard(restaurant: restaurant),
                  if (restaurant.lat != null && restaurant.lng != null)
                    const SizedBox(height: 20),
                  // Badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
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
                      if (restaurant.freeDrink)
                        _Badge(
                          icon: Icons.local_bar_rounded,
                          label: '飲み放題',
                          color: const Color(0xFFEF4444),
                        ),
                      if (restaurant.freeFood)
                        _Badge(
                          icon: Icons.restaurant_rounded,
                          label: '食べ放題',
                          color: const Color(0xFFF59E0B),
                        ),
                      if (restaurant.wifi)
                        _Badge(
                          icon: Icons.wifi_rounded,
                          label: 'Wi-Fi',
                          color: const Color(0xFF3B82F6),
                        ),
                      if (restaurant.nonSmoking)
                        _Badge(
                          icon: Icons.smoke_free_rounded,
                          label: '禁煙',
                          color: Colors.grey.shade600,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ルート検索ボタン
                  if (restaurant.lat != null && restaurant.lng != null)
                    _RouteButton(restaurant: restaurant),
                  const SizedBox(height: 12),
                  // 予約ボタン
                  if (restaurant.isReservable)
                    _ReserveButton(restaurant: restaurant),
                  const SizedBox(height: 12),
                  _VisitLogButton(restaurant: restaurant),
                  const SizedBox(height: 12),
                  _NearbySearchButton(restaurant: restaurant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 写真カルーセル ─────────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});
  final List<String> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => Image.network(
            widget.photos[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, Color(0xFF7C3AED)],
                ),
              ),
              child: const Center(
                child: Icon(Icons.restaurant, size: 48, color: Colors.white70),
              ),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photos.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
        if (widget.photos.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_page + 1} / ${widget.photos.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _heroFallback(Restaurant r) => Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.getCategoryBg(r.category), AppColors.getCategoryBg(r.category).withValues(alpha: 0.65)],
    ),
  ),
  child: const Center(child: Icon(Icons.restaurant, size: 64, color: Colors.white70)),
);

// ─── ルート検索ボタン ─────────────────────────────────────────────────────────

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.restaurant});
  final Restaurant restaurant;

  Future<void> _openRoute() async {
    final uri = Uri.parse(buildGoogleMapsRouteUrl(restaurant.lat!, restaurant.lng!));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Googleマップでルート検索',
      child: SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _openRoute,
        icon: const Icon(Icons.directions_walk_rounded, size: 18),
        label: const Text(
          'Google マップでルート検索',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      ),
    );
  }
}

// ─── 予約ボタン ───────────────────────────────────────────────────────────────

class _ReserveButton extends StatelessWidget {
  const _ReserveButton({required this.restaurant});
  final Restaurant restaurant;

  Future<void> _reserve(BuildContext context) async {
    HapticFeedback.mediumImpact();
    if (restaurant.hotpepperUrl != null) {
      final url = restaurant.hotpepperUrl!;
      if (isReservationUrlAllowed(url)) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${restaurant.name}の予約画面へ移動します（デモ）'),
          backgroundColor: AppColors.primary,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '予約する',
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => _reserve(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          child: const Text('予約する',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── 地図 ─────────────────────────────────────────────────────────────────────

class _MapCard extends StatelessWidget {
  const _MapCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(restaurant.lat!, restaurant.lng!);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(initialCenter: pos, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'jp.mannaka.mannaka',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pos,
                  width: 48,
                  height: 48,
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                          'https://maps.google.com/?q=${restaurant.lat},${restaurant.lng}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEF4444), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(Icons.restaurant_rounded, size: 22, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 情報カード ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    void addRow(IconData icon, String label, String value) {
      if (value.isNotEmpty) {
        if (rows.isNotEmpty) {
          rows.add(const SizedBox(height: 8));
        }
        rows.add(_InfoRow(icon: icon, label: label, value: value));
      }
    }

    addRow(Icons.restaurant_menu_rounded, 'カテゴリ', restaurant.category);
    addRow(Icons.attach_money_rounded, '目安予算', restaurant.priceLabel.isNotEmpty ? restaurant.priceLabel : restaurant.priceStr);
    if (restaurant.accessInfo.isNotEmpty) {
      addRow(Icons.directions_walk_rounded, 'アクセス', restaurant.accessInfo);
    } else if (restaurant.distanceMinutes > 0) {
      addRow(Icons.directions_walk_rounded, '駅からの距離', '徒歩${restaurant.distanceMinutes}分');
    }
    addRow(Icons.access_time_rounded, '営業時間', restaurant.openHours);
    addRow(Icons.block_rounded, '定休日', restaurant.closeDay);
    addRow(Icons.location_on_rounded, '住所', restaurant.address);

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
      child: Column(children: rows),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
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

// ─── エリア周辺探しボタン ──────────────────────────────────────────────────────

class _NearbySearchButton extends StatefulWidget {
  const _NearbySearchButton({required this.restaurant});
  final Restaurant restaurant;

  @override
  State<_NearbySearchButton> createState() => _NearbySearchButtonState();
}

class _NearbySearchButtonState extends State<_NearbySearchButton> {
  bool _loading = false;

  Future<void> _search() async {
    final lat = widget.restaurant.lat;
    final lng = widget.restaurant.lng;
    if (lat == null || lng == null) return;

    setState(() => _loading = true);
    final apiKey = ApiConfig.hotpepperApiKey;
    List<Restaurant> results = [];
    try {
      if (apiKey.isNotEmpty) {
        results = await HotpepperService.searchNearCentroid(
          apiKey: apiKey,
          lat: lat,
          lng: lng,
          range: 2,
          count: 20,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NearbyResultsSheet(
        results: results,
        restaurantName: widget.restaurant.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.restaurant.lat != null;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: hasLocation && !_loading ? _search : null,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.search_rounded, size: 18),
        label: Text(
          hasLocation ? 'このエリアで他のお店を探す' : '位置情報が取得できません',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: hasLocation
                ? AppColors.primary
                : Colors.grey.shade300,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _NearbyResultsSheet extends StatelessWidget {
  const _NearbyResultsSheet({
    required this.results,
    required this.restaurantName,
  });
  final List<Restaurant> results;
  final String restaurantName;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ハンドル
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$restaurantName 周辺のお店',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${results.length}件',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'お店が見つかりませんでした',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final r = results[i];
                    return InkWell(
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => RestaurantDetailScreen(restaurant: r),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.getCategoryBg(r.category),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          r.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.getCategoryColor(r.category),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        r.priceStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (r.rating > 0) ...[
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      size: 14,
                                      color: Colors.amber.shade400),
                                  const SizedBox(width: 2),
                                  Text(
                                    r.ratingStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                size: 20, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 訪問記録ボタン ────────────────────────────────────────────────────────────

class _VisitLogButton extends ConsumerStatefulWidget {
  const _VisitLogButton({required this.restaurant});
  final Restaurant restaurant;

  @override
  ConsumerState<_VisitLogButton> createState() => _VisitLogButtonState();
}

class _VisitLogButtonState extends ConsumerState<_VisitLogButton> {
  Future<void> _showLogDialog() async {
    int selectedRating = 4;
    final memoCtrl = TextEditingController();
    bool? result;
    String memoText = '';
    try {
    result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('訪問を記録', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.restaurant.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              const Text('評価', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setS(() => selectedRating = i + 1),
                  child: Icon(
                    i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber.shade400,
                    size: 32,
                  ),
                )),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: memoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('記録する'),
            ),
          ],
        ),
      ),
    );
    memoText = memoCtrl.text;
    } finally {
      memoCtrl.dispose();
    }

    if (result == true && mounted) {
      final log = VisitLog(
        id: '${widget.restaurant.id}_${DateTime.now().millisecondsSinceEpoch}',
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        category: widget.restaurant.category,
        emoji: widget.restaurant.emoji,
        visitedAt: DateTime.now(),
        userRating: selectedRating,
        memo: memoText,
        imageUrl: widget.restaurant.imageUrl,
        address: widget.restaurant.address,
        hotpepperUrl: widget.restaurant.hotpepperUrl,
      );
      ref.read(visitLogProvider.notifier).add(log);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('訪問を記録しました！'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '訪問を記録',
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _showLogDialog,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: const Text('行った！記録する', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF10B981),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
