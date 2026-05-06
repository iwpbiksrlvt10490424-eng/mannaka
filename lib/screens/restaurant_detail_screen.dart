import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../data/station_data.dart';
import '../models/reserved_restaurant.dart';
import '../models/restaurant.dart';
import '../providers/reserved_restaurants_provider.dart';
import '../providers/search_provider.dart';
import '../services/hotpepper_service.dart';
import '../theme/app_theme.dart';
import '../utils/photo_ref.dart';
import '../utils/share_utils.dart';

/// Google Maps ルート検索 URL を構築する。
String buildGoogleMapsRouteUrl(double lat, double lng) =>
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking';

/// 予約 URL として許可するかを返す。https:// スキームのみ許可。
bool isReservationUrlAllowed(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && uri.scheme == 'https';
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
  const RestaurantDetailScreen({super.key, required this.restaurant, this.groupNames});
  final Restaurant restaurant;
  final List<String>? groupNames;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen>
    with WidgetsBindingObserver {
  /// Hotpepper を開いた後にアプリへ戻ってきたら LINE 共有シートを出す
  bool _waitingForReturn = false;

  /// Foursquare /photos エンドポイントから追加取得した写真URL
  List<String> _extraPhotos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchFoursquarePhotos();
  }

  Future<void> _fetchFoursquarePhotos() async {
    final r = widget.restaurant;

    if (r.id.startsWith('fsq_')) {
      // Foursquareのお店: /photos エンドポイントで追加取得
      await _fetchFsqPhotosByFsqId(r.id.replaceFirst('fsq_', ''));
    } else {
      // Hotpepperのお店: ①Foursquareクロス検索 → ②Google Places Photos を並列実行
      await Future.wait([
        _fetchPhotosByFoursquareCross(),
        _fetchGooglePlacesPhotos(),
      ]);
    }
  }

  /// ① Foursquare テキスト検索でお店を特定し写真を取得
  Future<void> _fetchPhotosByFoursquareCross() async {
    final r = widget.restaurant;
    final fsqKey = ApiConfig.foursquareApiKey;
    if (fsqKey.isEmpty || r.lat == null || r.lng == null) return;
    try {
      // テキスト検索でFoursquare venue IDを取得
      final searchUri = Uri.parse('https://api.foursquare.com/v3/places/search').replace(
        queryParameters: {
          'query': r.name,
          'll': '${r.lat},${r.lng}',
          'limit': '1',
          'fields': 'fsq_id',
        },
      );
      final searchRes = await http.get(searchUri, headers: {
        'Authorization': fsqKey,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));
      if (searchRes.statusCode != 200) return;
      final results = (jsonDecode(utf8.decode(searchRes.bodyBytes))['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) return;
      final fsqId = (results.first as Map<String, dynamic>)['fsq_id'] as String?;
      if (fsqId == null) return;
      await _fetchFsqPhotosByFsqId(fsqId);
    } catch (_) {}
  }

  /// Foursquare /photos エンドポイントで写真取得（共通）
  Future<void> _fetchFsqPhotosByFsqId(String fsqId) async {
    final r = widget.restaurant;
    final apiKey = ApiConfig.foursquareApiKey;
    if (apiKey.isEmpty) return;
    try {
      final uri = Uri.parse(
          'https://api.foursquare.com/v3/places/$fsqId/photos?limit=10');
      final response = await http.get(uri, headers: {
        'Authorization': apiKey,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      final existingUrls = {...r.imageUrls, if (r.imageUrl != null) r.imageUrl!};
      final fetched = <String>[];
      for (final item in data) {
        final photo = item as Map<String, dynamic>;
        final prefix = photo['prefix'] as String?;
        final suffix = photo['suffix'] as String?;
        if (prefix != null && suffix != null) {
          final url = '${prefix}600x600$suffix';
          if (!existingUrls.contains(url) && !_extraPhotos.contains(url)) fetched.add(url);
        }
      }
      if (fetched.isNotEmpty && mounted) {
        setState(() => _extraPhotos = [..._extraPhotos, ...fetched]);
      }
    } catch (_) {}
  }

  /// ② Google Places Photos API でお店の写真を取得
  Future<void> _fetchGooglePlacesPhotos() async {
    final r = widget.restaurant;
    final gKey = ApiConfig.googleMapsApiKey;
    if (gKey.isEmpty || r.lat == null || r.lng == null) return;
    try {
      // Text Search でplace_idを取得
      final searchUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/findplacefromtext/json').replace(
        queryParameters: {
          'input': r.name,
          'inputtype': 'textquery',
          'locationbias': 'point:${r.lat},${r.lng}',
          'fields': 'place_id',
          'language': 'ja',
          'key': gKey,
        },
      );
      final searchRes = await http.get(searchUri).timeout(const Duration(seconds: 5));
      if (searchRes.statusCode != 200) return;
      final candidates = (jsonDecode(utf8.decode(searchRes.bodyBytes))['candidates'] as List<dynamic>?) ?? [];
      if (candidates.isEmpty) return;
      final placeId = (candidates.first as Map<String, dynamic>)['place_id'] as String?;
      if (placeId == null) return;

      // Place Details で photos を取得
      final detailUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'fields': 'photos',
          'language': 'ja',
          'key': gKey,
        },
      );
      final detailRes = await http.get(detailUri).timeout(const Duration(seconds: 5));
      if (detailRes.statusCode != 200) return;
      final photoRefs = (jsonDecode(utf8.decode(detailRes.bodyBytes))['result']?['photos'] as List<dynamic>?) ?? [];

      final fetched = <String>[];
      for (final p in photoRefs.take(8)) {
        final ref = (p as Map<String, dynamic>)['photo_reference'] as String?;
        if (ref == null) continue;
        final url = 'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=800&photo_reference=$ref&key=$gKey';
        if (!_extraPhotos.contains(url)) fetched.add(url);
      }
      if (fetched.isNotEmpty && mounted) {
        setState(() => _extraPhotos = [..._extraPhotos, ...fetched]);
      }
    } catch (_) {}
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
        if (mounted) _showReservationConfirmDialog();
      });
    }
  }

  void _showReservationConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('予約できましたか？',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          '予約が完了したらLINEでみんなに\n集合場所を教えましょう。',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('戻る', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final r = widget.restaurant;
              final station = r.lat != null && r.lng != null
                  ? _nearestStationName(r.lat!, r.lng!)
                  : '';
              final entry = ReservedRestaurant(
                id: '${r.id}_${DateTime.now().millisecondsSinceEpoch}',
                restaurantName: r.name,
                category: r.category,
                reservedAt: DateTime.now(),
                address: r.address,
                hotpepperUrl: r.hotpepperUrl,
                imageUrl: r.imageUrl,
                photoRefs: PhotoRef.listToRefs(r.imageUrls),
                lat: r.lat,
                lng: r.lng,
                nearestStation: station,
              );
              _onShared(entry);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showLineShare(alreadySaved: true);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('予約した！LINEでシェア',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _onReservePressed() async {
    HapticFeedback.mediumImpact();
    final r = widget.restaurant;
    if (r.hotpepperUrl != null && isReservationUrlAllowed(r.hotpepperUrl!)) {
      _waitingForReturn = true;
      await launchUrl(Uri.parse(r.hotpepperUrl!),
          mode: LaunchMode.externalApplication);
      if (!mounted) return;
    } else {
      // デモ: URLがない場合は直接共有シートを出す
      _showLineShare();
    }
  }

  void _showLineShare({bool alreadySaved = false}) {
    if (!mounted) return;
    // 予約フローの「集合日時」と「チーム」を SearchState から取り出す。
    // 履歴経由でこの画面を開いた場合は widget.groupNames に名前リストが入る。
    final state = ref.read(searchProvider);
    final groupNames = widget.groupNames ??
        state.participants.map((p) => p.name).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineShareSheet(
        restaurant: widget.restaurant,
        onShared: alreadySaved ? null : _onShared,
        meetingDate: state.selectedDate,
        meetingTime: state.selectedMeetingTime,
        groupNames: groupNames,
      ),
    );
  }

  void _onShared(ReservedRestaurant entry) {
    // 参加者名をグループ名として一緒に保存（履歴から開いた場合は渡されたgroupNamesを使う）
    final groupNames = widget.groupNames ??
        ref
            .read(searchProvider)
            .participants
            .map((p) => p.name)
            .toList();
    final entryWithGroup = ReservedRestaurant(
      id: entry.id,
      restaurantName: entry.restaurantName,
      category: entry.category,
      reservedAt: entry.reservedAt,
      address: entry.address,
      hotpepperUrl: entry.hotpepperUrl,
      imageUrl: entry.imageUrl,
      photoRefs: entry.photoRefs,
      lat: entry.lat,
      lng: entry.lng,
      nearestStation: entry.nearestStation,
      groupNames: groupNames,
    );
    ref.read(reservedRestaurantsProvider.notifier).add(entryWithGroup);
    // 「行ったお店」への自動追加は廃止。
    // 予定画面の「決定！行った」ボタンで明示的に追加する。
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('予定に保存しました'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final basePhotos = r.imageUrls.isNotEmpty
        ? r.imageUrls
        : (r.imageUrl != null ? [r.imageUrl!] : <String>[]);
    // 5 枚を上限にする（仕様）。基本写真を優先し、足りない分だけ詳細画面で拡張取得した写真で埋める。
    final merged = <String>[
      ...basePhotos,
      ..._extraPhotos.where((u) => !basePhotos.contains(u)),
    ];
    final photos = merged.length > 5 ? merged.sublist(0, 5) : merged;

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
                        child: Text(
                          r.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (r.hasRating && r.rating! > 0)
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
                            label: 'ここから予約可能',
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
                  // ─── アクション領域（Primary → Secondary → Tertiary 階層） ───
                  // Primary: 予約ページへ進む（外部サイト遷移、ユーザーが最も期待する次の一手）
                  if (r.isReservable) ...[
                    _ReserveButton(onPressed: _onReservePressed),
                    const SizedBox(height: 14),
                  ],
                  // Secondary: 共有・ルートを横並び（同等の補助動線）
                  Row(
                    children: [
                      Expanded(
                        child: _LineShareButton(onPressed: _showLineShare),
                      ),
                      if (r.lat != null && r.lng != null) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _RouteButton(restaurant: r)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tertiary: テキストリンクで控えめに（補助の補助）
                  _NearbyTextLink(restaurant: r),
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
  bool _initialPrecacheDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialPrecacheDone && widget.photos.length > 1) {
      _initialPrecacheDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _precacheNeighbors(0);
      });
    }
  }

  /// 現在ページの前後を裏で先読み。スワイプ時のチラつきを抑える。
  void _precacheNeighbors(int center) {
    final ctx = context;
    for (final i in [center - 1, center + 1, center + 2]) {
      if (i < 0 || i >= widget.photos.length) continue;
      precacheImage(
        CachedNetworkImageProvider(widget.photos[i]),
        ctx,
      ).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) {
            setState(() => _page = i);
            _precacheNeighbors(i);
          },
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.photos[i],
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(color: Colors.grey.shade100),
            ),
            errorWidget: (context, url, error) => Container(
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
      decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'NO IMAGE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );

// ─── ルート検索ボタン ─────────────────────────────────────────────────────────

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Googleマップでルート検索',
      child: SizedBox(
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
        label: const Text('ルートを見る',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8),
          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
    // ボタン文言: 「予約する」だとアプリ内予約と誤解される可能性があるため
    // 外部サイト（Hotpepper）に遷移する実態を文言で明示する。
    return Tooltip(
      message: '予約ページへ進む',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('予約ページへ進む',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '外部の予約サイトを開きます',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
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
            const Text('LINE で共有',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    this.meetingDate,
    this.meetingTime,
    this.groupNames = const [],
  });
  final Restaurant restaurant;
  final void Function(ReservedRestaurant)? onShared;
  final DateTime? meetingDate;
  final TimeOfDay? meetingTime;
  final List<String> groupNames;

  Future<void> _shareLine(BuildContext context) async {
    final r = restaurant;
    final station =
        r.lat != null && r.lng != null ? _nearestStationName(r.lat!, r.lng!) : '';

    // 「Aimachiで予約しました」+ 集合日時 + チーム + 地図リンクを 1 本のテキストに。
    // 送信者の生 GPS は含めない（プライバシー）— 店舗座標のみ。
    final text = ShareUtils.buildReservationLineText(
      restaurantName: r.name,
      category: r.category,
      stationName: station,
      walkMinutes: r.distanceMinutes,
      lat: r.lat,
      lng: r.lng,
      meetingDate: meetingDate,
      meetingTime: meetingTime,
      groupNames: groupNames,
    );
    final ok = await ShareUtils.launchLineWithText(text);

    if (!context.mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('LINE を開けませんでした。インストール後に再度お試しください'),
        ),
      );
    }
  }

  void _saveOnly(BuildContext context) {
    final r = restaurant;
    final station =
        r.lat != null && r.lng != null ? _nearestStationName(r.lat!, r.lng!) : '';
    onShared?.call(_buildEntry(r, station));
    Navigator.pop(context);
  }

  ReservedRestaurant _buildEntry(dynamic r, String station) {
    final List<String> imageUrls =
        (r.imageUrls as List?)?.cast<String>() ?? const [];
    return ReservedRestaurant(
      id: '${r.id}_${DateTime.now().millisecondsSinceEpoch}',
      restaurantName: r.name,
      category: r.category,
      reservedAt: DateTime.now(),
      address: r.address,
      hotpepperUrl: r.hotpepperUrl,
      imageUrl: r.imageUrl,
      photoRefs: PhotoRef.listToRefs(imageUrls),
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
          // プレビュー（LINEチャットのメッセージイメージ）
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
                Text(r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                if (r.category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(r.category,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
                if (station.isNotEmpty || r.distanceMinutes > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (station.isNotEmpty) '$station駅',
                      if (r.distanceMinutes > 0) '徒歩${r.distanceMinutes}分',
                    ].join('から'),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                ],
                if (r.lat != null && r.lng != null) ...[
                  const SizedBox(height: 8),
                  const Text('▼ Googleマップで確認',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  // Google Mapsカードプレビュー
                  Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8)),
                          ),
                          child: Icon(Icons.map_rounded,
                              size: 32, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(r.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('maps.google.com',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '※ あなたの現在地は共有されません',
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
              child: const Text('予約した（記録する）',
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
            top: 10,
            left: 10,
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
              Icons.receipt_long_rounded,
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
    // この Widget は後方互換のため残す（他から参照される可能性）。
    // 詳細画面では _NearbyTextLink（Tertiary テキストリンク）を使う。
    final hasLocation = widget.restaurant.lat != null;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: hasLocation && !_loading ? _search : null,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : const Icon(Icons.search_rounded,
                size: 18, color: AppColors.primary),
        label: Text(
          hasLocation ? 'このエリアで他のお店を探す' : '位置情報が取得できません',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasLocation
              ? AppColors.primaryLight
              : Colors.grey.shade100,
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: hasLocation ? AppColors.primary : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── エリア周辺探し（Tertiary テキストリンク） ───────────────────────────────
//
// _NearbySearchButton と同じ振る舞い（位置情報を使った周辺再検索 → BottomSheet）
// を持つが、見た目はテキストリンクで控えめ。詳細画面のボタン階層で
// Primary（予約）> Secondary（共有・ルート）> Tertiary（このリンク）という
// 視覚的優先度を確立するために導入。

class _NearbyTextLink extends StatefulWidget {
  const _NearbyTextLink({required this.restaurant});
  final Restaurant restaurant;

  @override
  State<_NearbyTextLink> createState() => _NearbyTextLinkState();
}

class _NearbyTextLinkState extends State<_NearbyTextLink> {
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
    if (!hasLocation) return const SizedBox.shrink();
    return Center(
      child: TextButton.icon(
        onPressed: _loading ? null : _search,
        icon: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : const Icon(Icons.search_rounded,
                size: 16, color: AppColors.primary),
        label: const Text(
          'このエリアで他のお店を探す',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
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
                                  Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
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
                            if (r.hasRating && r.rating! > 0) ...[
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
