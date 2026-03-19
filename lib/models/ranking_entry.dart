class RankingEntry {
  const RankingEntry({
    required this.stationName,
    required this.stationIndex,
    required this.searchCount,
    required this.rank,
  });

  final String stationName;
  final int stationIndex;
  final int searchCount;
  final int rank;

  factory RankingEntry.fromMap(Map<String, dynamic> map, int rank) {
    return RankingEntry(
      stationName: (map['station_name'] as String?) ?? '',
      stationIndex: (map['station_index'] as int?) ?? 0,
      searchCount: (map['count'] as int?) ?? 0,
      rank: rank,
    );
  }
}
