import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/restaurant.dart';

/// Foursquare Places API v3 - リアルな店舗データを取得
class FoursquareService {
  static const _endpoint = 'https://api.foursquare.com/v3/places/search';
  static const _fields =
      'fsq_id,name,location,geocodes,categories,rating,stats,hours,tel,website,price,photos';

  Future<List<Restaurant>> searchNearby(
    double lat,
    double lng, {
    int radiusMeters = 1000,
    int limit = 50,
  }) async {
    if (ApiConfig.foursquareApiKey.isEmpty ||
        ApiConfig.foursquareApiKey.startsWith('YOUR_')) {
      return [];
    }
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'll': '$lat,$lng',
        'radius': '$radiusMeters',
        'categories': '13000',
        'limit': '$limit',
        'fields': _fields,
      });

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': ApiConfig.foursquareApiKey,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[FoursquareService] HTTP ${response.statusCode}: ${response.body.substring(0, min(200, response.body.length))}');
        return [];
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null) return [];

      return results
          .map((e) => _parseResult(e as Map<String, dynamic>))
          .whereType<Restaurant>()
          .toList();
    } catch (e) {
      debugPrint('FoursquareService: searchNearby failed - ${e.runtimeType}');
      return [];
    }
  }

  static Restaurant? _parseResult(Map<String, dynamic> e) {
    final fsqId = e['fsq_id'] as String?;
    if (fsqId == null) return null;

    final name = e['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final geocodes = e['geocodes'] as Map<String, dynamic>?;
    final mainGeo = geocodes?['main'] as Map<String, dynamic>?;
    final lat = (mainGeo?['latitude'] as num?)?.toDouble();
    final lng = (mainGeo?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final location = e['location'] as Map<String, dynamic>?;
    final address = (location?['formatted_address'] as String?) ??
        (location?['address'] as String?) ??
        '';

    final categories = e['categories'] as List<dynamic>?;
    final firstCategory = categories?.isNotEmpty == true
        ? categories!.first as Map<String, dynamic>
        : null;
    final shortName = firstCategory?['short_name'] as String?;
    final fullName = firstCategory?['name'] as String?;
    final category = _mapCategory(shortName ?? fullName ?? '');
    final emoji = _categoryEmoji(category);

    final rawRating = (e['rating'] as num?)?.toDouble();
    final rating = rawRating != null ? rawRating / 2.0 : 0.0;

    final stats = e['stats'] as Map<String, dynamic>?;
    final reviewCount = (stats?['total_ratings'] as num?)?.toInt() ?? 0;

    final hours = e['hours'] as Map<String, dynamic>?;
    final openHours = (hours?['display'] as String?) ?? '';

    final phone = (e['tel'] as String?) ?? '';

    final rawPrice = (e['price'] as num?)?.toInt();
    final priceAvg = rawPrice != null ? _priceFromTier(rawPrice) : 0;
    final priceLabel = _priceLabel(priceAvg);

    final photos = e['photos'] as List<dynamic>?;
    String? imageUrl;
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first as Map<String, dynamic>;
      final prefix = first['prefix'] as String?;
      final suffix = first['suffix'] as String?;
      if (prefix != null && suffix != null) {
        imageUrl = '${prefix}300x300$suffix';
      }
    }

    return Restaurant(
      id: 'fsq_$fsqId',
      name: name,
      category: category,
      emoji: emoji,
      stationIndex: 0,
      lat: lat,
      lng: lng,
      rating: rating,
      reviewCount: reviewCount,
      priceLabel: priceLabel,
      priceAvg: priceAvg,
      tags: phone.isNotEmpty ? [phone] : const [],
      description: '',
      distanceMinutes: 5,
      address: address,
      openHours: openHours,
      isReservable: true,
      hasPrivateRoom: false,
      isFemalePopular: false,
      occasionTags: const [],
      hotpepperUrl: '',
      imageUrl: imageUrl,
    );
  }

  static String _mapCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('japanese')) return '和食';
    if (lower.contains('ramen')) return 'ラーメン';
    if (lower.contains('sushi')) return '寿司';
    if (lower.contains('izakaya')) return '居酒屋';
    if (lower.contains('italian')) return 'イタリアン';
    if (lower.contains('chinese')) return '中華';
    if (lower.contains('cafe') || lower.contains('coffee')) return 'カフェ';
    if (lower.contains('bar')) return 'バー';
    return name.isNotEmpty ? name : '洋食';
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
        '寿司' => '🍣',
        _ => '🍽️',
      };

  static int _priceFromTier(int tier) => switch (tier) {
        1 => 1000,
        2 => 2000,
        3 => 3000,
        4 => 5000,
        _ => 0,
      };

  static String _priceLabel(int avg) {
    if (avg == 0) return '';
    if (avg < 1500) return '〜¥1,500';
    if (avg < 2500) return '〜¥2,500';
    if (avg < 4000) return '〜¥4,000';
    return '¥4,000〜';
  }
}

final foursquareServiceProvider = Provider<FoursquareService>((ref) => FoursquareService());
