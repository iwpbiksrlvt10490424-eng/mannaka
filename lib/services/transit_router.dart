import 'dart:math';
import 'package:collection/collection.dart';
import '../data/station_data.dart';
import '../data/transit_graph_data.dart';
import '../utils/geo_utils.dart';

/// Dijkstra最短経路ルーター
/// 参加者の出発駅から全59候補駅への移動時間を計算する
class TransitRouter {
  TransitRouter._();
  static final TransitRouter instance = TransitRouter._();

  // キャッシュ: 出発駅名 → {候補駅名 → 分数}
  final Map<String, Map<String, int>> _cache = {};

  /// 出発駅名から全kStations候補への移動時間マップを返す
  Map<String, int> routeFromStation(String originName) {
    if (_cache.containsKey(originName)) return _cache[originName]!;
    _runDijkstra(originName);
    return _cache[originName]!;
  }

  /// 出発駅インデックスから候補駅インデックスへの移動時間（分）を返す
  int travelMinutes(int fromIdx, int toIdx) {
    final fromName = kStations[fromIdx];
    final toName = kStations[toIdx];
    final routes = routeFromStation(fromName);
    return routes[toName] ?? _geoFallback(fromIdx, toIdx);
  }

  void _runDijkstra(String origin) {
    final dist = <String, int>{};
    final pq = PriorityQueue<(int, String, String)>(
      (a, b) => a.$1.compareTo(b.$1),
    );

    dist[origin] = 0;
    pq.add((0, origin, ''));

    while (pq.isNotEmpty) {
      final (cost, name, arrivingLine) = pq.removeFirst();
      if (cost > (dist[name] ?? 999999)) continue;

      final neighbors = kTransitGraph[name];
      if (neighbors == null) continue;

      for (final edge in neighbors) {
        final transfer = (arrivingLine.isNotEmpty && arrivingLine != edge.lineId)
            ? kTransferPenaltyMinutes
            : 0;
        final newCost = cost + edge.minutes + transfer;
        if (newCost < (dist[edge.to] ?? 999999)) {
          dist[edge.to] = newCost;
          pq.add((newCost, edge.to, edge.lineId));
        }
      }
    }

    final originIdx = kStations.indexOf(origin);
    final result = <String, int>{};
    for (int i = 0; i < kStations.length; i++) {
      final name = kStations[i];
      result[name] = dist[name] ?? _geoFallback(originIdx >= 0 ? originIdx : 0, i);
    }
    _cache[origin] = result;
  }

  int _geoFallback(int fromIdx, int toIdx) {
    if (fromIdx >= kStationLatLng.length || toIdx >= kStationLatLng.length) return 60;
    final from = kStationLatLng[fromIdx];
    final to = kStationLatLng[toIdx];
    final distKm = GeoUtils.distKm(from.$1, from.$2, to.$1, to.$2);
    return max(5, (distKm / 25.0 * 60).round());
  }
}
