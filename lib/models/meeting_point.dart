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
  final double fairnessScore;
  final double overallScore;
  final Map<String, int> participantTimes;
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

  Map<String, dynamic> toJson() => {
        'stationIndex': stationIndex,
        'stationName': stationName,
        'stationEmoji': stationEmoji,
        'totalMinutes': totalMinutes,
        'maxMinutes': maxMinutes,
        'minMinutes': minMinutes,
        'averageMinutes': averageMinutes,
        'fairnessScore': fairnessScore,
        'overallScore': overallScore,
        'participantTimes': participantTimes,
        'stdDev': stdDev,
      };

  factory MeetingPoint.fromJson(Map<String, dynamic> j) => MeetingPoint(
        stationIndex: j['stationIndex'] as int,
        stationName: j['stationName'] as String,
        stationEmoji: j['stationEmoji'] as String,
        totalMinutes: j['totalMinutes'] as int,
        maxMinutes: j['maxMinutes'] as int,
        minMinutes: j['minMinutes'] as int,
        averageMinutes: (j['averageMinutes'] as num).toDouble(),
        fairnessScore: (j['fairnessScore'] as num).toDouble(),
        overallScore: (j['overallScore'] as num).toDouble(),
        participantTimes: (j['participantTimes'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        stdDev: (j['stdDev'] as num? ?? 0).toDouble(),
      );
}
