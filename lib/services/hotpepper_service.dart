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

  static Future<List<Restaurant>> searchNearCentroid({
    required String apiKey,
    required double lat,
    required double lng,
    int range = 5,    // 5 = 3km（1:300m 2:500m 3:1km 4:2km 5:3km）
    int count = 100,  // 最大100件取得
    String? genre,    // Hotpepperジャンルコード（指定するとサーバーサイド絞り込み）
  }) async {
    final params = <String, String>{
      'key': apiKey,
      'lat': lat.toString(),
      'lng': lng.toString(),
      'range': range.toString(),
      'count': count.toString(),
      'format': 'json',
      if (genre != null) 'genre': genre,
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

    final budgetAvg = int.tryParse(
            ((s['budget'] as Map?)?['average'] ?? '').toString()) ??
        3000;
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
