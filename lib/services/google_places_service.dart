import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  static Future<List<Restaurant>> searchNearby({
    required String apiKey,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    if (apiKey.isEmpty) return [];
    final body = jsonEncode({
      'includedTypes': ['restaurant'],
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
        debugPrint('[GooglePlaces] HTTP ${res.statusCode}');
        return [];
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final places = (json['places'] as List?) ?? [];
      debugPrint('[GooglePlaces] 取得: ${places.length}件 (lat=$lat, lng=$lng)');
      return places
          .map((p) => _mapPlace(p as Map<String, dynamic>, apiKey))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      debugPrint('[GooglePlaces] searchNearby failed - ${e.runtimeType}');
      return [];
    }
  }

  static Restaurant? _mapPlace(Map<String, dynamic> p, String apiKey) {
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
    final category = _typeToCategory(types);
    final emoji = _categoryEmoji(category);

    final stationIdx = (lat != null && lng != null)
        ? LocationService.nearestStationIndex(lat, lng)
        : 0;

    // photos は `name` フィールドが "places/PLACE_ID/photos/PHOTO_NAME" 形式
    // media エンドポイントで画像取得できる
    final photos = p['photos'] as List?;
    String? imageUrl;
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first as Map?;
      final photoName = first?['name']?.toString();
      if (photoName != null && photoName.isNotEmpty) {
        imageUrl =
            'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=800&key=$apiKey';
      }
    }

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
      imageUrls: imageUrl != null ? [imageUrl] : const [],
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
    if (types.contains('cafe')) return 'カフェ';
    if (types.contains('bakery')) return 'カフェ';
    if (types.contains('bar') || types.contains('night_club')) return 'バー';
    if (types.contains('meal_takeaway') || types.contains('meal_delivery')) {
      return '洋食';
    }
    if (types.contains('restaurant')) return 'レストラン';
    return 'その他';
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
