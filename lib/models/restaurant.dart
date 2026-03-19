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
    this.lat,
    this.lng,
    this.hotpepperUrl,
    this.imageUrl,
    this.imageUrls = const [],
    this.accessInfo = '',
    this.stationName = '',
    this.closeDay = '',
    this.nonSmoking = false,
    this.freeDrink = false,
    this.freeFood = false,
    this.lunchFromApi = false,
    this.wifi = false,
    this.course = false,
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
  final List<String> occasionTags;
  final double? lat;
  final double? lng;
  final String? hotpepperUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final String accessInfo;
  final String stationName;
  final String closeDay;
  final bool nonSmoking;
  final bool freeDrink;
  final bool freeFood;
  final bool lunchFromApi;
  final bool wifi;
  final bool course;

  String get ratingStr => rating.toStringAsFixed(1);
  String get priceStr => '¥${_formatNumber(priceAvg)}〜';

  bool isOpenNow(DateTime now) {
    if (openHours.isEmpty) return false;
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})[^-]*-[^-]*(\d{1,2}):(\d{2})').firstMatch(openHours);
    if (timeMatch == null) return false;
    final openH = int.parse(timeMatch.group(1)!);
    final openM = int.parse(timeMatch.group(2)!);
    final closeH = int.parse(timeMatch.group(3)!);
    final closeM = int.parse(timeMatch.group(4)!);
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = openH * 60 + openM;
    var closeMinutes = closeH * 60 + closeM;
    if (closeMinutes < openMinutes) closeMinutes += 24 * 60;
    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }

  bool get isLunchAvailable {
    if (lunchFromApi) return true;
    final match = RegExp(r'^(\d+):').firstMatch(openHours);
    if (match == null) return false; // 時刻不明 → 保守的にfalse
    final openHour = int.tryParse(match.group(1) ?? '') ?? 0;
    if (openHour <= 5) return false;
    return openHour <= 12;
  }

  bool get isDinnerAvailable {
    if (openHours.contains('翌')) return true;
    // 終了時刻を正規表現で抽出して判定（例: "9:00〜17:00" → 閉店17時 → ディナー不可）
    final match = RegExp(r'[〜~\-]\s*(\d{1,2}):\d{2}').firstMatch(openHours);
    if (match != null) {
      final closeHour = int.tryParse(match.group(1)!) ?? 0;
      return closeHour >= 18 || closeHour <= 5; // 18時以降 or 深夜5時以前（深夜営業）
    }
    return false;
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
