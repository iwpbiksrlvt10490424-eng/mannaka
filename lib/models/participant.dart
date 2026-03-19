class Participant {
  const Participant({
    required this.id,
    required this.name,
    this.stationIndex,
    this.stationName,
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final int? stationIndex;
  final String? stationName;
  final double? lat;
  final double? lng;

  bool get hasStation => stationIndex != null;
  bool get hasLocation => lat != null && lng != null;

  Participant copyWith({
    String? id,
    String? name,
    int? stationIndex,
    String? stationName,
    double? lat,
    double? lng,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      stationIndex: stationIndex ?? this.stationIndex,
      stationName: stationName ?? this.stationName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  Participant clearStation() {
    return Participant(id: id, name: name);
  }
}
