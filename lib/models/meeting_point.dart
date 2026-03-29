class MeetingPoint {
  const MeetingPoint({
    required this.stationIndex,
    required this.stationName,
    required this.stationEmoji,
    required this.lat,
    required this.lng,
    required this.totalMinutes,
    required this.maxMinutes,
    required this.minMinutes,
    required this.averageMinutes,
    required this.fairnessScore,
    required this.overallScore,
    required this.participantTimes,
    this.stdDev = 0,
    this.reason,
  });

  final int stationIndex; // kStations index, or -1 if not in kStations
  final String stationName;
  final String stationEmoji;
  final double lat;
  final double lng;
  final int totalMinutes;
  final int maxMinutes;
  final int minMinutes;
  final double averageMinutes;
  final double fairnessScore;
  final double overallScore;
  final Map<String, int> participantTimes;
  final double stdDev;
  final String? reason;

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
        'lat': lat,
        'lng': lng,
        'totalMinutes': totalMinutes,
        'maxMinutes': maxMinutes,
        'minMinutes': minMinutes,
        'averageMinutes': averageMinutes,
        'fairnessScore': fairnessScore,
        'overallScore': overallScore,
        'participantTimes': participantTimes,
        'stdDev': stdDev,
        'reason': reason,
      };

  factory MeetingPoint.fromJson(Map<String, dynamic> j) => MeetingPoint(
        stationIndex: j['stationIndex'] as int,
        stationName: j['stationName'] as String,
        stationEmoji: j['stationEmoji'] as String,
        lat: (j['lat'] as num? ?? 0.0).toDouble(),
        lng: (j['lng'] as num? ?? 0.0).toDouble(),
        totalMinutes: j['totalMinutes'] as int,
        maxMinutes: j['maxMinutes'] as int,
        minMinutes: j['minMinutes'] as int,
        averageMinutes: (j['averageMinutes'] as num).toDouble(),
        fairnessScore: (j['fairnessScore'] as num).toDouble(),
        overallScore: (j['overallScore'] as num).toDouble(),
        participantTimes: (j['participantTimes'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        stdDev: (j['stdDev'] as num? ?? 0).toDouble(),
        reason: j['reason'] as String?,
      );
}
