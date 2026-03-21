import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';

/// OpenStreetMap Overpass API - 無料・APIキー不要でリアルな店舗データを取得
class OverpassService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  static Future<List<Restaurant>> searchNearby({
    required double lat,
    required double lng,
    int radiusMeters = 1000,
    int limit = 50,
  }) async {
    final query = '''
[out:json][timeout:15];
(
  node["amenity"="restaurant"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="cafe"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="bar"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="pub"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="fast_food"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="food_court"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="ice_cream"]["name"](around:$radiusMeters,$lat,$lng);
  node["amenity"="izakaya"]["name"](around:$radiusMeters,$lat,$lng);
  node["shop"="bakery"]["name"](around:$radiusMeters,$lat,$lng);
  node["shop"="confectionery"]["name"](around:$radiusMeters,$lat,$lng);
);
out $limit;
''';
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[OverpassService] HTTP ${response.statusCode}: ${response.body.substring(0, min(200, response.body.length))}');
        return [];
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final elements = (json['elements'] as List<dynamic>?) ?? [];

      return elements
          .map((e) => _parseElement(e as Map<String, dynamic>))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      debugPrint('OverpassService: searchNearby failed - ${e.runtimeType}');
      return [];
    }
  }

  static Restaurant? _parseElement(Map<String, dynamic> e) {
    final tags = e['tags'] as Map<String, dynamic>?;
    if (tags == null) return null;

    final name = tags['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final lat = (e['lat'] as num?)?.toDouble();
    final lng = (e['lon'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final amenity = tags['amenity'] as String?;
    final shop = tags['shop'] as String?;
    final cuisine = tags['cuisine'] as String? ?? '';
    final category = _mapCategory(amenity ?? shop ?? 'restaurant', cuisine);
    final emoji = _categoryEmoji(category);

    // Real rating from OSM if available, otherwise default 3.0
    double rating = 3.0;
    int reviewCount = 0;
    final starsTag = tags['stars'] as String?;
    final ratingTag = tags['rating'] as String?;
    if (starsTag != null) {
      final parsed = double.tryParse(starsTag);
      if (parsed != null && parsed > 0) rating = parsed;
    } else if (ratingTag != null) {
      final parsed = double.tryParse(ratingTag);
      if (parsed != null && parsed > 0) rating = parsed;
    }

    final hash = name.hashCode.abs();
    final priceAvg = [1500, 2000, 2500, 3000, 4000, 5000][hash % 6];
    final isReservable = tags['reservation'] == 'yes' || (hash % 3) != 0;
    final hasPrivateRoom = tags['private_room'] == 'yes' || (hash % 4) == 0;

    // Real opening hours from OSM if available
    final osmOpenHours = tags['opening_hours'] as String?;
    final openHours = osmOpenHours ?? _syntheticOpenHours(amenity ?? shop ?? 'restaurant', hash);

    // Real phone from OSM if available
    final phone = (tags['phone'] as String?) ??
        (tags['contact:phone'] as String?);

    final address = (tags['addr:full'] as String?) ??
        (tags['addr:city'] as String?) ??
        '';

    return Restaurant(
      id: 'osm_${e['id']}',
      name: name,
      category: category,
      emoji: emoji,
      stationIndex: 0,
      lat: lat,
      lng: lng,
      rating: rating,
      reviewCount: reviewCount,
      priceLabel: _priceLabel(priceAvg),
      priceAvg: priceAvg,
      tags: phone != null ? [phone] : const [],
      description: '',
      distanceMinutes: 5,
      address: address,
      openHours: openHours,
      isReservable: isReservable,
      hasPrivateRoom: hasPrivateRoom,
      isFemalePopular: (hash % 5) == 0,
      occasionTags: const [],
    );
  }

  static String _syntheticOpenHours(String amenity, int hash) {
    if (amenity == 'bar' || amenity == 'pub') return '18:00〜翌3:00';
    if (amenity == 'cafe' || amenity == 'bakery') return '8:00〜20:00';
    if (amenity == 'ice_cream') return '10:00〜21:00';
    final opens = [11, 11, 11, 12][hash % 4];
    final closes = [21, 22, 22, 23, 24][hash % 5];
    return '$opens:00〜$closes:00';
  }

  static String _mapCategory(String amenity, String cuisine) {
    if (amenity == 'cafe' || amenity == 'bakery') return 'カフェ';
    if (amenity == 'bar' || amenity == 'pub') return 'バー';
    if (amenity == 'izakaya') return '居酒屋';
    if (amenity == 'ice_cream' || amenity == 'confectionery') return 'スイーツ';
    if (amenity == 'fast_food') return 'ファストフード';
    if (amenity == 'food_court') return 'フードコート';
    if (cuisine.contains('ramen') || cuisine.contains('noodle')) {
      return 'ラーメン';
    }
    if (cuisine.contains('sushi') || cuisine.contains('japanese')) {
      return '和食';
    }
    if (cuisine.contains('italian') || cuisine.contains('pizza')) {
      return 'イタリアン';
    }
    if (cuisine.contains('french')) return 'フレンチ';
    if (cuisine.contains('chinese')) return '中華';
    if (cuisine.contains('korean') || cuisine.contains('bbq')) return '焼肉';
    if (cuisine.contains('izakaya')) return '居酒屋';
    return '洋食';
  }

  static String _categoryEmoji(String category) => switch (category) {
        '和食' => '🍱',
        'ラーメン' => '🍜',
        'イタリアン' => '🍝',
        'フレンチ' => '🥐',
        '中華' => '🥟',
        '焼肉' => '🥩',
        '居酒屋' => '🍺',
        'バー' => '🍸',
        'カフェ' => '☕',
        'スイーツ' => '🍰',
        'ファストフード' => '🍔',
        'フードコート' => '🍽️',
        _ => '🍽️',
      };

  static String _priceLabel(int avg) {
    if (avg < 1500) return '〜¥1,500';
    if (avg < 2500) return '〜¥2,500';
    if (avg < 4000) return '〜¥4,000';
    return '¥4,000〜';
  }

  /// インスタンスメソッド版（static版をラップ、DI経由で使用）
  Future<List<Restaurant>> search({
    required double lat,
    required double lng,
    int radiusMeters = 1000,
    int limit = 50,
  }) =>
      searchNearby(lat: lat, lng: lng, radiusMeters: radiusMeters, limit: limit);
}

final overpassServiceProvider = Provider<OverpassService>((ref) => OverpassService());
