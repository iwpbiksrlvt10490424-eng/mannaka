import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/search_provider.dart';
import '../providers/ad_provider.dart';
import '../models/ad.dart';
import '../theme/app_theme.dart';
import '../data/station_data.dart';
import '../services/location_service.dart';
import '../providers/profile_provider.dart';

typedef NavigateCallback = void Function(int tabIndex, {Occasion? occasion});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onNavigate});
  final NavigateCallback? onNavigate;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  gmap.GoogleMapController? _mapController;
  // 生のGPS座標は保持しない。最寄駅に変換した座標のみを使用（プライバシー保護）
  gmap.LatLng? _nearestStationLatLng;
  ProviderSubscription<HomeStationData?>? _homeStationSub;
  // マイページでホーム駅が変更されたとき用 — Offstage中でもアニメーション漏れを防ぐ
  gmap.LatLng? _pendingCameraLatLng;

  double _lastSize = 0;

  /// GPS取得 → 最寄駅に変換 → 駅座標のみを保持
  /// 生の緯度経度は外部に露出しない
  /// [saveAsHome] = true のとき、ホーム駅として保存してマイページ・検索にも反映する
  void _updateToNearestStation(double lat, double lng, {bool saveAsHome = false}) {
    final idx = LocationService.nearestStationIndex(lat, lng);
    final (sLat, sLng) = kStationLatLng[idx];
    final stationLoc = gmap.LatLng(sLat, sLng);
    if (mounted) {
      setState(() {
        _nearestStationLatLng = stationLoc;
      });
      if (saveAsHome) _saveAsHomeStation(idx, sLat, sLng);
    }
  }

  /// 最寄駅をホーム駅としてSharedPreferences・プロバイダに保存する。
  /// ホーム駅が未設定のときのみ保存（手動設定を上書きしない）。
  /// 参加者の駅は変更しない（_autoFillHomeStation に任せる）。
  Future<void> _saveAsHomeStation(int idx, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    // 既にホーム駅が設定されていれば上書きしない
    if (prefs.getInt('home_station') != null) return;
    await prefs.setInt('home_station', idx);
    await prefs.setString('home_station_name', kStations[idx]);
    await prefs.setDouble('home_station_lat', lat);
    await prefs.setDouble('home_station_lng', lng);
    if (!mounted) return;
    ref.read(homeStationProvider.notifier).state = idx;
    ref.read(homeStationDataProvider.notifier).state =
        HomeStationData(name: kStations[idx], lat: lat, lng: lng);
  }

  // Phase 1: getLastKnownPosition（即座）→ 最寄駅ピン表示
  // Phase 2: getCurrentPosition（バックグラウンド）→ より正確な最寄駅に更新
  Future<void> _fetchLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }

    // Phase 1: キャッシュ位置を即座に取得 → 最寄駅に変換
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (!mounted) return;
      if (last != null) {
        _updateToNearestStation(last.latitude, last.longitude);
      }
    } catch (_) {}

    // Phase 2: バックグラウンドで精度の高い現在地を取得 → 最寄駅を再確定 → ホーム駅として保存
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      _updateToNearestStation(pos.latitude, pos.longitude, saveAsHome: true);
      // ホーム駅が手動設定済みの場合はGPSによるカメラ移動をスキップする
      // （マイページで選択した駅のピンが画面外に押し出されるのを防ぐ）
      final existingHome = ref.read(homeStationDataProvider);
      if (existingHome == null && _nearestStationLatLng != null) {
        _mapController?.animateCamera(
          gmap.CameraUpdate.newLatLngZoom(_nearestStationLatLng!, 14.0),
        );
      }
    } catch (_) {}
  }


  void _onSheetChanged() {
    final size = _sheetCtrl.size;
    const snapPoints = [0.04, 0.09, 0.32];
    for (final snap in snapPoints) {
      if ((_lastSize - snap).abs() > 0.01 && (size - snap).abs() < 0.01) {
        HapticFeedback.selectionClick();
        break;
      }
    }
    _lastSize = size;
  }

  /// SharedPreferences からホーム駅を読み込んで homeStationDataProvider を設定する。
  /// SettingsScreen._loadPrefs() と競合しないよう、未設定の場合のみ実行する。
  Future<void> _loadHomeStationIfNeeded() async {
    if (ref.read(homeStationDataProvider) != null) return;
    final prefs = await SharedPreferences.getInstance();
    final homeStation = prefs.getInt('home_station');
    if (homeStation == null) return;
    if (!mounted) return;
    final homeStationName = prefs.getString('home_station_name');
    final homeStationLat = prefs.getDouble('home_station_lat');
    final homeStationLng = prefs.getDouble('home_station_lng');
    if (homeStation < kStationLatLng.length) {
      final fallback = kStationLatLng[homeStation];
      final lat = homeStationLat ?? fallback.$1;
      final lng = homeStationLng ?? fallback.$2;
      if (!mounted) return;
      ref.read(homeStationProvider.notifier).state = homeStation;
      ref.read(homeStationDataProvider.notifier).state = HomeStationData(
        name: homeStationName ?? kStations[homeStation],
        lat: lat,
        lng: lng,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _sheetCtrl.addListener(_onSheetChanged);
    _fetchLocation();
    _loadHomeStationIfNeeded();
    // ホーム駅の変更を監視してカメラを移動（マーカーはbuild()内のwatchで自動更新）
    _homeStationSub = ref.listenManual<HomeStationData?>(homeStationDataProvider, (prev, next) {
      if (next == null) return;
      debugPrint('[HomeScreen] homeStationData変更: ${next.name} (${next.lat}, ${next.lng})');
      final target = gmap.LatLng(next.lat, next.lng);
      // カメラ移動を複数回リトライ（IndexedStackのOffstage対策）
      for (final delay in [300, 800, 1500]) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (!mounted || _mapController == null) return;
          _mapController!.animateCamera(
            gmap.CameraUpdate.newLatLngZoom(target, 15.0),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _homeStationSub?.close();
    _sheetCtrl.removeListener(_onSheetChanged);
    _sheetCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    final hasResult = searchState.hasCentroid &&
        searchState.sortedRestaurants.isNotEmpty;
    final homeStationData = ref.watch(homeStationDataProvider);

    // ホーム駅が設定されている場合はそちらを優先
    final lat = homeStationData?.lat
        ?? searchState.centroidLat
        ?? _nearestStationLatLng?.latitude
        ?? 35.6812;
    final lng = homeStationData?.lng
        ?? searchState.centroidLng
        ?? _nearestStationLatLng?.longitude
        ?? 139.7671;
    final scored = searchState.sortedRestaurants;

    // Google Maps SDK for iOS: $7/1,000 map loads.
    // $200/month free credit → ~28,500 loads/month.
    // API key should be restricted to iOS bundle ID `com.example.mannaka`
    // in Google Cloud Console → APIs & Services → Credentials.

    // Build Google Maps markers
    final gmapMarkers = <gmap.Marker>{};
    // ホーム駅ピン（実際に選択した駅の座標を使用）
    final effectiveHomeMarker = homeStationData != null
        ? gmap.Marker(
            markerId: const gmap.MarkerId('home_station'),
            position: gmap.LatLng(homeStationData.lat, homeStationData.lng),
            infoWindow: gmap.InfoWindow(title: '🏠 ${homeStationData.name}'),
            icon: gmap.BitmapDescriptor.defaultMarker,
          )
        : null;
    if (effectiveHomeMarker != null) gmapMarkers.add(effectiveHomeMarker);
    if (hasResult) {
      // Centroid marker
      gmapMarkers.add(gmap.Marker(
        markerId: const gmap.MarkerId('centroid'),
        position: gmap.LatLng(lat, lng),
        infoWindow: const gmap.InfoWindow(title: 'Aimachi'),
        icon: gmap.BitmapDescriptor.defaultMarkerWithHue(
            gmap.BitmapDescriptor.hueRose),
      ));
      // Restaurant markers (top 5)
      for (final sr in scored.take(5)) {
        final sLat = sr.restaurant.lat;
        final sLng = sr.restaurant.lng;
        if (sLat != null && sLng != null) {
          gmapMarkers.add(gmap.Marker(
            markerId: gmap.MarkerId(sr.restaurant.id),
            position: gmap.LatLng(sLat, sLng),
            infoWindow: gmap.InfoWindow(title: sr.restaurant.name),
          ));
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── 全画面地図 ───────────────────────────────────────
          Positioned.fill(
            child: gmap.GoogleMap(
              initialCameraPosition: gmap.CameraPosition(
                target: gmap.LatLng(lat, lng),
                zoom: homeStationData != null ? 15.0 : (hasResult ? 15.5 : 13.5),
              ),
              markers: gmapMarkers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: gmap.MapType.normal,
              onMapCreated: (controller) {
                _mapController = controller;
                // ホーム駅選択中 or 選択済みのとき、初期カメラをホーム駅に移動
                final pending = _pendingCameraLatLng;
                if (pending != null) {
                  _pendingCameraLatLng = null;
                  Future.microtask(() {
                    if (mounted) {
                      controller.animateCamera(
                        gmap.CameraUpdate.newLatLngZoom(pending, 14.5),
                      );
                    }
                  });
                } else {
                  final homeData = ref.read(homeStationDataProvider);
                  if (homeData != null && !ref.read(searchProvider).hasCentroid) {
                    Future.microtask(() {
                      if (mounted) {
                        controller.animateCamera(
                          gmap.CameraUpdate.newLatLngZoom(
                            gmap.LatLng(homeData.lat, homeData.lng), 14.5,
                          ),
                        );
                      }
                    });
                  }
                }
              },
            ),
          ),

          // ─── トップバー（浮き） ───────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 10, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Aimachi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // ─── マスコットキャラ（全画面Stackで移動） ───────────
          Positioned.fill(
            child: _MascotButton(onNavigate: widget.onNavigate),
          ),

          // ─── Draggable Bottom Sheet ───────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.09,
            minChildSize: 0.04,
            maxChildSize: 0.32,
            snap: true,
            snapSizes: const [0.04, 0.09, 0.32],
            builder: (ctx, scrollCtrl) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7F7),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, -4)),
                  ],
                ),
                child: CustomScrollView(
                  controller: scrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // ドラッグハンドル
                          const SizedBox(height: 10),
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // タイトル
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '集まりやすいお店、見つけよう',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                // ─── メインCTA ─────────────────────
                                Semantics(
                                  label: 'Aimaを探す',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      widget.onNavigate?.call(1);
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.people_alt_rounded,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Aimaを探す',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ─── シーンで絞り込む ──────────────
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '集まりの種類を選んでください',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _OccasionGrid(onNavigate: widget.onNavigate),
                          const SizedBox(height: 46),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}



// ─── 目的グリッド（横スクロール・ピル形状） ─────────────────────────────────

class _OccasionGrid extends StatelessWidget {
  const _OccasionGrid({this.onNavigate});
  final NavigateCallback? onNavigate;

  static const _items = [
    (Occasion.girlsNight, '女子会'),
    (Occasion.birthday, '誕生日'),
    (Occasion.lunch, 'ランチ'),
    (Occasion.mixer, '合コン'),
    (Occasion.welcome, '歓迎会'),
    (Occasion.date, 'デート'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (occasion, label) = _items[i];
          return _cell(occasion, label);
        },
      ),
    );
  }

  Widget _cell(Occasion occasion, String label) {
    return Semantics(
      label: '$label シーンで検索',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onNavigate?.call(1, occasion: occasion);
        },
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ),
      ),
    );
  }
}

// ─── マスコットキャラクター ────────────────────────────────────────────────
class _MascotButton extends StatefulWidget {
  const _MascotButton({this.onNavigate});
  final NavigateCallback? onNavigate;

  @override
  State<_MascotButton> createState() => _MascotButtonState();
}

class _MascotButtonState extends State<_MascotButton>
    with TickerProviderStateMixin {
  late final AnimationController _blinkCtrl;
  late final Animation<double> _blinkAnim;
  late AnimationController _wanderCtrl;
  late Animation<double> _wanderX;
  late Animation<double> _wanderY;

  double _posX = -1;
  double _posY = -1;
  double _fromX = 0;
  double _fromY = 0;
  double _toX = 0;
  double _toY = 0;
  bool _dragging = false;
  bool _pauseWander = false;

  static const _size = 70.0;

  @override
  void initState() {
    super.initState();

    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _blinkAnim = Tween<double>(begin: 1.0, end: 0.05).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );
    _scheduleBlink();

    _wanderCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _wanderX = Tween<double>(begin: 0, end: 0).animate(_wanderCtrl);
    _wanderY = Tween<double>(begin: 0, end: 0).animate(_wanderCtrl);
    _wanderCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_pauseWander && mounted) {
        _pickNewTarget();
      }
    });
  }

  void _initPositionIfNeeded(double screenW, double screenH) {
    if (_posX < 0) {
      _posX = screenW - _size - 20;
      _posY = (screenH - _size) / 2;
      _fromX = _posX;
      _fromY = _posY;
      _toX = _posX;
      _toY = _posY;
      Future.delayed(const Duration(milliseconds: 500), _pickNewTarget);
    }
  }

  void _pickNewTarget() {
    if (!mounted || _pauseWander) return;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final rng = math.Random();
    final currentX = _wanderCtrl.isAnimating ? _wanderX.value : _toX;
    final currentY = _wanderCtrl.isAnimating ? _wanderY.value : _toY;
    _fromX = currentX;
    _fromY = currentY;
    _toX = (_fromX + (rng.nextDouble() - 0.5) * 120).clamp(0.0, screenW - _size);
    _toY = (_fromY + (rng.nextDouble() - 0.5) * 100).clamp(screenH * 0.12, screenH * 0.82 - _size - 8);
    _wanderX = Tween<double>(begin: _fromX, end: _toX).animate(
      CurvedAnimation(parent: _wanderCtrl, curve: Curves.easeInOut),
    );
    _wanderY = Tween<double>(begin: _fromY, end: _toY).animate(
      CurvedAnimation(parent: _wanderCtrl, curve: Curves.easeInOut),
    );
    _wanderCtrl.forward(from: 0);
  }

  void _scheduleBlink() {
    Future.delayed(Duration(seconds: 3 + math.Random().nextInt(4)), () {
      if (!mounted) return;
      _blinkCtrl.forward().then((_) {
        if (!mounted) return;
        _blinkCtrl.reverse();
      }).then((_) {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _blinkCtrl.forward().then((_) {
            if (!mounted) return;
            _blinkCtrl.reverse();
          }).then((_) {
            if (!mounted) return;
            _scheduleBlink();
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _wanderCtrl.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MascotSheet(onNavigate: widget.onNavigate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    _initPositionIfNeeded(screenW, screenH);

    return AnimatedBuilder(
      animation: Listenable.merge([_blinkAnim, _wanderCtrl]),
      builder: (context, child) {
        final x = _dragging ? _posX : (_wanderCtrl.isAnimating ? _wanderX.value : _toX);
        final y = _dragging ? _posY : (_wanderCtrl.isAnimating ? _wanderY.value : _toY);

        return Stack(
          children: [
            Positioned(
              left: x,
              top: y,
              child: Semantics(
                label: 'まんちゃん',
                button: true,
                child: GestureDetector(
                  onTap: () => _onTap(context),
                  onPanStart: (_) {
                  _wanderCtrl.stop();
                  setState(() {
                    _dragging = true;
                    _pauseWander = true;
                    _posX = _wanderCtrl.isAnimating ? _wanderX.value : _toX;
                    _posY = _wanderCtrl.isAnimating ? _wanderY.value : _toY;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _posX = (_posX + details.delta.dx).clamp(0.0, screenW - _size);
                    _posY = (_posY + details.delta.dy).clamp(0.0, screenH - _size);
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _dragging = false;
                    _fromX = _posX;
                    _fromY = _posY;
                    _toX = _posX;
                    _toY = _posY;
                  });
                  Future.delayed(const Duration(seconds: 2), () {
                    if (!mounted) return;
                    setState(() => _pauseWander = false);
                    _pickNewTarget();
                  });
                },
                child: AnimatedScale(
                  scale: _dragging ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: CustomPaint(
                    size: const Size(_size, _size),
                    painter: _MascotPainter(blinkAmount: _blinkAnim.value),
                  ),
                ),
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter({required this.blinkAmount});
  final double blinkAmount;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ─ ボディ（丸っこいピン形）
    final bodyPaint = Paint()..color = AppColors.primary;
    final bodyPath = ui.Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy - 6), radius: 26));
    canvas.drawPath(bodyPath, bodyPaint);

    // ピンの先端
    final pinPaint = Paint()..color = AppColors.primary;
    final pinPath = ui.Path()
      ..moveTo(cx - 10, cy + 14)
      ..lineTo(cx, cy + 26)
      ..lineTo(cx + 10, cy + 14)
      ..close();
    canvas.drawPath(pinPath, pinPaint);

    // ─ 顔の白い丸
    final facePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy - 8), 18, facePaint);

    // ─ 目（左右）
    final eyePaint = Paint()..color = const Color(0xFF333333);
    final eyeH = 5.0 * blinkAmount;
    // 左目
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 6, cy - 10), width: 5, height: math.max(eyeH, 0.8)),
        const Radius.circular(3),
      ),
      eyePaint,
    );
    // 右目
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 6, cy - 10), width: 5, height: math.max(eyeH, 0.8)),
        const Radius.circular(3),
      ),
      eyePaint,
    );

    // ─ ほっぺ
    final cheekPaint = Paint()
      ..color = const Color(0xFFFFB3C1).withValues(alpha: 0.7);
    canvas.drawCircle(Offset(cx - 11, cy - 5), 5, cheekPaint);
    canvas.drawCircle(Offset(cx + 11, cy - 5), 5, cheekPaint);

    // ─ 口（笑顔の弧）
    final mouthPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final mouthPath = ui.Path();
    mouthPath.moveTo(cx - 6, cy - 1);
    mouthPath.quadraticBezierTo(cx, cy + 5, cx + 6, cy - 1);
    canvas.drawPath(mouthPath, mouthPaint);

    // ─ 小さな星（アクセント）
    _drawStar(canvas, Offset(cx + 22, cy - 22), 5, const Color(0xFFF59E0B));
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()..color = color;
    final path = ui.Path();
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 5);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      final innerAngle = angle + math.pi / 5;
      path.lineTo(
        center.dx + r * 0.4 * math.cos(innerAngle),
        center.dy + r * 0.4 * math.sin(innerAngle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.blinkAmount != blinkAmount;
}

// ─── マスコット吹き出しシート ───────────────────────────────────────────────
class _MascotSheet extends ConsumerWidget {
  const _MascotSheet({this.onNavigate});
  final NavigateCallback? onNavigate;

  static const _tips = [
    '今日、みんなどこ行く',
    '駅を入れるだけで、\nぴったりなお店が見つかる。',
    '予約できるお店を\n優先的に表示してるよ',
    'よく使う駅を\n登録しておくと便利！',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = _tips[DateTime.now().second % _tips.length];
    final ads = ref.watch(adsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // キャラクターと吹き出し
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    children: [
                      CustomPaint(
                        size: const Size(64, 64),
                        painter: const _MascotPainter(blinkAmount: 1.0),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'マチみちゃん',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // クイックアクション
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _QuickAction(
                    icon: Icons.search_rounded,
                    label: 'Aimaを探す',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      onNavigate?.call(1);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.celebration_rounded,
                          label: '女子会',
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(context);
                            onNavigate?.call(1, occasion: Occasion.girlsNight);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.restaurant_rounded,
                          label: 'ランチ',
                          color: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.pop(context);
                            onNavigate?.call(1, occasion: Occasion.lunch);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.favorite_rounded,
                          label: 'デート',
                          color: const Color(0xFFEF4444),
                          onTap: () {
                            Navigator.pop(context);
                            onNavigate?.call(1, occasion: Occasion.date);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── お店からのお知らせ（広告）───────────────────
            if (ads.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      'お店からのお知らせ',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ads.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _AdCard(ad: ads[i]),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad});
  final AppAd ad;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        // 広告URLへ遷移（将来的にはRestaurantDetailScreenへ）
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                ad.imageUrl,
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 90,
                  color: AppColors.primaryLight,
                  alignment: Alignment.center,
                  child: const Icon(Icons.restaurant_rounded,
                      color: AppColors.primary, size: 32),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ad.restaurantName,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ad.discount,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ad.title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 初回利用ガイド ────────────────────────────────────────────────────────



