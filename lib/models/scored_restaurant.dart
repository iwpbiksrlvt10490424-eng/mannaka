import '../data/station_data.dart';
import 'restaurant.dart';

/// スコアリング済みレストラン（集合最適化）
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
    this.trustScore = 0,
    this.appealScore = 0,
    this.planFitScore = 0,
  });

  final Restaurant restaurant;
  final double score;          // 総合スコア 0-1
  final double distanceKm;    // 重心からの直線距離 (km)
  final Map<String, double> participantDistances; // 参加者名 → 距離(km)
  final double fairnessScore; // 公平性スコア 0-1
  final String curationLabel; // おすすめ理由ラベル

  // 4軸スコア内訳
  final double accessScore;     // 集合しやすさ（駅徒歩時間）
  final double conditionScore;  // 条件一致（ジャンル・予算・シーン）
  final double qualityScore;    // 品質総合（trust + appeal + planFit の加重平均）
  final double usabilityScore;  // 純粋な使いやすさ（予約可・個室・禁煙・Wi-Fi）

  // qualityScore の内訳（デバッグ・将来の重み調整用）
  final double trustScore;    // 信頼性（評価 × レビュー件数）
  final double appealScore;   // 魅力（写真・女性人気）
  final double planFitScore;  // プラン適合（コース・飲放・食放）

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
