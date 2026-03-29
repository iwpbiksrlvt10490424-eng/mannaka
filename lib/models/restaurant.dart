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
    this.sourceApi = 'mock',
    this.confidenceLevel = 'high',
    this.secondaryGenres = const [],
    this.blockedGenres = const [],
    this.ratingConfidence = 'known',
    this.reviewConfidence = 'known',
    this.planInfoConfidence = 'known',
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

  // APIソース管理
  final String sourceApi;        // 'hotpepper' | 'foursquare' | 'overpass' | 'mock'
  final String confidenceLevel;  // 'high' | 'medium' | 'low'

  // ── ジャンル詳細 ──────────────────────────────────────────────────
  final List<String> secondaryGenres;   // 副ジャンル（例: 居酒屋でも洋食系）
  final List<String> blockedGenres;     // このジャンル表示では出すべきでない
  // ── 項目別信頼度（'known' | 'unknown'） ──────────────────────────
  final String ratingConfidence;   // 評価の信頼度
  final String reviewConfidence;   // レビュー件数の信頼度
  final String planInfoConfidence; // コース/飲放/食放情報の信頼度

  /// 情報が十分そろっている店かどうか（ラベル付与の前提条件）
  bool get hasAdequateInfo =>
      ratingConfidence == 'known' &&
      reviewConfidence == 'known' &&
      (reviewCount > 0 || confidenceLevel == 'high');

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stationIndex': stationIndex,
    'category': category,
    'rating': rating,
    'reviewCount': reviewCount,
    'priceLabel': priceLabel,
    'priceAvg': priceAvg,
    'tags': tags,
    'emoji': emoji,
    'description': description,
    'distanceMinutes': distanceMinutes,
    'address': address,
    'openHours': openHours,
    'isReservable': isReservable,
    'isFemalePopular': isFemalePopular,
    'hasPrivateRoom': hasPrivateRoom,
    'occasionTags': occasionTags,
    'lat': lat,
    'lng': lng,
    'hotpepperUrl': hotpepperUrl,
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'accessInfo': accessInfo,
    'stationName': stationName,
    'closeDay': closeDay,
    'nonSmoking': nonSmoking,
    'freeDrink': freeDrink,
    'freeFood': freeFood,
    'lunchFromApi': lunchFromApi,
    'wifi': wifi,
    'course': course,
    'sourceApi': sourceApi,
    'confidenceLevel': confidenceLevel,
    'secondaryGenres': secondaryGenres,
    'blockedGenres': blockedGenres,
    'ratingConfidence': ratingConfidence,
    'reviewConfidence': reviewConfidence,
    'planInfoConfidence': planInfoConfidence,
  };

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
    id: j['id'] as String,
    name: j['name'] as String,
    stationIndex: j['stationIndex'] as int,
    category: j['category'] as String,
    rating: (j['rating'] as num).toDouble(),
    reviewCount: j['reviewCount'] as int,
    priceLabel: j['priceLabel'] as String,
    priceAvg: j['priceAvg'] as int,
    tags: List<String>.from(j['tags'] as List),
    emoji: j['emoji'] as String,
    description: j['description'] as String,
    distanceMinutes: j['distanceMinutes'] as int,
    address: j['address'] as String,
    openHours: j['openHours'] as String,
    isReservable: j['isReservable'] as bool? ?? true,
    isFemalePopular: j['isFemalePopular'] as bool? ?? false,
    hasPrivateRoom: j['hasPrivateRoom'] as bool? ?? false,
    occasionTags: List<String>.from(j['occasionTags'] as List? ?? []),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    hotpepperUrl: j['hotpepperUrl'] as String?,
    imageUrl: j['imageUrl'] as String?,
    imageUrls: List<String>.from(j['imageUrls'] as List? ?? []),
    accessInfo: j['accessInfo'] as String? ?? '',
    stationName: j['stationName'] as String? ?? '',
    closeDay: j['closeDay'] as String? ?? '',
    nonSmoking: j['nonSmoking'] as bool? ?? false,
    freeDrink: j['freeDrink'] as bool? ?? false,
    freeFood: j['freeFood'] as bool? ?? false,
    lunchFromApi: j['lunchFromApi'] as bool? ?? false,
    wifi: j['wifi'] as bool? ?? false,
    course: j['course'] as bool? ?? false,
    sourceApi: j['sourceApi'] as String? ?? 'mock',
    confidenceLevel: j['confidenceLevel'] as String? ?? 'high',
    secondaryGenres: List<String>.from(j['secondaryGenres'] as List? ?? []),
    blockedGenres: List<String>.from(j['blockedGenres'] as List? ?? []),
    ratingConfidence: j['ratingConfidence'] as String? ?? 'known',
    reviewConfidence: j['reviewConfidence'] as String? ?? 'known',
    planInfoConfidence: j['planInfoConfidence'] as String? ?? 'known',
  );
}
