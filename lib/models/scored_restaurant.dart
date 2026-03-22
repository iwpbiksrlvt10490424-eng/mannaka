import '../data/station_data.dart';
import 'restaurant.dart';

/// 重心スコアリング済みレストラン
class ScoredRestaurant {
  const ScoredRestaurant({
    required this.restaurant,
    required this.score,
    required this.distanceKm,
    required this.participantDistances,
    required this.fairnessScore,
    this.curationLabel = '',
  });

  final Restaurant restaurant;
  final double score;          // 総合スコア 0-1
  final double distanceKm;    // 重心からの直線距離 (km)
  final Map<String, double> participantDistances; // 参加者名 → 距離(km)
  final double fairnessScore; // 公平性スコア 0-1
  final String curationLabel; // おすすめ理由ラベル（例: "予約OK · 女性人気"）

  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()}m';
    return '${distanceKm.toStringAsFixed(1)}km';
  }

  String get fairnessLabel {
    if (fairnessScore >= 0.85) return '最もフェア';
    if (fairnessScore >= 0.65) return 'フェア';
    return '要確認';
  }

  String get areaLabel => '${kStations[restaurant.stationIndex]}駅エリア';
}
