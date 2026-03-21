import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../data/station_data.dart';

/// HeartRails Express API を使った全国駅検索サービス
/// 無料・認証不要・全国対応
class StationSearchService {
  static const _base = 'https://express.heartrails.com/api/json';

  // kStations 名前 → インデックスマップ（ローカルで対応できる駅）
  static final Map<String, int> _kStationIndex = {
    for (int i = 0; i < kStations.length; i++) kStations[i]: i,
  };

  /// 駅名で検索（HeartRails API）。
  /// kStations に含まれない駅は緯度経度から最近傍 kStation を自動解決。
  static Future<List<StationCandidate>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse(
          '$_base?method=getStations&name=${Uri.encodeComponent(q)}');
      final res =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final stations =
          (body['response']?['station'] as List?) ?? [];

      final seen = <String>{};
      final results = <StationCandidate>[];
      for (final s in stations) {
        final name = (s['name'] as String? ?? '').trim();
        final line = (s['line'] as String? ?? '');
        final lat = double.tryParse(s['y']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(s['x']?.toString() ?? '') ?? 0.0;
        if (name.isEmpty || lat == 0.0) continue;
        if (!seen.add(name)) continue; // 同名駅は先頭のみ（路線は subtitle で表示）

        final kIdx = _kStationIndex[name] ?? _nearestKStation(lat, lng);
        results.add(StationCandidate(
            name: name, line: line, lat: lat, lng: lng, kIndex: kIdx));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// kStationLatLng から最近傍の駅インデックスを返す
  static int _nearestKStation(double lat, double lng) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < kStationLatLng.length; i++) {
      final (sLat, sLng) = kStationLatLng[i];
      final d = _dist(lat, lng, sLat, sLng);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    // Haversine 簡易版（比較用）
    final dlat = (lat1 - lat2) * math.pi / 180;
    final dlng = (lng1 - lng2) * math.pi / 180;
    return dlat * dlat + dlng * dlng;
  }
}

/// API から返ってくる駅候補
class StationCandidate {
  const StationCandidate({
    required this.name,
    required this.line,
    required this.lat,
    required this.lng,
    required this.kIndex,
  });

  final String name;
  final String line; // 路線名（サブタイトル表示用）
  final double lat;
  final double lng;
  final int kIndex; // 必ず 0〜kStations.length-1（最近傍解決済み）
}
