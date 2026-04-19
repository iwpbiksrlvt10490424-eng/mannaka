import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import '../services/location_service.dart';

class HotpepperService {
  static const String _base =
      'https://webservice.recruit.co.jp/hotpepper/gourmet/v1/';

  /// カテゴリ名 → Hotpepper ジャンルコードのマッピング
  static const Map<String, String> _categoryToGenre = {
    '居酒屋': 'G001',
    'バー': 'G002',
    '和食': 'G004',
    '洋食': 'G005',
    'イタリアン': 'G006',
    '中華': 'G007',
    '焼肉': 'G008',
    '韓国料理': 'G009',
    'ラーメン': 'G013',
    'カフェ': 'G016',
    'フレンチ': 'G036',
  };

  /// カテゴリ名からHotpepperジャンルコードを返す（未対応なら null）
  static String? categoryToGenreCode(String category) =>
      _categoryToGenre[category];

  /// Hotpepper予算コード（budget param 用）
  /// 参考: https://webservice.recruit.co.jp/doc/hotpepper/reference.html#budget
  /// - B010: 〜500円 / B009: 501〜1000円 / B011: 1001〜1500円
  /// - B001: 1501〜2000円 / B002: 2001〜3000円 / B003: 3001〜4000円
  /// - B008: 4001〜5000円 / B004: 5001〜7000円 / B005: 7001〜10000円
  /// - B006: 10001〜15000円 / B012: 15001〜20000円 / B013: 20001〜30000円 / B014: 30001円〜
  ///
  /// [maxBudget] は UI の選択値（円）で、以下の規約:
  /// - 正の数 → その金額以下を意味（例: 3000 → 3000円以下のバンドを全て含める）
  /// - 負の数 → その絶対値以上を意味（例: -10000 → 10000円以上）
  /// - 0 → 指定なし
  static String? maxBudgetToCodes(int maxBudget) {
    if (maxBudget == 0) return null;
    if (maxBudget > 0) {
      // 以下: 低価格帯から maxBudget を含むバンドまで
      if (maxBudget <= 1500) return 'B010,B009,B011';
      if (maxBudget <= 3000) return 'B010,B009,B011,B001,B002';
      if (maxBudget <= 5000) return 'B010,B009,B011,B001,B002,B003,B008';
      if (maxBudget <= 10000) {
        return 'B010,B009,B011,B001,B002,B003,B008,B004,B005';
      }
      // それ以上は全帯
      return null;
    }
    // 以上（maxBudget = -10000 は 10000円以上）
    final minBudget = maxBudget.abs();
    if (minBudget >= 30000) return 'B014';
    if (minBudget >= 20000) return 'B013,B014';
    if (minBudget >= 15000) return 'B012,B013,B014';
    if (minBudget >= 10000) return 'B006,B012,B013,B014';
    return null;
  }

  static Future<List<Restaurant>> searchNearCentroid({
    required String apiKey,
    required double lat,
    required double lng,
    // 3 = 1km。Hotpepper は有料掲載のみで店舗密度が低いため、
    // 500m だと予約可能な店が極端に少なくなる。1km の徒歩圏を取り
    // 予約動線のあるお店を確保する。Google 側はエリア純度のため 500m に
    // 絞っており、役割分担で両立させる設計。
    int range = 3,
    int count = 100,  // 最大100件取得
    String? genre,         // カテゴリ（Hotpepperジャンルコード）
    int maxBudget = 0,     // 予算（円、上記 maxBudgetToCodes 参照）
    bool privateRoom = false,  // 個室あり
    bool freeDrink = false,    // 飲み放題あり
    bool freeFood = false,     // 食べ放題あり
    bool lunch = false,        // ランチあり
    bool nonSmoking = false,   // 禁煙席あり
    bool course = false,       // コースあり
    bool card = false,         // カード可
  }) async {
    // maxBudget は Hotpepper API に渡さず、クライアント側 priceAvg で絞る。
    // Hotpepper の budget パラメータは複数コードを並べると 0 件を返すバグ
    // （例: B010,B009,B011,B001,B002 → 0件）があるため、
    // 使わずに取得しクライアント側で priceAvg <= maxBudget で除外する。
    final params = <String, String>{
      'key': apiKey,
      'lat': lat.toString(),
      'lng': lng.toString(),
      'range': range.toString(),
      'count': count.toString(),
      'format': 'json',
      if (genre != null) 'genre': genre,
      if (privateRoom) 'private_room': '1',
      if (freeDrink) 'free_drink': '1',
      if (freeFood) 'free_food': '1',
      if (lunch) 'lunch': '1',
      if (nonSmoking) 'non_smoking': '1',
      if (course) 'course': '1',
      if (card) 'card': '1',
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        debugPrint('[HotpepperService] HTTP ${res.statusCode}: ${res.body.substring(0, min(200, res.body.length))}');
        return [];
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final shops = ((json['results'] as Map?)?['shop'] as List?) ?? [];
      debugPrint('[HotpepperService] 取得: ${shops.length}件 (lat=$lat, lng=$lng, range=$range)');
      return shops.map((s) => _mapShop(s as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('HotpepperService: searchNearCentroid failed - ${e.runtimeType}');
      return [];
    }
  }

  static Restaurant _mapShop(Map<String, dynamic> s) {
    final double? shopLat = double.tryParse(s['lat']?.toString() ?? '');
    final double? shopLng = double.tryParse(s['lng']?.toString() ?? '');

    final genreCode = (s['genre'] as Map?)?['code'] ?? '';
    final genreName = (s['genre'] as Map?)?['name'] ?? 'その他';
    final category = _genreToCategory(genreCode, genreName);

    // Hotpepper budget.code → 円換算平均値（各レンジの中央値）
    final budgetCode =
        (s['budget'] as Map?)?['code']?.toString() ?? '';
    final budgetAvg = _budgetCodeToAvg(budgetCode);
    final budgetName =
        (s['budget'] as Map?)?['name']?.toString() ?? '';

    final privateRoom =
        (s['private_room']?.toString() ?? '') == 'あり';
    final card = (s['card']?.toString() ?? '').contains('利用可');
    final hotpepperUrl =
        (s['urls'] as Map?)?['pc']?.toString() ?? '';

    final stationIdx = (shopLat != null && shopLng != null)
        ? LocationService.nearestStationIndex(shopLat, shopLng)
        : 0;

    final hasInfo = (s['catch']?.toString() ?? '').isNotEmpty;
    final rating = hasInfo ? 3.5 : 3.0;

    // pc.l / pc.m / mobile.l はすべて同一画像の異なるサイズ。最大サイズのみ使用。
    final pcPhoto = (s['photo'] as Map?)?['pc'] as Map?;
    final photoL = pcPhoto?['l']?.toString() ?? '';
    final imageUrls = <String>[
      if (photoL.isNotEmpty) photoL,
    ];

    // アクセス情報から徒歩時間を解析
    final access = s['access']?.toString() ?? '';
    final distMatch = RegExp(r'徒歩(\d+)分').firstMatch(access);
    final distanceMinutes = distMatch != null
        ? int.tryParse(distMatch.group(1) ?? '') ?? 5
        : 5;

    // 新フィールド
    final stationName = s['station_name']?.toString() ?? '';
    final closeDay = s['close']?.toString() ?? '';
    final nonSmoking = (s['non_smoking']?.toString() ?? '').contains('禁煙');
    final freeDrink = (s['free_drink']?.toString() ?? '') == 'あり';
    final freeFood = (s['free_food']?.toString() ?? '') == 'あり';
    final lunchFromApi = (s['lunch']?.toString() ?? '') == 'あり';
    final wifi = (s['wifi']?.toString() ?? '') == 'あり';
    final course = (s['course']?.toString() ?? '') == 'あり';

    final tags = <String>[
      if (privateRoom) '個室あり',
      if (card) 'カード可',
      if (freeDrink) '飲み放題',
      if (freeFood) '食べ放題',
      if (lunchFromApi) 'ランチあり',
      if (wifi) 'Wi-Fi',
      if (course) 'コースあり',
      if (nonSmoking) '禁煙',
      if ((s['catch']?.toString() ?? '').isNotEmpty) s['catch'].toString(),
    ].where((t) => t.isNotEmpty).toList();

    return Restaurant(
      id: s['id']?.toString() ?? '',
      name: s['name']?.toString() ?? '',
      stationIndex: stationIdx,
      category: category,
      rating: rating,
      reviewCount: 0,
      priceLabel: budgetName,
      priceAvg: budgetAvg,
      tags: tags,
      emoji: _genreEmoji(genreCode),
      description: s['catch']?.toString() ?? '',
      distanceMinutes: distanceMinutes,
      address: s['address']?.toString() ?? '',
      openHours: s['open']?.toString() ?? '',
      isReservable: hotpepperUrl.isNotEmpty,
      isFemalePopular: category == 'カフェ' || category == 'イタリアン' ||
          category == 'フレンチ' || nonSmoking,
      hasPrivateRoom: privateRoom,
      lat: shopLat,
      lng: shopLng,
      hotpepperUrl: hotpepperUrl.isNotEmpty ? hotpepperUrl : null,
      imageUrl: photoL.isNotEmpty ? photoL : null,
      imageUrls: imageUrls,
      accessInfo: access,
      stationName: stationName,
      closeDay: closeDay,
      nonSmoking: nonSmoking,
      freeDrink: freeDrink,
      freeFood: freeFood,
      lunchFromApi: lunchFromApi,
      wifi: wifi,
      course: course,
      sourceApi: 'hotpepper',
      confidenceLevel: 'high',
      ratingConfidence: 'known',
      reviewConfidence: 'known',
      planInfoConfidence: 'known',
    );
  }

  static String _genreToCategory(String code, String name) =>
      switch (code) {
        'G001' => '居酒屋',
        'G002' => 'バー',
        'G004' => '和食',
        'G005' => '洋食',
        'G006' => 'イタリアン',
        'G007' => '中華',
        'G008' => '焼肉',
        'G009' => '韓国料理',
        'G013' => 'ラーメン',
        'G016' => 'カフェ',
        'G025' => '和食',
        'G036' => 'フレンチ',
        _ => name.length > 6 ? name.substring(0, 6) : name,
      };

  /// budget.code (B001〜B014) を円換算の中央値に変換する。
  /// `budget.average` フィールドは "夜10000〜14999円(税込)" のような
  /// フリーテキストで int としてパースできないため、安定したコードから算出する。
  static int _budgetCodeToAvg(String code) => switch (code) {
        'B010' => 300,     // 〜500円
        'B009' => 750,     // 501〜1000円
        'B011' => 1250,    // 1001〜1500円
        'B001' => 1750,    // 1501〜2000円
        'B002' => 2500,    // 2001〜3000円
        'B003' => 3500,    // 3001〜4000円
        'B008' => 4500,    // 4001〜5000円
        'B004' => 6000,    // 5001〜7000円
        'B005' => 8500,    // 7001〜10000円
        'B006' => 12500,   // 10001〜15000円
        'B012' => 17500,   // 15001〜20000円
        'B013' => 25000,   // 20001〜30000円
        'B014' => 35000,   // 30001円〜
        _ => 0,            // 不明時は 0（フィルタで素通り）
      };

  static String _genreEmoji(String code) => switch (code) {
        'G001' => '🍺',
        'G002' => '🍸',
        'G004' => '🍱',
        'G005' => '🍽️',
        'G006' => '🍝',
        'G007' => '🥟',
        'G008' => '🥩',
        'G009' => '🥘',
        'G013' => '🍜',
        'G016' => '☕',
        'G025' => '🍣',
        'G036' => '🥂',
        _ => '🍴',
      };
}

final hotpepperServiceProvider = Provider<HotpepperService>((ref) => HotpepperService());
