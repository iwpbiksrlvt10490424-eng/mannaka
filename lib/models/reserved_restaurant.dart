import '../config/secrets.dart';
import '../utils/photo_ref.dart';

class ReservedRestaurant {
  const ReservedRestaurant({
    required this.id,
    required this.restaurantName,
    required this.category,
    required this.reservedAt,
    this.address = '',
    this.hotpepperUrl,
    this.imageUrl,
    this.photoRefs = const [],
    this.lat,
    this.lng,
    this.nearestStation = '',
    this.groupNames = const [],
  });

  final String id;
  final String restaurantName;
  final String category;
  final DateTime reservedAt;
  final String address;
  final String? hotpepperUrl;
  final String? imageUrl;

  /// 複数枚写真の参照（API キーを含まない形）。
  /// 表示時に Secrets.placesApiKey で URL 化する。
  final List<String> photoRefs;
  final double? lat;
  final double? lng;
  final String nearestStation; // 最寄り駅名（シェア用）
  final List<String> groupNames;

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantName': restaurantName,
        'category': category,
        'reservedAt': reservedAt.toIso8601String(),
        'address': address,
        'hotpepperUrl': hotpepperUrl,
        'imageUrl': imageUrl == null ? null : PhotoRef.toRef(imageUrl!),
        if (photoRefs.isNotEmpty) 'photoRefs': photoRefs,
        'lat': lat,
        'lng': lng,
        'nearestStation': nearestStation,
        'groupNames': groupNames,
      };

  factory ReservedRestaurant.fromJson(Map<String, dynamic> j) =>
      ReservedRestaurant(
        id: j['id'] as String,
        restaurantName: j['restaurantName'] as String,
        category: j['category'] as String? ?? '',
        reservedAt: DateTime.parse(j['reservedAt'] as String),
        address: j['address'] as String? ?? '',
        hotpepperUrl: j['hotpepperUrl'] as String?,
        imageUrl: (j['imageUrl'] as String?) == null
            ? null
            : PhotoRef.toUrl(j['imageUrl'] as String,
                googleApiKey: Secrets.placesApiKey),
        photoRefs: (j['photoRefs'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        nearestStation: j['nearestStation'] as String? ?? '',
        groupNames: List<String>.from(j['groupNames'] as List? ?? []),
      );
}
