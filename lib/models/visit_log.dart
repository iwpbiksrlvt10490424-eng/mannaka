import 'dart:convert';

class VisitLog {
  const VisitLog({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.category,
    required this.emoji,
    required this.visitedAt,
    this.userRating,
    this.memo = '',
    this.imageUrl,
    this.address = '',
    this.hotpepperUrl,
  });

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String category;
  final String emoji;
  final DateTime visitedAt;
  final int? userRating; // 1-5
  final String memo;
  final String? imageUrl;
  final String address;
  final String? hotpepperUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'category': category,
        'emoji': emoji,
        'visitedAt': visitedAt.toIso8601String(),
        'userRating': userRating,
        'memo': memo,
        'imageUrl': imageUrl,
        'address': address,
        'hotpepperUrl': hotpepperUrl,
      };

  factory VisitLog.fromJson(Map<String, dynamic> j) => VisitLog(
        id: j['id'] as String,
        restaurantId: j['restaurantId'] as String,
        restaurantName: j['restaurantName'] as String,
        category: j['category'] as String,
        emoji: j['emoji'] as String,
        visitedAt: DateTime.parse(j['visitedAt'] as String),
        userRating: j['userRating'] as int?,
        memo: j['memo'] as String? ?? '',
        imageUrl: j['imageUrl'] as String?,
        address: j['address'] as String? ?? '',
        hotpepperUrl: j['hotpepperUrl'] as String?,
      );

  static String encodeList(List<VisitLog> logs) =>
      jsonEncode(logs.map((l) => l.toJson()).toList());

  static List<VisitLog> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((j) => VisitLog.fromJson(j as Map<String, dynamic>)).toList();
  }
}
