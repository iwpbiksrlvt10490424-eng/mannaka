import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class GeocodingService {
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// 駅名から Google Maps の正確な座標を取得する
  /// 失敗時は null を返す
  static Future<(double lat, double lng)?> getStationLatLng(String stationName) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'address': '$stationName駅',
        'language': 'ja',
        'region': 'jp',
        'key': Secrets.geocodingApiKey,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        developer.log(
          '[Geocoding] HTTPエラー: ${res.statusCode}',
          name: 'GeocodingService',
        );
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final googleStatus = json['status'] as String?;
      developer.log(
        '[Geocoding] $stationName: googleStatus=$googleStatus',
        name: 'GeocodingService',
      );
      if (googleStatus != 'OK') {
        developer.log(
          '[Geocoding] エラー詳細: ${json['error_message'] ?? 'なし'}',
          name: 'GeocodingService',
        );
        return null;
      }
      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final location = (results[0] as Map)['geometry']['location'] as Map;
      final lat = (location['lat'] as num).toDouble();
      final lng = (location['lng'] as num).toDouble();
      developer.log(
        '[Geocoding] $stationName → ($lat, $lng)',
        name: 'GeocodingService',
      );
      return (lat, lng);
    } catch (e) {
      developer.log(
        '[Geocoding] 例外: ${e.runtimeType}',
        name: 'GeocodingService',
        error: e,
      );
      return null;
    }
  }
}
