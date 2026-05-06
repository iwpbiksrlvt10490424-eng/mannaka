import '../config/secrets.dart';
import '../utils/photo_ref.dart';

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
    this.photoRefs = const [],
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

  /// 複数枚写真の参照（API キーを含まない形）。表示時に Secrets で URL 化。
  final List<String> photoRefs;
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
        'imageUrl': imageUrl == null ? null : PhotoRef.toRef(imageUrl!),
        if (photoRefs.isNotEmpty) 'photoRefs': photoRefs,
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
      );
}
