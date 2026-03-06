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

  String get ratingStr => rating.toStringAsFixed(1);

  String get priceStr => '¥${_formatNumber(priceAvg)}〜';

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
