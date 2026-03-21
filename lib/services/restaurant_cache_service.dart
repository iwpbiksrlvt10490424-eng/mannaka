import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/restaurant.dart';

/// Firestore-based restaurant search result cache.
/// Cache key: centroid lat/lng rounded to 2 decimal places (~1km grid).
/// TTL: 15 minutes.
class RestaurantCacheService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'restaurant_cache';
  static const _ttlMinutes = 15;

  static String _cacheKey(double lat, double lng) {
    final rLat = (lat * 100).round();
    final rLng = (lng * 100).round();
    return '${rLat}_$rLng';
  }

  static Future<List<Restaurant>?> get(double lat, double lng) async {
    try {
      final doc = await _db.collection(_collection).doc(_cacheKey(lat, lng)).get()
          .timeout(const Duration(seconds: 2));
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
      debugPrint('RestaurantCacheService.get: $e');
      return null;
    }
  }

  static Future<void> set(double lat, double lng, List<Restaurant> restaurants) async {
    try {
      await _db.collection(_collection).doc(_cacheKey(lat, lng)).set({
        'restaurants': restaurants.map((r) => r.toJson()).toList(),
        'cached_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('RestaurantCacheService.set: $e');
    }
  }
}
