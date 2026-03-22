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
      final overall = 0.2 * effScore + 0.8 * fairScore;

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
    Set<String>? categories,
    int? maxBudget,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
  }) {
    var list = kRestaurants.where((r) => r.stationIndex == stationIndex).toList();

    if (categories != null && categories.isNotEmpty) {
      list = list.where((r) => categories.contains(r.category)).toList();
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
    Set<String>? categories,
    bool femaleFriendly = false,
    bool hasPrivateRoom = false,
    TimeSlot timeSlot = TimeSlot.all,
    int maxBudget = 0,
    String? occasion,
    String? groupRelation,
  }) {
    final active = participants.where((p) => p.hasLocation).toList();
    if (active.isEmpty) return [];

    var restaurants = (baseRestaurants ?? kRestaurants).toList();

    // ハードフィルタ（ユーザーが明示的に指定した条件のみ）
    if (categories != null && categories.isNotEmpty) {
      restaurants = restaurants.where((r) => categories.contains(r.category)).toList();
    }
    if (maxBudget > 0) {
      restaurants = restaurants.where((r) => r.priceAvg == 0 || r.priceAvg <= maxBudget).toList();
    } else if (maxBudget < 0) {
      // ¥10,000以上（センチネル値 -10000）
      final minB = maxBudget.abs();
      restaurants = restaurants.where((r) => r.priceAvg == 0 || r.priceAvg >= minB).toList();
    }
    // femaleFriendly はスコアリングで対応（シーンスコアで女子会に不向きな店を自然に下位に押し下げる）
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

    // 正規化（距離のみ使用）
    final maxDist = intermediates.map((s) => s.distFromCentroid).reduce(max);
    final minDist = intermediates.map((s) => s.distFromCentroid).reduce(min);

    final scored = intermediates.map((s) {
      final r = s.restaurant;

      // ── 距離スコア（重心からの近さ）──────────────────────────────────────
      final distScore = maxDist == minDist
          ? 1.0
          : (maxDist - s.distFromCentroid) / (maxDist - minDist);

      // ── クオリティスコア（客観的な店舗品質シグナル）─────────────────────
      // 予約可能(Hotpepper URL あり) が最重要シグナル: 実在・人気店の証拠
      double qualityScore = 0.0;
      if (r.isReservable) qualityScore += 0.40;                              // 予約可
      if (r.imageUrl != null && r.imageUrl!.isNotEmpty) qualityScore += 0.25; // 写真あり
      if (r.course) qualityScore += 0.15;                                    // コースあり
      if (r.freeDrink) qualityScore += 0.10;                                 // 飲み放題
      if (r.rating >= 3.5) qualityScore += 0.10;                             // 高評価
      qualityScore = qualityScore.clamp(0.0, 1.0);

      // ── シーン適合スコア（occasion選択時のみ有効）───────────────────────
      final occasionScore = occasion != null
          ? _computeOccasionScore(r, occasion)
          : 0.5; // occasion未選択時はニュートラル

      // ── 総合スコア ───────────────────────────────────────────────────────
      // occasion未選択: クオリティ65% + 距離35%
      // occasion選択時: シーン45% + クオリティ40% + 距離15%
      final overall = occasion != null
          ? 0.45 * occasionScore + 0.40 * qualityScore + 0.15 * distScore
          : 0.65 * qualityScore + 0.35 * distScore;

      // ── おすすめラベル ────────────────────────────────────────────────────
      final reasons = <String>[];
      if (r.isReservable) reasons.add('予約可');
      if (r.freeDrink) reasons.add('飲み放題');
      if (r.course) reasons.add('コースあり');
      if (r.hasPrivateRoom && reasons.length < 2) reasons.add('個室あり');
      if (distScore >= 0.8 && reasons.length < 2) reasons.add('中間地点');
      final curationLabel = reasons.take(2).join(' · ');

      return ScoredRestaurant(
        restaurant: s.restaurant,
        score: overall,
        distanceKm: s.distFromCentroid,
        participantDistances: s.participantDistances,
        fairnessScore: distScore,
        curationLabel: curationLabel,
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// シーンに応じたレストランスコアをカテゴリ・属性から動的に計算する
  /// （APIレストランに occasionTags が存在しないため、カテゴリと属性で代替）
  static double _computeOccasionScore(Restaurant r, String occasion) {
    switch (occasion) {
      case '女子会':
        double s = switch (r.category) {
          'カフェ' => 1.0,
          'イタリアン' || 'フレンチ' => 0.95,
          '韓国料理' => 0.90,
          '和食' => 0.75,
          '洋食' => 0.70,
          'バー' => 0.45,
          '居酒屋' => 0.25,
          'ラーメン' || '中華' || '焼肉' => 0.10,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) s = (s + 0.15).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.course) s = (s + 0.05).clamp(0.0, 1.0);
        return s;

      case '誕生日':
        double s = switch (r.category) {
          'フレンチ' || 'イタリアン' => 1.0,
          'カフェ' => 0.85,
          '和食' => 0.80,
          '洋食' => 0.70,
          '居酒屋' => 0.35,
          'ラーメン' || '中華' => 0.15,
          _ => 0.55,
        };
        if (r.hasPrivateRoom) s = (s + 0.25).clamp(0.0, 1.0);
        if (r.course) s = (s + 0.15).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      case 'ランチ':
        final isLunch = r.lunchFromApi || r.isLunchAvailable;
        double s = isLunch ? 1.0 : 0.25;
        if (r.category == 'カフェ') s = (s + 0.15).clamp(0.0, 1.0);
        return s;

      case '合コン':
        double s = switch (r.category) {
          'イタリアン' || 'フレンチ' => 1.0,
          'カフェ' => 0.80,
          '韓国料理' => 0.80,
          '和食' => 0.75,
          'バー' => 0.70,
          '居酒屋' => 0.55,
          'ラーメン' || '中華' => 0.20,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) s = (s + 0.20).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      case '歓迎会':
        double s = switch (r.category) {
          '居酒屋' => 1.0,
          '和食' => 0.90,
          '中華' || '洋食' => 0.70,
          '焼肉' => 0.65,
          'カフェ' || 'フレンチ' => 0.20,
          _ => 0.55,
        };
        if (r.hasPrivateRoom) s = (s + 0.20).clamp(0.0, 1.0);
        if (r.course && r.freeDrink) {
          s = (s + 0.25).clamp(0.0, 1.0);
        } else if (r.course || r.freeDrink) {
          s = (s + 0.12).clamp(0.0, 1.0);
        }
        return s;

      case 'デート':
        double s = switch (r.category) {
          'フレンチ' => 1.0,
          'イタリアン' => 0.95,
          'カフェ' => 0.80,
          '和食' => 0.80,
          'バー' => 0.60,
          '居酒屋' => 0.25,
          'ラーメン' || '焼肉' || '中華' => 0.10,
          _ => 0.50,
        };
        if (r.hasPrivateRoom) s = (s + 0.25).clamp(0.0, 1.0);
        if (r.nonSmoking) s = (s + 0.10).clamp(0.0, 1.0);
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty) s = (s + 0.10).clamp(0.0, 1.0);
        return s;

      default:
        return 0.5;
    }
  }

}
