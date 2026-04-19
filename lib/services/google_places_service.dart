import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';
import '../services/location_service.dart';

/// Google Places API (Nearby Search legacy) を使ったレストラン検索。
/// Hotpepper が少ない駅・地域で「0件になる」のを防ぐためのフォールバック。
///
/// 注意:
///  - 従量課金（基本 $32/1000req、月 $200 の無料枠あり）
///  - GCP Billing の有効化と Places API の有効化が必要
///  - 予約URL・個室・飲み放題などの日本特有の情報は取れない
class GooglePlacesService {
  static const _endpoint =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// 指定座標周辺のお店を検索。最大 20 件返る。
  /// [radiusMeters] は検索半径（m）。デフォルト 3000m（Hotpepper の range=5 と揃える）
  static Future<List<Restaurant>> searchNearby({
    required String apiKey,
    required double lat,
    required double lng,
    int radiusMeters = 3000,
  }) async {
    if (apiKey.isEmpty) return [];
    final params = <String, String>{
      'location': '$lat,$lng',
      'radius': radiusMeters.toString(),
      'type': 'restaurant',
      'language': 'ja',
      'key': apiKey,
    };
    final uri = Uri.parse(_endpoint).replace(queryParameters: params);
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('[GooglePlaces] HTTP ${res.statusCode}');
        return [];
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        debugPrint('[GooglePlaces] status=$status');
        return [];
      }
      final results = (json['results'] as List?) ?? [];
      debugPrint('[GooglePlaces] 取得: ${results.length}件 (lat=$lat, lng=$lng)');
      return results
          .map((r) => _mapPlace(r as Map<String, dynamic>))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      debugPrint('[GooglePlaces] searchNearby failed - ${e.runtimeType}');
      return [];
    }
  }

  static Restaurant? _mapPlace(Map<String, dynamic> p) {
    final placeId = p['place_id']?.toString();
    final name = p['name']?.toString();
    if (placeId == null || name == null || name.isEmpty) return null;

    final geometry = p['geometry'] as Map?;
    final location = geometry?['location'] as Map?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();

    // price_level: 0=Free, 1=Inexpensive, 2=Moderate, 3=Expensive, 4=Very Expensive
    final priceLevel = (p['price_level'] as num?)?.toInt();
    final priceAvg = switch (priceLevel) {
      0 => 500,
      1 => 1500,
      2 => 3000,
      3 => 5000,
      4 => 10000,
      _ => 3000, // 不明時はデフォルト
    };
    final priceLabel = switch (priceLevel) {
      0 => '¥〜500',
      1 => '¥〜1,500',
      2 => '¥1,500〜3,000',
      3 => '¥3,000〜5,000',
      4 => '¥5,000〜',
      _ => '',
    };

    final rating = (p['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (p['user_ratings_total'] as num?)?.toInt() ?? 0;
    final types = (p['types'] as List?)?.cast<String>() ?? [];
    final category = _typeToCategory(types);
    final emoji = _categoryEmoji(category);

    final stationIdx = (lat != null && lng != null)
        ? LocationService.nearestStationIndex(lat, lng)
        : 0;

    final photos = p['photos'] as List?;
    String? photoRef;
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first as Map?;
      photoRef = first?['photo_reference']?.toString();
    }
    final imageUrl = photoRef != null
        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef'
        : null;

    return Restaurant(
      id: 'gp_$placeId',
      name: name,
      stationIndex: stationIdx,
      category: category,
      rating: rating,
      reviewCount: reviewCount,
      priceLabel: priceLabel,
      priceAvg: priceAvg,
      tags: const [],
      emoji: emoji,
      description: '',
      distanceMinutes: 5, // 徒歩時間は推定5分
      address: p['vicinity']?.toString() ?? '',
      openHours: '',
      isReservable: false, // Google Places からは予約できない
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
      planInfoConfidence: 'unknown', // 飲み放題等は取れない
    );
  }

  /// Google Places の `types` から日本語カテゴリ名へマップする
  static String _typeToCategory(List<String> types) {
    if (types.contains('cafe')) return 'カフェ';
    if (types.contains('bakery')) return 'カフェ';
    if (types.contains('bar') || types.contains('night_club')) return 'バー';
    if (types.contains('meal_takeaway') || types.contains('meal_delivery')) {
      return '洋食';
    }
    // 細かいジャンルは Google では取れないので restaurant 共通として返す
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
