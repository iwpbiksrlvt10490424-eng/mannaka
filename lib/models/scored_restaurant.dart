import '../data/station_data.dart';
import 'restaurant.dart';

/// 4軸スコアリング済みレストラン（Uber Eats式 集合最適化）
class ScoredRestaurant {
  const ScoredRestaurant({
    required this.restaurant,
    required this.score,
    required this.distanceKm,
    required this.participantDistances,
    required this.fairnessScore,
    this.curationLabel = '',
    this.accessScore = 0,
    this.conditionScore = 0,
    this.qualityScore = 0,
    this.usabilityScore = 0,
  });

  final Restaurant restaurant;
  final double score;          // 総合スコア 0-1
  final double distanceKm;    // 重心からの直線距離 (km)
  final Map<String, double> participantDistances; // 参加者名 → 距離(km)
  final double fairnessScore; // 公平性スコア 0-1
  final String curationLabel; // おすすめ理由ラベル（なぜこの店か）

  // 4軸スコア内訳
  final double accessScore;     // 集合しやすさ（駅徒歩時間）
  final double conditionScore;  // 条件一致（ジャンル・予算・シーン）
  final double qualityScore;    // 品質（評価・写真・コース等）
  final double usabilityScore;  // 利用しやすさ（予約可・個室・禁煙）

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
