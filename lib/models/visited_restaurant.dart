class VisitedRestaurant {
  const VisitedRestaurant({
    required this.id,
    required this.restaurantName,
    required this.category,
    required this.visitedAt,
    required this.groupNames,
    this.address = '',
    this.nearestStation = '',
    this.hotpepperUrl,
    this.imageUrl,
    this.lat,
    this.lng,
  });

  final String id;
  final String restaurantName;
  final String category;
  final DateTime visitedAt;
  final List<String> groupNames;
  final String address;
  final String nearestStation;
  final String? hotpepperUrl;
  final String? imageUrl;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantName': restaurantName,
        'category': category,
        'visitedAt': visitedAt.toIso8601String(),
        'groupNames': groupNames,
        'address': address,
        'nearestStation': nearestStation,
        'hotpepperUrl': hotpepperUrl,
        'imageUrl': imageUrl,
        'lat': lat,
        'lng': lng,
      };

  factory VisitedRestaurant.fromJson(Map<String, dynamic> j) =>
      VisitedRestaurant(
        id: j['id'] as String,
        restaurantName: j['restaurantName'] as String,
        category: j['category'] as String? ?? '',
        visitedAt: DateTime.parse(j['visitedAt'] as String),
        groupNames: List<String>.from(j['groupNames'] as List? ?? []),
        address: j['address'] as String? ?? '',
        nearestStation: j['nearestStation'] as String? ?? '',
        hotpepperUrl: j['hotpepperUrl'] as String?,
        imageUrl: j['imageUrl'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}
