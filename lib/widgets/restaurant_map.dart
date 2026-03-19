import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/scored_restaurant.dart';
import '../models/participant.dart';
import '../data/station_data.dart';
import '../theme/app_theme.dart';
import '../screens/restaurant_detail_screen.dart';

class RestaurantMap extends StatefulWidget {
  const RestaurantMap({
    super.key,
    required this.scored,
    required this.centroidLat,
    required this.centroidLng,
    this.participants = const [],
    this.onDecide,
  });

  final List<ScoredRestaurant> scored;
  final double centroidLat;
  final double centroidLng;
  final List<Participant> participants;
  final void Function(ScoredRestaurant)? onDecide;

  @override
  State<RestaurantMap> createState() => _RestaurantMapState();
}

class _RestaurantMapState extends State<RestaurantMap>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  ScoredRestaurant? _selected;

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ─── 地図本体 ──────────────────────────────────────────
        Builder(
          builder: (mapContext) {
            final isDark = MediaQuery.platformBrightnessOf(mapContext) == Brightness.dark;
            final tileUrl = isDark
                ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';
            return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(widget.centroidLat, widget.centroidLng),
            initialZoom: 15.0,
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'jp.mannaka.mannaka',
              maxZoom: 19,
            ),
            // 参加者ピン（青丸アイコン）
            MarkerLayer(
              markers: widget.participants
                  .where((p) => p.hasLocation)
                  .map((p) => Marker(
                        point: LatLng(p.lat!, p.lng!),
                        width: 44,
                        height: 54,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            CustomPaint(
                              size: const Size(10, 6),
                              painter: _TrianglePainter(
                                  color: const Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            // 重心マーカー
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(widget.centroidLat, widget.centroidLng),
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.primary, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.place_rounded, size: 20, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            // レストランマーカー
            MarkerLayer(
              markers: widget.scored.asMap().entries.map((e) {
                final sr = e.value;
                final isSelected = _selected == sr;
                final (lat, lng) = _restLatLng(sr);
                return Marker(
                  point: LatLng(lat, lng),
                  width: isSelected ? 56 : 40,
                  height: isSelected ? 56 : 40,
                  child: GestureDetector(
                    onTap: () => _onMarkerTap(sr, lat, lng),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFFEF4444),
                          width: isSelected ? 0 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: isSelected ? 0.25 : 0.15),
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.restaurant,
                        size: isSelected ? 28 : 20,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
          },
        ),

        // ─── 選択中レストランの浮きカード ─────────────────────
        if (_selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 160,
            child: _SelectedCard(
              scored: _selected!,
              onClose: () => setState(() => _selected = null),
              onDetail: () => _openDetail(_selected!),
              onDecide: widget.onDecide != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      widget.onDecide!(_selected!);
                    }
                  : null,
            ),
          ),

        // ─── 凡例 ─────────────────────────────────────────────
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('集合スポット',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('出発地',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                const Icon(Icons.restaurant_rounded, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${widget.scored.length}件',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),

        // ─── フィットボタン ────────────────────────────────────
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _fitAll,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4)
                ],
              ),
              child: const Icon(Icons.zoom_out_map_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
        ),

        // ─── Draggable Bottom Sheet（GOタクシー風リスト）────────
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.13,
          minChildSize: 0.08,
          maxChildSize: 0.6,
          snap: true,
          snapSizes: const [0.13, 0.4, 0.6],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -2)),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Text(
                                'おすすめのお店',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.scored.length}件',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final sr = widget.scored[i];
                        final r = sr.restaurant;
                        final isSelected = _selected == sr;
                        return InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final (lat, lng) = _restLatLng(sr);
                            _onMarkerTap(sr, lat, lng);
                            _sheetController.animateTo(
                              0.13,
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Container(
                            color: isSelected
                                ? AppColors.primary
                                    .withValues(alpha: 0.05)
                                : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: i < 3 ? 18 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.getCategoryBg(
                                        r.category),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.restaurant_rounded, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(r.category,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textSecondary)),
                                          const SizedBox(width: 6),
                                          Text(r.priceStr,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textSecondary)),
                                          const SizedBox(width: 6),
                                          Text(sr.distanceLabel,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textTertiary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(sr.score * 100).round()}点',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (r.isReservable)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 3),
                                        child: Text(
                                          '予約可',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: widget.scored.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  (double, double) _restLatLng(ScoredRestaurant sr) {
    if (sr.restaurant.lat != null && sr.restaurant.lng != null) {
      return (sr.restaurant.lat!, sr.restaurant.lng!);
    }
    return kStationLatLng[sr.restaurant.stationIndex];
  }

  void _onMarkerTap(ScoredRestaurant sr, double lat, double lng) {
    setState(() => _selected = sr);
    _mapController.move(LatLng(lat, lng), 16.0);
  }

  void _fitAll() {
    final points = [
      LatLng(widget.centroidLat, widget.centroidLng),
      ...widget.participants
          .where((p) => p.hasLocation)
          .map((p) => LatLng(p.lat!, p.lng!)),
      ...widget.scored.map((sr) {
        final (lat, lng) = _restLatLng(sr);
        return LatLng(lat, lng);
      }),
    ];
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _openDetail(ScoredRestaurant sr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RestaurantDetailScreen(restaurant: sr.restaurant),
      ),
    );
  }
}

// ─── 三角形（吹き出しの尻尾） ───────────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

Widget _mapPhotoFallback(Color bg) => Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bg, bg.withValues(alpha: 0.65)],
    ),
  ),
  child: const Center(
    child: Icon(Icons.restaurant, size: 24, color: Colors.white70),
  ),
);

// ─── 選択中レストランカード ─────────────────────────────────────────────────

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.scored,
    required this.onClose,
    required this.onDetail,
    this.onDecide,
  });

  final ScoredRestaurant scored;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  final VoidCallback? onDecide;

  @override
  Widget build(BuildContext context) {
    final r = scored.restaurant;
    final categoryColor = AppColors.getCategoryColor(r.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: r.imageUrl != null && r.imageUrl!.isNotEmpty
                        ? Image.network(
                            r.imageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _mapPhotoFallback(AppColors.getCategoryBg(r.category)),
                          )
                        : _mapPhotoFallback(AppColors.getCategoryBg(r.category)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(r.priceStr,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          const SizedBox(width: 6),
                          Text(scored.distanceLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close,
                        size: 18, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetail,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                          color:
                              AppColors.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('詳細を見る',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (onDecide != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDecide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('ここに決定！',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
