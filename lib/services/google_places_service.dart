import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import '../services/location_service.dart';

/// Google Places API (New) Nearby Search を使ったレストラン検索。
/// Hotpepper 未掲載店（個人経営・町の名店）を補うために並列取得する。
///
/// 注意:
///  - 従量課金（Places API (New) は legacy より安く、field mask によって変動）
///  - GCP Billing の有効化と Places API (New) の有効化が必要
///  - キーの API 制限に Places API (New) を含めること
class GooglePlacesService {
  static const _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';

  /// 返してほしいフィールドを絞って課金を最小化する（field mask）。
  static const _fieldMask =
      'places.id,places.displayName,places.location,places.rating,'
      'places.userRatingCount,places.priceLevel,places.types,'
      'places.formattedAddress,places.photos';

  /// 指定座標周辺のお店を検索。最大 20 件返る。
  /// [category] を渡すと Places API (New) の includedTypes で
  /// 細かいジャンル（italian_restaurant 等）に絞る。
  static Future<List<Restaurant>> searchNearby({
    required String apiKey,
    required double lat,
    required double lng,
    // 500m = 徒歩6-7分。駅を選んだとき、隣接駅の店が入らないように
    // その駅エリアに限定する（例: 大崎検索で 852m 先の五反田の店を除外）。
    int radiusMeters = 500,
    String? category,
  }) async {
    if (apiKey.isEmpty) return [];
    final includedTypes = _categoryToIncludedTypes(category);
    final body = jsonEncode({
      // includedPrimaryTypes: 主要分類が restaurant 系の店だけに絞る。
      // includedTypes だと、ホテル（ロビーにレストランを持つ）等も混ざる。
      'includedPrimaryTypes': includedTypes,
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusMeters.toDouble(),
        },
      },
      'languageCode': 'ja',
    });
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        developer.log(
          '[GooglePlaces] HTTP ${res.statusCode}',
          name: 'GooglePlacesService',
        );
        return [];
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final places = (json['places'] as List?) ?? [];
      developer.log(
        '[GooglePlaces] 取得: ${places.length}件 (lat=$lat, lng=$lng)',
        name: 'GooglePlacesService',
      );
      return places
          .map((p) => _mapPlace(p as Map<String, dynamic>, apiKey, category))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      developer.log(
        '[GooglePlaces] searchNearby failed - ${e.runtimeType}',
        name: 'GooglePlacesService',
        error: e,
      );
      return [];
    }
  }

  static Restaurant? _mapPlace(
    Map<String, dynamic> p,
    String apiKey,
    String? requestedCategory,
  ) {
    final id = p['id']?.toString();
    final displayName = (p['displayName'] as Map?)?['text']?.toString();
    if (id == null || displayName == null || displayName.isEmpty) {
      return null;
    }

    final loc = p['location'] as Map?;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();

    // priceLevel は enum 文字列で返る
    final priceLevel = p['priceLevel']?.toString() ?? '';
    final priceAvg = switch (priceLevel) {
      'PRICE_LEVEL_FREE' => 500,
      'PRICE_LEVEL_INEXPENSIVE' => 1500,
      'PRICE_LEVEL_MODERATE' => 3000,
      'PRICE_LEVEL_EXPENSIVE' => 5000,
      'PRICE_LEVEL_VERY_EXPENSIVE' => 10000,
      _ => 0, // 不明時は 0（フィルタで素通り）
    };
    final priceLabel = switch (priceLevel) {
      'PRICE_LEVEL_FREE' => '¥〜500',
      'PRICE_LEVEL_INEXPENSIVE' => '¥〜1,500',
      'PRICE_LEVEL_MODERATE' => '¥1,500〜3,000',
      'PRICE_LEVEL_EXPENSIVE' => '¥3,000〜5,000',
      'PRICE_LEVEL_VERY_EXPENSIVE' => '¥5,000〜',
      _ => '',
    };

    final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (p['userRatingCount'] as num?)?.toInt() ?? 0;
    final types = (p['types'] as List?)?.cast<String>() ?? [];
    // ユーザーが指定したカテゴリ（例: 居酒屋）があればそれを優先する。
    // Google の types からの自動マッピングだと「居酒屋」のような日本特有カテゴリに
    // マップできず、結果的にクライアント側の category フィルタで除外されてしまうため。
    final category = requestedCategory ?? _typeToCategory(types);
    final emoji = _categoryEmoji(category);

    final stationIdx = (lat != null && lng != null)
        ? LocationService.nearestStationIndex(lat, lng)
        : 0;

    // photos は `name` フィールドが "places/PLACE_ID/photos/PHOTO_NAME" 形式
    // media エンドポイントで画像取得できる。最大 5 枚を imageUrls に格納する。
    final photosRaw = p['photos'] as List?;
    final photoUrls = <String>[];
    if (photosRaw != null) {
      for (final ph in photosRaw) {
        if (photoUrls.length >= 5) break;
        if (ph is! Map) continue;
        final photoName = ph['name']?.toString();
        if (photoName == null || photoName.isEmpty) continue;
        photoUrls.add(
          'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=800&key=$apiKey',
        );
      }
    }
    final imageUrl = photoUrls.isNotEmpty ? photoUrls.first : null;

    return Restaurant(
      id: 'gp_$id',
      name: displayName,
      stationIndex: stationIdx,
      category: category,
      rating: rating,
      reviewCount: reviewCount,
      priceLabel: priceLabel,
      priceAvg: priceAvg,
      tags: const [],
      emoji: emoji,
      description: '',
      distanceMinutes: 5,
      address: p['formattedAddress']?.toString() ?? '',
      openHours: '',
      isReservable: false,
      isFemalePopular: category == 'カフェ' ||
          category == 'イタリアン' ||
          category == 'フレンチ',
      hasPrivateRoom: false,
      lat: lat,
      lng: lng,
      hotpepperUrl: null,
      imageUrl: imageUrl,
      imageUrls: photoUrls,
      accessInfo: '',
      stationName: '',
      sourceApi: 'google_places',
      confidenceLevel: 'medium',
      ratingConfidence: reviewCount > 0 ? 'known' : 'unknown',
      reviewConfidence: reviewCount > 0 ? 'known' : 'unknown',
      planInfoConfidence: 'unknown',
    );
  }

  /// Google Places の types から日本語カテゴリ名へマップする
  static String _typeToCategory(List<String> types) {
    // cuisine-specific 優先
    if (types.contains('italian_restaurant')) return 'イタリアン';
    if (types.contains('french_restaurant')) return 'フレンチ';
    if (types.contains('japanese_restaurant') ||
        types.contains('sushi_restaurant') ||
        types.contains('ramen_restaurant')) {
      return '和食';
    }
    if (types.contains('chinese_restaurant')) return '中華';
    if (types.contains('korean_restaurant') ||
        types.contains('barbecue_restaurant')) {
      return '焼肉';
    }
    if (types.contains('cafe') || types.contains('bakery')) return 'カフェ';
    if (types.contains('bar') || types.contains('night_club')) return 'バー';
    if (types.contains('meal_takeaway') || types.contains('meal_delivery')) {
      return '洋食';
    }
    if (types.contains('restaurant')) return 'レストラン';
    return 'その他';
  }

  /// 日本語カテゴリ名 → Places API (New) の includedTypes 配列
  /// 指定なしや未対応カテゴリは広く 'restaurant' で検索する。
  static List<String> _categoryToIncludedTypes(String? category) {
    switch (category) {
      case 'イタリアン':
        return ['italian_restaurant'];
      case 'フレンチ':
        return ['french_restaurant'];
      case '和食':
        return ['japanese_restaurant', 'sushi_restaurant', 'ramen_restaurant'];
      case 'ラーメン':
        return ['ramen_restaurant'];
      case '中華':
        return ['chinese_restaurant'];
      case '焼肉':
      case '韓国料理':
        return ['korean_restaurant', 'barbecue_restaurant'];
      case 'カフェ':
        return ['cafe', 'coffee_shop'];
      case 'バー':
        return ['bar'];
      case '居酒屋':
        return ['bar', 'restaurant']; // Google に 居酒屋 type がないので近似
      case '洋食':
      case 'レストラン':
      default:
        return ['restaurant'];
    }
  }

  static String _categoryEmoji(String category) => switch (category) {
        'カフェ' => '☕',
        'バー' => '🍸',
        '居酒屋' => '🍺',
        '和食' => '🍱',
        '洋食' => '🍽️',
        'イタリアン' => '🍝',
        'フレンチ' => '🥂',
        'レストラン' => '🍴',
        _ => '🍴',
      };
}
