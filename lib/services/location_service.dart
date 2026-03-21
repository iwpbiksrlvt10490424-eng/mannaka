import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/station_data.dart';
import '../utils/geo_utils.dart';

class LocationService {
  /// 現在地の Permission を確認・リクエストし、位置情報を取得する。
  /// 許可されない場合は null を返す。
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  /// 緯度経度から最も近い駅インデックスを返す。
  static int nearestStationIndex(double lat, double lng) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < kStationLatLng.length; i++) {
      final (sLat, sLng) = kStationLatLng[i];
      final d = GeoUtils.distKm(lat, lng, sLat, sLng);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
