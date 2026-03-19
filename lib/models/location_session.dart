class LocationSession {
  final String id;
  final String hostName;
  final int slotIndex;
  final String participantName;
  final double? lat;
  final double? lng;
  final bool submitted;

  const LocationSession({
    required this.id,
    required this.hostName,
    required this.slotIndex,
    required this.participantName,
    this.lat,
    this.lng,
    this.submitted = false,
  });

  factory LocationSession.fromMap(String id, Map<String, dynamic> map) {
    return LocationSession(
      id: id,
      hostName: map['hostName'] as String? ?? '',
      slotIndex: map['slotIndex'] as int? ?? 0,
      participantName: map['participantName'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      submitted: map['submitted'] as bool? ?? false,
    );
  }
}
