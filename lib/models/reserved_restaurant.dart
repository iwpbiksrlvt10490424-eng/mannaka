class ReservedRestaurant {
  const ReservedRestaurant({
    required this.id,
    required this.restaurantName,
    required this.category,
    required this.reservedAt,
    this.address = '',
    this.hotpepperUrl,
    this.imageUrl,
    this.lat,
    this.lng,
    this.nearestStation = '',
  });

  final String id;
  final String restaurantName;
  final String category;
  final DateTime reservedAt;
  final String address;
  final String? hotpepperUrl;
  final String? imageUrl;
  final double? lat;
  final double? lng;
  final String nearestStation; // 最寄り駅名（シェア用）

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantName': restaurantName,
        'category': category,
        'reservedAt': reservedAt.toIso8601String(),
        'address': address,
        'hotpepperUrl': hotpepperUrl,
        'imageUrl': imageUrl,
        'lat': lat,
        'lng': lng,
        'nearestStation': nearestStation,
      };

  factory ReservedRestaurant.fromJson(Map<String, dynamic> j) =>
      ReservedRestaurant(
        id: j['id'] as String,
        restaurantName: j['restaurantName'] as String,
        category: j['category'] as String? ?? '',
        reservedAt: DateTime.parse(j['reservedAt'] as String),
        address: j['address'] as String? ?? '',
        hotpepperUrl: j['hotpepperUrl'] as String?,
        imageUrl: j['imageUrl'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        nearestStation: j['nearestStation'] as String? ?? '',
      );
}
