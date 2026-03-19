import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// 地図タップで出発地を指定する画面
class MapInputScreen extends StatefulWidget {
  const MapInputScreen({
    super.key,
    required this.participantName,
    this.initialLat,
    this.initialLng,
  });

  final String participantName;
  final double? initialLat;
  final double? initialLng;

  @override
  State<MapInputScreen> createState() => _MapInputScreenState();
}

class _MapInputScreenState extends State<MapInputScreen> {
  final MapController _mapController = MapController();

  // デフォルト: 東京駅
  late double _lat;
  late double _lng;
  bool _pinSet = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? 35.6812;
    _lng = widget.initialLng ?? 139.7671;
    _pinSet = widget.initialLat != null;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final tileUrl = isDark
        ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── 地図 ────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_lat, _lng),
              initialZoom: _pinSet ? 15.0 : 11.0,
              onTap: (_, point) {
                HapticFeedback.lightImpact();
                setState(() {
                  _lat = point.latitude;
                  _lng = point.longitude;
                  _pinSet = true;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'jp.mannaka.mannaka',
                maxZoom: 19,
              ),
              if (_pinSet)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_lat, _lng),
                      width: 48,
                      height: 58,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.participantName.isNotEmpty
                                  ? widget.participantName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: const Size(12, 7),
                            painter: _TrianglePainter(
                                color: const Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ─── トップバー ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, MediaQuery.of(context).padding.top + 8, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${widget.participantName}の出発地を指定',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 説明テキスト ─────────────────────────────────────
          if (!_pinSet)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '地図をタップして出発地を指定',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ─── 確定ボタン ───────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: AnimatedOpacity(
              opacity: _pinSet ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '緯度 ${_lat.toStringAsFixed(4)}, 経度 ${_lng.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _pinSet
                          ? () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, (_lat, _lng));
                            }
                          : null,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        'ここを出発地にする',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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
