class SavedGroup {
  const SavedGroup({
    required this.id,
    required this.name,
    required this.memberNames,
    required this.createdAt,
    this.memberStations = const [],
    this.memberStationIndices = const [],
  });

  final String id;
  final String name;
  final List<String> memberNames;
  final DateTime createdAt;
  /// 各メンバーの駅名（null = 未設定）
  final List<String?> memberStations;
  /// 各メンバーの kStations インデックス（null = kStations 未収録）
  final List<int?> memberStationIndices;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberNames': memberNames,
        'createdAt': createdAt.toIso8601String(),
        'memberStations': memberStations,
        'memberStationIndices': memberStationIndices,
      };

  factory SavedGroup.fromJson(Map<String, dynamic> j) => SavedGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        memberNames: List<String>.from(j['memberNames'] as List),
        createdAt: DateTime.parse(j['createdAt'] as String),
        memberStations: j['memberStations'] != null
            ? List<String?>.from(j['memberStations'] as List)
            : const [],
        memberStationIndices: j['memberStationIndices'] != null
            ? List<int?>.from((j['memberStationIndices'] as List)
                .map((e) => e as int?))
            : const [],
      );
}
