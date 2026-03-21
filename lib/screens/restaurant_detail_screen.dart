import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../data/station_data.dart';
import '../models/reserved_restaurant.dart';
import '../models/restaurant.dart';
import '../models/visited_restaurant.dart';
import '../providers/reserved_restaurants_provider.dart';
import '../providers/search_provider.dart';
import '../providers/visited_restaurants_provider.dart';
import '../services/hotpepper_service.dart';
import '../theme/app_theme.dart';

/// Google Maps ルート検索 URL を構築する。
String buildGoogleMapsRouteUrl(double lat, double lng) =>
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';

/// 予約 URL として許可するかを返す。https:// スキームのみ許可。
bool isReservationUrlAllowed(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https';
}

/// mannaka:// ディープリンクを生成する。
/// 受け取った側がアプリをインストール済みであればお店の詳細画面に直接遷移する。
String _buildDeepLink(Restaurant r, String station) {
  final params = <String, String>{
    if (r.id.isNotEmpty) 'id': r.id,
    'name': r.name,
    if (r.lat != null) 'lat': r.lat!.toStringAsFixed(6),
    if (r.lng != null) 'lng': r.lng!.toStringAsFixed(6),
    if (r.address.isNotEmpty) 'address': r.address,
    if (r.category.isNotEmpty) 'category': r.category,
    if (r.hotpepperUrl != null) 'url': r.hotpepperUrl!,
    if (r.openHours.isNotEmpty) 'hours': r.openHours,
    if (r.accessInfo.isNotEmpty) 'access': r.accessInfo,
    if (r.stationName.isNotEmpty) 'station': r.stationName,
    if (station.isNotEmpty) 'station': station,
    if (r.closeDay.isNotEmpty) 'closeDay': r.closeDay,
    if (r.priceLabel.isNotEmpty) 'price': r.priceLabel,
    if (r.rating > 0) 'rating': r.rating.toStringAsFixed(1),
  };
  final query = params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'mannaka://restaurant?$query';
}

/// レストランの緯度経度から最寄り kStation 名を取得（シェア用）
String _nearestStationName(double lat, double lng) {
  double best = double.infinity;
  int bestIdx = 0;
  for (int i = 0; i < kStationLatLng.length; i++) {
    final (sLat, sLng) = kStationLatLng[i];
    final d = (sLat - lat) * (sLat - lat) + (sLng - lng) * (sLng - lng);
    if (d < best) {
      best = d;
      bestIdx = i;
    }
  }
  return kStations[bestIdx];
}

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen>
    with WidgetsBindingObserver {
  /// Hotpepper を開いた後にアプリへ戻ってきたら LINE 共有シートを出す
  bool _waitingForReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForReturn) {
      _waitingForReturn = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLineShare();
      });
    }
  }

  void _onReservePressed() async {
    HapticFeedback.mediumImpact();
    final r = widget.restaurant;
    if (r.hotpepperUrl != null && isReservationUrlAllowed(r.hotpepperUrl!)) {
      _waitingForReturn = true;
      await launchUrl(Uri.parse(r.hotpepperUrl!),
          mode: LaunchMode.externalApplication);
    } else {
      // デモ: URLがない場合は直接共有シートを出す
      _showLineShare();
    }
  }

  void _showLineShare() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineShareSheet(
        restaurant: widget.restaurant,
        onShared: _onShared,
      ),
    );
  }

  void _onShared(ReservedRestaurant entry) {
    ref.read(reservedRestaurantsProvider.notifier).add(entry);

    final groupNames = ref
        .read(searchProvider)
        .participants
        .map((p) => p.name)
        .toList();
    final visited = VisitedRestaurant(
      id: entry.id,
      restaurantName: entry.restaurantName,
      category: entry.category,
      visitedAt: entry.reservedAt,
      groupNames: groupNames,
      address: entry.address,
      nearestStation: entry.nearestStation,
      hotpepperUrl: entry.hotpepperUrl,
      imageUrl: entry.imageUrl,
      lat: entry.lat,
      lng: entry.lng,
    );
    ref.read(visitedRestaurantsProvider.notifier).add(visited);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('予約済みに保存しました'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final photos = r.imageUrls.isNotEmpty
        ? r.imageUrls
        : (r.imageUrl != null ? [r.imageUrl!] : <String>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── ヒーロー写真エリア ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: photos.isEmpty ? 160 : 240,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isEmpty
                  ? _heroFallback(r)
                  : _PhotoCarousel(photos: photos),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名前 + 評価
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(r.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                      ),
                      if (r.rating > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.amber.shade400, size: 20),
                              const SizedBox(width: 4),
                              Text(r.ratingStr,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                            ]),
                            if (r.reviewCount > 0)
                              Text('${r.reviewCount}件のレビュー',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (r.description.isNotEmpty)
                    Text(r.description,
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.5)),
                  const SizedBox(height: 16),
                  if (r.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: r.tags
                          .map((t) => Chip(
                                label: Text(t,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.08),
                                labelStyle: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                                side: BorderSide.none,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  _InfoCard(restaurant: r),
                  const SizedBox(height: 20),
                  if (r.lat != null && r.lng != null)
                    _GMapCard(restaurant: r),
                  if (r.lat != null && r.lng != null)
                    const SizedBox(height: 20),
                  // バッジ
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (r.hasPrivateRoom)
                        _Badge(
                            icon: Icons.meeting_room_rounded,
                            label: '個室あり',
                            color: const Color(0xFF7C3AED)),
                      if (r.isReservable)
                        _Badge(
                            icon: Icons.calendar_today_rounded,
                            label: '予約可',
                            color: const Color(0xFF10B981)),
                      if (r.freeDrink)
                        _Badge(
                            icon: Icons.local_bar_rounded,
                            label: '飲み放題',
                            color: const Color(0xFFEF4444)),
                      if (r.freeFood)
                        _Badge(
                            icon: Icons.restaurant_rounded,
                            label: '食べ放題',
                            color: const Color(0xFFF59E0B)),
                      if (r.wifi)
                        _Badge(
                            icon: Icons.wifi_rounded,
                            label: 'Wi-Fi',
                            color: const Color(0xFF3B82F6)),
                      if (r.nonSmoking)
                        _Badge(
                            icon: Icons.smoke_free_rounded,
                            label: '禁煙',
                            color: Colors.grey.shade600),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (r.lat != null && r.lng != null)
                    _RouteButton(restaurant: r),
                  const SizedBox(height: 12),
                  if (r.isReservable) ...[
                    _ReserveButton(onPressed: _onReservePressed),
                    const SizedBox(height: 10),
                    _LineShareButton(onPressed: _showLineShare),
                    const SizedBox(height: 12),
                  ],
                  _NearbySearchButton(restaurant: r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 写真カルーセル ────────────────────────────────────────────────────────────

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
              children: List.generate(
                widget.photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        if (widget.photos.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_page + 1} / ${widget.photos.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
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
          colors: [
            AppColors.getCategoryBg(r.category),
            AppColors.getCategoryBg(r.category).withValues(alpha: 0.65)
          ],
        ),
      ),
      child: const Center(
          child: Icon(Icons.restaurant, size: 64, color: Colors.white70)),
    );

// ─── ルート検索ボタン ─────────────────────────────────────────────────────────

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(
              buildGoogleMapsRouteUrl(restaurant.lat!, restaurant.lng!));
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.directions_walk_rounded, size: 18),
        label: const Text('Google マップでルート検索',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── 予約ボタン ───────────────────────────────────────────────────────────────

class _ReserveButton extends StatelessWidget {
  const _ReserveButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('予約する',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─── LINEシェアボタン（単体） ────────────────────────────────────────────────

class _LineShareButton extends StatelessWidget {
  const _LineShareButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF06C755),
          side: const BorderSide(color: Color(0xFF06C755), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _MiniLinePainter()),
            ),
            const SizedBox(width: 8),
            const Text('LINEで予約情報をシェア',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── LINE共有ボトムシート ─────────────────────────────────────────────────────

class _LineShareSheet extends StatelessWidget {
  const _LineShareSheet({
    required this.restaurant,
    required this.onShared,
  });
  final Restaurant restaurant;
  final void Function(ReservedRestaurant) onShared;

  Future<void> _shareLine(BuildContext context) async {
    final r = restaurant;
    final station =
        r.lat != null && r.lng != null ? _nearestStationName(r.lat!, r.lng!) : '';

    // mannaka:// ディープリンク（アプリインストール済みの人はここからお店詳細へ直接遷移）
    final deepLink = _buildDeepLink(r, station);

    // Googleマップ目的地リンク（受け取った側が自分の現在地からルート確認）
    // 送信者の位置情報は含まない
    final mapsUrl = r.lat != null && r.lng != null
        ? 'https://maps.google.com/maps?daddr=${r.lat},${r.lng}'
        : '';

    final lines = <String>[
      '【集合場所が決まりました！】',
      '🍽 ${r.name}',
      if (r.address.isNotEmpty) '📍 ${r.address}',
      if (station.isNotEmpty) '🚉 最寄り駅: $station駅',
      if (mapsUrl.isNotEmpty) '\n📍 道順はこちら\n$mapsUrl',
      '\n📲 Aimaアプリで開く\n$deepLink',
      '\n「Aima」で見つけたよ！',
    ];
    final text = lines.join('\n');
    final encoded = Uri.encodeComponent(text);
    final lineUri = Uri.parse('https://line.me/R/share?text=$encoded');

    // 予約済みとして保存
    final entry = _buildEntry(r, station);
    onShared(entry);

    if (await canLaunchUrl(lineUri)) {
      await launchUrl(lineUri, mode: LaunchMode.externalApplication);
    }

    if (context.mounted) Navigator.pop(context);
  }

  void _saveOnly(BuildContext context) {
    final r = restaurant;
    final station =
        r.lat != null && r.lng != null ? _nearestStationName(r.lat!, r.lng!) : '';
    onShared(_buildEntry(r, station));
    Navigator.pop(context);
  }

  ReservedRestaurant _buildEntry(dynamic r, String station) {
    return ReservedRestaurant(
      id: '${r.id}_${DateTime.now().millisecondsSinceEpoch}',
      restaurantName: r.name,
      category: r.category,
      reservedAt: DateTime.now(),
      address: r.address,
      hotpepperUrl: r.hotpepperUrl,
      imageUrl: r.imageUrl,
      lat: r.lat,
      lng: r.lng,
      nearestStation: station,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final station = r.lat != null && r.lng != null
        ? _nearestStationName(r.lat!, r.lng!)
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(painter: _MiniLinePainter()),
              ),
              const SizedBox(width: 10),
              const Text('LINEで集合場所をシェア',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text('友だちに送って、みんなで道順を確認できます',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          // プレビュー
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('【集合場所が決まりました！】',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('🍽 ${r.name}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (r.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('📍 ${r.address}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                ],
                if (station.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('🚉 最寄り駅: $station駅',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 6),
                Text('📍 道順はこちら（Googleマップ）',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.blue.shade600)),
                const SizedBox(height: 2),
                Text('📲 Aimaアプリで開く（インストール済みの方）',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text('「Aima」で見つけたよ！',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '※ 受け取った方が自分の現在地からGoogleマップで道順を確認できます。\n'
            '※ Aimaアプリをお持ちの方はアプリ内でお店の詳細を確認できます。\n'
            '　 あなたの現在地は共有されません。',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _shareLine(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06C755),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(
                        painter: _MiniLinePainter(iconColor: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  const Text('LINEで送る',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _saveOnly(context),
              child: const Text('LINEで送らず記録だけする',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// LINE吹き出しアイコン（ミニ版）
class _MiniLinePainter extends CustomPainter {
  const _MiniLinePainter({this.iconColor});
  final Color? iconColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (iconColor == null) {
      // 緑の丸背景
      final bgPaint = Paint()..color = const Color(0xFF06C755);
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width / 2, bgPaint);
    }
    final paint = Paint()..color = iconColor ?? Colors.white;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.20,
          size.width * 0.64, size.height * 0.44),
      const Radius.circular(3),
    );
    canvas.drawRRect(bubbleRect, paint);
    final path = Path();
    final tx = size.width * 0.34;
    final ty = size.height * 0.63;
    path.moveTo(tx, ty);
    path.lineTo(tx - size.width * 0.10, ty + size.height * 0.17);
    path.lineTo(tx + size.width * 0.14, ty);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Google Maps 埋め込み ─────────────────────────────────────────────────────

class _GMapCard extends StatefulWidget {
  const _GMapCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  State<_GMapCard> createState() => _GMapCardState();
}

class _GMapCardState extends State<_GMapCard> {
  gmap.GoogleMapController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _openGoogleMaps() async {
    final r = widget.restaurant;
    final uri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(r.name)}&ll=${r.lat},${r.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = gmap.LatLng(widget.restaurant.lat!, widget.restaurant.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 180,
            child: gmap.GoogleMap(
              initialCameraPosition:
                  gmap.CameraPosition(target: pos, zoom: 16),
              onMapCreated: (ctrl) => _ctrl = ctrl,
              markers: {
                gmap.Marker(
                  markerId: const gmap.MarkerId('restaurant'),
                  position: pos,
                  infoWindow:
                      gmap.InfoWindow(title: widget.restaurant.name),
                ),
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: false,
              onTap: (_) => _openGoogleMaps(),
            ),
          ),
          // 「Googleマップで開く」オーバーレイボタン
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: _openGoogleMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 13, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text('Googleマップで開く',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 情報カード ───────────────────────────────────────────────────────────────

List<String> _formatOpenHours(String raw) {
  if (raw.isEmpty) return [];
  final parts = raw
      .split(RegExp(r'[/／\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.length > 1 ? parts : [raw.trim()];
}

String _formatCloseDay(String raw) =>
    raw.replaceAll('　', ' ').trim();

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          _buildRow(Icons.restaurant_menu_rounded, 'カテゴリ',
              restaurant.category),
          _buildRow(
              Icons.attach_money_rounded,
              '予算',
              restaurant.priceLabel.isNotEmpty
                  ? restaurant.priceLabel
                  : restaurant.priceStr),
          _buildAccessRow(),
          _buildHoursRow(),
          _buildCloseDayRow(),
          _buildRow(
              Icons.location_on_rounded, '住所', restaurant.address),
        ].whereType<Widget>().toList(),
      ),
    );
  }

  Widget? _buildRow(IconData icon, String label, String value) {
    if (value.isEmpty) return null;
    return _InfoRow(icon: icon, label: label, value: value);
  }

  Widget? _buildAccessRow() {
    if (restaurant.accessInfo.isNotEmpty) {
      return _InfoRow(
          icon: Icons.directions_walk_rounded,
          label: 'アクセス',
          value: restaurant.accessInfo);
    } else if (restaurant.distanceMinutes > 0) {
      return _InfoRow(
          icon: Icons.directions_walk_rounded,
          label: 'アクセス',
          value: '駅から徒歩${restaurant.distanceMinutes}分');
    }
    return null;
  }

  Widget? _buildHoursRow() {
    if (restaurant.openHours.isEmpty) return null;
    final slots = _formatOpenHours(restaurant.openHours);
    if (slots.length <= 1) {
      return _InfoRow(
          icon: Icons.access_time_rounded,
          label: '営業時間',
          value: slots.firstOrNull ?? restaurant.openHours);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text('営業時間',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: slots
                  .map((s) => Text(s,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCloseDayRow() {
    final day = _formatCloseDay(restaurant.closeDay);
    if (day.isEmpty) return null;
    if (day == '無休' || day == '年中無休') {
      return _InfoRow(
          icon: Icons.calendar_month_rounded,
          label: '定休日',
          value: '年中無休',
          valueColor: const Color(0xFF10B981));
    }
    return _InfoRow(
        icon: Icons.calendar_month_rounded,
        label: '定休日',
        value: day);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text(label,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(
      {required this.icon, required this.label, required this.color});
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
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── エリア周辺探しボタン ─────────────────────────────────────────────────────

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
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.search_rounded, size: 18),
        label: Text(
          hasLocation ? 'このエリアで他のお店を探す' : '位置情報が取得できません',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
            color: hasLocation ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _NearbyResultsSheet extends StatelessWidget {
  const _NearbyResultsSheet(
      {required this.results, required this.restaurantName});
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$restaurantName 周辺のお店',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('${results.length}件',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('お店が見つかりませんでした',
                      style: TextStyle(color: Colors.grey)),
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
                        nav.push(MaterialPageRoute(
                          builder: (_) =>
                              RestaurantDetailScreen(restaurant: r),
                        ));
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
                                  Text(r.name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.getCategoryBg(
                                              r.category),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          r.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.getCategoryColor(
                                                r.category),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(r.priceStr,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (r.rating > 0) ...[
                              const SizedBox(width: 8),
                              Row(children: [
                                Icon(Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber.shade400),
                                const SizedBox(width: 2),
                                Text(r.ratingStr,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ]),
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
