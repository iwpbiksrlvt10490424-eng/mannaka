import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurant.dart';

/// Firestore-based restaurant search result cache.
/// Cache key: centroid lat/lng rounded to 3 decimal places (~100m grid).
/// TTL: 15 minutes.
class RestaurantCacheService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'restaurant_cache';
  static const _ttlMinutes = 15;
  static const _readTimeout = Duration(seconds: 5);
  static const _writeTimeout = Duration(seconds: 3);

  /// ~100m granularity (3 decimal places)
  static String _cacheKey(double lat, double lng, {String? genre}) {
    final rLat = (lat * 1000).round();
    final rLng = (lng * 1000).round();
    return genre != null ? '${rLat}_${rLng}_$genre' : '${rLat}_$rLng';
  }

  static Future<List<Restaurant>?> get(double lat, double lng, {String? genre}) async {
    try {
      final doc = await _db
          .collection(_collection)
          .doc(_cacheKey(lat, lng, genre: genre))
          .get()
          .timeout(_readTimeout);
      if (!doc.exists) return null;
      final data = doc.data()!;
      final cachedAt = (data['cached_at'] as Timestamp?)?.toDate();
      if (cachedAt == null) return null;
      if (DateTime.now().difference(cachedAt).inMinutes > _ttlMinutes) return null;
      final list = (data['restaurants'] as List<dynamic>?) ?? [];
      return list
          .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log(
        'RestaurantCacheService.get: ${e.runtimeType}',
        name: 'RestaurantCacheService',
        error: e,
      );
      return null;
    }
  }

  static Future<void> set(double lat, double lng, List<Restaurant> restaurants, {String? genre}) async {
    try {
      await _db
          .collection(_collection)
          .doc(_cacheKey(lat, lng, genre: genre))
          .set({
            'restaurants': restaurants.map((r) => r.toJson()).toList(),
            'cached_at': FieldValue.serverTimestamp(),
          })
          .timeout(_writeTimeout);
    } catch (e) {
      developer.log(
        'RestaurantCacheService.set: ${e.runtimeType}',
        name: 'RestaurantCacheService',
        error: e,
      );
    }
  }
}
