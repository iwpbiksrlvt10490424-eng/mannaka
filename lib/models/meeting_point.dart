class MeetingPoint {
  const MeetingPoint({
    required this.stationIndex,
    required this.stationName,
    required this.stationEmoji,
    required this.totalMinutes,
    required this.maxMinutes,
    required this.minMinutes,
    required this.averageMinutes,
    required this.fairnessScore,
    required this.overallScore,
    required this.participantTimes,
    this.stdDev = 0,
  });

  final int stationIndex;
  final String stationName;
  final String stationEmoji;
  final int totalMinutes;
  final int maxMinutes;
  final int minMinutes;
  final double averageMinutes;
  final double fairnessScore; // 0-1, 高いほど公平
  final double overallScore;
  final Map<String, int> participantTimes; // name → minutes
  final double stdDev;

  int get timeDifference => maxMinutes - minMinutes;

  String get fairnessLabel {
    if (fairnessScore >= 0.85) return '最もフェア';
    if (fairnessScore >= 0.65) return 'フェア';
    return '要確認';
  }

  String get fairnessEmoji {
    if (fairnessScore >= 0.85) return '⭐';
    if (fairnessScore >= 0.65) return '👍';
    return '⚠️';
  }
}
