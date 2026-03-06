class Participant {
  const Participant({
    required this.id,
    required this.name,
    this.stationIndex,
    this.stationName,
  });

  final String id;
  final String name;
  final int? stationIndex;
  final String? stationName;

  bool get hasStation => stationIndex != null;

  Participant copyWith({
    String? id,
    String? name,
    int? stationIndex,
    String? stationName,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      stationIndex: stationIndex ?? this.stationIndex,
      stationName: stationName ?? this.stationName,
    );
  }

  Participant clearStation() {
    return Participant(id: id, name: name);
  }
}
