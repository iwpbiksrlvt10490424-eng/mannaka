class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.stationIndex,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.priceLabel,
    required this.priceAvg,
    required this.tags,
    required this.emoji,
    required this.description,
    required this.distanceMinutes,
    required this.address,
    required this.openHours,
    this.isReservable = true,
    this.isFemalePopular = false,
    this.hasPrivateRoom = false,
    this.occasionTags = const [],
  });

  final String id;
  final String name;
  final int stationIndex;
  final String category;
  final double rating;
  final int reviewCount;
  final String priceLabel;
  final int priceAvg;
  final List<String> tags;
  final String emoji;
  final String description;
  final int distanceMinutes;
  final String address;
  final String openHours;
  final bool isReservable;
  final bool isFemalePopular;
  final bool hasPrivateRoom;
  // 女子会/誕生日/ランチ会/合コン/歓迎会
  final List<String> occasionTags;

  String get ratingStr => rating.toStringAsFixed(1);
  String get priceStr => '¥${_formatNumber(priceAvg)}〜';

  // openHoursから自動判定
  bool get isLunchAvailable {
    final match = RegExp(r'^(\d+):').firstMatch(openHours);
    if (match == null) return true;
    final openHour = int.tryParse(match.group(1) ?? '') ?? 0;
    return openHour <= 12;
  }

  bool get isDinnerAvailable {
    return openHours.contains('翌') ||
        openHours.contains('23:') ||
        openHours.contains('22:') ||
        openHours.contains('21:') ||
        openHours.contains('20:') ||
        openHours.contains('19:') ||
        openHours.contains('18:') ||
        openHours.contains('17:');
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
