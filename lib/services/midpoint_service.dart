import 'dart:math';
import '../data/station_data.dart';
import '../data/restaurant_data.dart';
import '../models/meeting_point.dart';
import '../models/participant.dart';
import '../models/restaurant.dart';
import '../models/scored_restaurant.dart';
import '../providers/search_provider.dart';
import '../utils/geo_utils.dart';

class MidpointService {
  /// 駅間の移動時間（分）を返す。
  /// 両インデックスがkTransitMatrix範囲内ならマトリクスを使用し、
  /// それ以外はHaversine距離から推定する（約25km/h＋乗り換えオーバーヘッド）。
  static int _transitTime(int fromIdx, int toIdx) {
    if (fromIdx < kTransitMatrix.length && toIdx < kTransitMatrix.length) {
      return kTransitMatrix[fromIdx][toIdx];
    }
    final from = kStationLatLng[fromIdx];
    final to = kStationLatLng[toIdx];
    final distKm = GeoUtils.distKm(from.$1, from.$2, to.$1, to.$2);
    return max(5, (distKm / 25.0 * 60).round());
  }

  static List<MeetingPoint> calculate(List<Participant> participants) {
    final active = participants.where((p) => p.hasStation).toList();
    if (active.isEmpty) return [];

    final results = <MeetingPoint>[];

    // 集合場所の候補はkTransitMatrix範囲内の駅のみ（表示用の35駅）
    for (int c = 0; c < kTransitMatrix.length; c++) {
      final times = <String, int>{};
      for (final p in active) {
        times[p.id] = _transitTime(p.stationIndex!, c);
      }

      final values = times.values.toList();
      final total = values.fold(0, (a, b) => a + b);
      final avg = total / values.length;
      final maxVal = values.reduce((a, b) => a > b ? a : b);
      final minVal = values.reduce((a, b) => a < b ? a : b);

      final variance =
          values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / values.length;
      final stdDev = sqrt(variance);

      results.add(MeetingPoint(
        stationIndex: c,
        stationName: kStations[c],
        stationEmoji: kStationEmojis[c],
        totalMinutes: total,
        maxMinutes: maxVal,
        minMinutes: minVal,
        averageMinutes: avg,
        fairnessScore: 0,
        overallScore: 0,
        participantTimes: times,
        stdDev: stdDev,
      ));
    }

    if (results.isEmpty) return [];

    // Normalize scores
    final minTotal = results.map((r) => r.totalMinutes).reduce(min);
    final maxTotal = results.map((r) => r.totalMinutes).reduce(max);
    final minStd = results.map((r) => r.stdDev).reduce(min);
    final maxStd = results.map((r) => r.stdDev).reduce(max);

    final scored = results.map((r) {
      final effScore = maxTotal == minTotal
          ? 1.0
          : (maxTotal - r.totalMinutes) / (maxTotal - minTotal);
      final fairScore =
          maxStd == minStd ? 1.0 : (maxStd - r.stdDev) / (maxStd - minStd);
      final overall = 0.4 * effScore + 0.6 * fairScore;

      return MeetingPoint(
        stationIndex: r.stationIndex,
        stationName: r.stationName,
        stationEmoji: r.stationEmoji,
        totalMinutes: r.totalMinutes,
        maxMinutes: r.maxMinutes,
        minMinutes: r.minMinutes,
        averageMinutes: r.averageMinutes,
        fairnessScore: fairScore,
        overallScore: overall,
        participantTimes: r.participantTimes,
        stdDev: r.stdDev,
      );
    }).toList();

    scored.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    return scored.take(5).toList();
  }

  static List<Restaurant> getRestaurants({
    required int stationIndex,
    String? category,
    int? maxBudget,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
  }) {
    var list = kRestaurants.where((r) => r.stationIndex == stationIndex).toList();

    if (category != null && category.isNotEmpty) {
      list = list.where((r) => r.category == category).toList();
    }
    if (maxBudget != null && maxBudget > 0) {
      list = list.where((r) => r.priceAvg <= maxBudget).toList();
    }
    if (femaleFriendly) {
      list = list.where((r) => r.isFemalePopular).toList();
    }
    if (hasPrivateRoom) {
      list = list.where((r) => r.hasPrivateRoom).toList();
    }
    if (timeSlot == TimeSlot.lunch) {
      list = list.where((r) => r.isLunchAvailable).toList();
    } else if (timeSlot == TimeSlot.dinner) {
      list = list.where((r) => r.isDinnerAvailable).toList();
    }

    list.sort((a, b) => b.rating.compareTo(a.rating));
    return list;
  }

  static List<String> getCategories(int stationIndex) {
    return kRestaurants
        .where((r) => r.stationIndex == stationIndex)
        .map((r) => r.category)
        .toSet()
        .toList()
      ..sort();
  }

  static List<String> getAllCategories() {
    return kRestaurants.map((r) => r.category).toSet().toList()..sort();
  }

  /// 重心（centroid）を計算して返す
  static (double lat, double lng)? calcCentroid(List<Participant> participants) {
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.length < 2) return null;
    final lat = active.map((p) => p.lat!).reduce((a, b) => a + b) / active.length;
    final lng = active.map((p) => p.lng!).reduce((a, b) => a + b) / active.length;
    return (lat, lng);
  }

  /// 重心ベースでレストランをスコアリングして返す
  /// [baseRestaurants] が null の場合はモックデータ(kRestaurants)を使用
  static List<ScoredRestaurant> scoreRestaurants({
    required List<Participant> participants,
    required double centroidLat,
    required double centroidLng,
    List<Restaurant>? baseRestaurants,
    String? category,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
    int maxBudget = 0,
  }) {
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.isEmpty) return [];

    var restaurants = (baseRestaurants ?? kRestaurants).toList();

    if (category != null && category.isNotEmpty) {
      restaurants = restaurants.where((r) => r.category == category).toList();
    }
    if (maxBudget > 0) {
      restaurants = restaurants.where((r) => r.priceAvg <= maxBudget).toList();
    }
    if (femaleFriendly) {
      restaurants = restaurants.where((r) => r.isFemalePopular).toList();
    }
    if (hasPrivateRoom) {
      restaurants = restaurants.where((r) => r.hasPrivateRoom).toList();
    }
    if (timeSlot == TimeSlot.lunch) {
      restaurants = restaurants.where((r) => r.isLunchAvailable).toList();
    } else if (timeSlot == TimeSlot.dinner) {
      restaurants = restaurants.where((r) => r.isDinnerAvailable).toList();
    }

    if (restaurants.isEmpty) return [];

    // 各レストランの距離・公平性を計算
    final intermediates = restaurants.map((r) {
      // お店自身のlat/lngがあればそれを使い、なければ駅座標にフォールバック
      final (rLat, rLng) = (r.lat != null && r.lng != null)
          ? (r.lat!, r.lng!)
          : kStationLatLng[r.stationIndex];
      final distFromCentroid = GeoUtils.distKm(centroidLat, centroidLng, rLat, rLng);

      final pDists = <String, double>{};
      for (final p in active) {
        pDists[p.id] = GeoUtils.distKm(p.lat!, p.lng!, rLat, rLng);
      }

      final dValues = pDists.values.toList();
      final avg = dValues.reduce((a, b) => a + b) / dValues.length;
      final variance =
          dValues.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) / dValues.length;
      final stdDev = sqrt(variance);

      return (
        restaurant: r,
        distFromCentroid: distFromCentroid,
        participantDistances: pDists,
        stdDev: stdDev,
      );
    }).toList();

    // 正規化
    final maxDist = intermediates.map((s) => s.distFromCentroid).reduce(max);
    final minDist = intermediates.map((s) => s.distFromCentroid).reduce(min);
    final maxStd = intermediates.map((s) => s.stdDev).reduce(max);
    final minStd = intermediates.map((s) => s.stdDev).reduce(min);

    final scored = intermediates.map((s) {
      final distScore = maxDist == minDist
          ? 1.0
          : (maxDist - s.distFromCentroid) / (maxDist - minDist);
      final fairScore =
          maxStd == minStd ? 1.0 : (maxStd - s.stdDev) / (maxStd - minStd);
      final ratingScore = ((s.restaurant.rating - 3.0) / 2.0).clamp(0.0, 1.0);
      // 予約可否を最重要因子に（25%）
      final reservationScore = s.restaurant.isReservable ? 1.0 : 0.0;
      final overall = 0.30 * distScore +
          0.30 * fairScore +
          0.15 * ratingScore +
          0.25 * reservationScore;

      return ScoredRestaurant(
        restaurant: s.restaurant,
        score: overall,
        distanceKm: s.distFromCentroid,
        participantDistances: s.participantDistances,
        fairnessScore: fairScore,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

}
