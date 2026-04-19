import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ranking_entry.dart';

/// マネタイズ対応の拡張分析サービス
/// データ提供はユーザーのオプトイン制（analytics_opt_in キー）
class AnalyticsService {
  static final _db = FirebaseFirestore.instance;
  static const _optInKey = 'analytics_opt_in';

  // ── オプトイン状態の確認 ────────────────────────────────────────────────
  // デフォルト true（プライバシーポリシーで開示済みの分析データ収集を有効にする）。
  // マイページからユーザーがオプトアウト可能（setOptIn(false)）。
  static Future<bool> isOptedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_optInKey) ?? true;
  }

  static Future<void> setOptIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optInKey, value);
  }

  // ── 匿名ユーザーID ─────────────────────────────────────────────────────
  static Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('anon_user_id');
    if (stored != null) return stored;
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString('anon_user_id', id);
    return id;
  }

  static Future<Map<String, dynamic>> _baseContext() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    return {
      'user_id': await _getUserId(),
      'timestamp': FieldValue.serverTimestamp(),
      'hour_of_day': now.hour,
      'day_of_week': now.weekday, // 1=月〜7=日
      'home_station': prefs.getInt('home_station'),
    };
  }

  // ── 検索ログ（中間点計算実行時） ────────────────────────────────────────
  /// scene: 'meal' | 'cafe' | 'drinks' | 'date' | 'party'
  /// genre: ユーザー選択ジャンル
  /// budget: '〜1000' | '〜2000' | '〜3000' | '3000〜'
  static Future<void> logSearch({
    required String stationName,
    required int stationIndex,
    required int participantCount,
    String? scene,
    String? genre,
    String? budget,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();

      // 駅カウンタ（ランキング用）
      await _db.collection('station_counts').doc('$stationIndex').set({
        'station_name': stationName,
        'station_index': stationIndex,
        'count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 時間帯×駅 需要マトリクス（広告・送客分析用）
      final timeSlot = _timeSlot(ctx['hour_of_day'] as int);
      await _db
          .collection('station_demand')
          .doc('${stationIndex}_${timeSlot}_${ctx['day_of_week']}')
          .set({
        'station_name': stationName,
        'time_slot': timeSlot,
        'day_of_week': ctx['day_of_week'],
        'count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 詳細ログ
      await _db.collection('search_logs').add({
        ...ctx,
        'station_name': stationName,
        'station_index': stationIndex,
        'participant_count': participantCount,
        'scene': scene,
        'genre': genre,
        'budget': budget,
      });
    } catch (e) {
      debugPrint('Analytics.logSearch: ${e.runtimeType}');
    }
  }

  // ── レストランクリックログ ──────────────────────────────────────────────
  static Future<void> logRestaurantClick({
    required String restaurantId,
    required String restaurantName,
    required String category,
    required String area,
    required int rank,
    String? priceRange,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();

      // カテゴリ需要（飲食店向け広告ターゲティング用）
      await _db.collection('category_demand').doc(category).set({
        'category': category,
        'click_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('restaurant_clicks').add({
        ...ctx,
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'category': category,
        'area': area,
        'rank': rank,
        'price_range': priceRange,
      });
    } catch (e) {
      debugPrint('Analytics.logRestaurantClick: ${e.runtimeType}');
    }
  }

  // ── 予約ボタン押下ログ（送客数=マネタイズの直接指標） ──────────────────
  static Future<void> logReservationTap({
    required String restaurantId,
    required String restaurantName,
    required String category,
    String? area,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();

      // 予約送客カウンタ（B2B課金根拠）
      await _db.collection('reservation_leads').doc(restaurantId).set({
        'restaurant_name': restaurantName,
        'category': category,
        'area': area,
        'lead_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('reservation_logs').add({
        ...ctx,
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'category': category,
        'area': area,
      });
    } catch (e) {
      debugPrint('Analytics.logReservationTap: ${e.runtimeType}');
    }
  }

  // ── シェアログ ─────────────────────────────────────────────────────────
  /// shareType: 'image' | 'text' | 'voting'
  static Future<void> logShare({
    required String shareType,
    String? restaurantName,
    String? area,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();
      await _db.collection('share_logs').add({
        ...ctx,
        'share_type': shareType,
        'restaurant_name': restaurantName,
        'area': area,
      });
    } catch (e) {
      debugPrint('Analytics.logShare: ${e.runtimeType}');
    }
  }

  // ── フィルター・ソート使用ログ（UX改善＆ニーズ分析） ────────────────────
  static Future<void> logFilterUsed({
    required String filterType,
    required String value,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();
      await _db.collection('filter_logs').add({
        ...ctx,
        'filter_type': filterType,
        'value': value,
      });
    } catch (e) {
      debugPrint('Analytics.logFilterUsed: ${e.runtimeType}');
    }
  }

  static Future<void> logSortChanged(String sortType) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();
      await _db.collection('sort_logs').add({...ctx, 'sort_type': sortType});
    } catch (e) {
      debugPrint('Analytics.logSortChanged: ${e.runtimeType}');
    }
  }

  // ── 店舗決定ログ（最終コンバージョン） ────────────────────────────────
  static Future<void> logRestaurantDecided({
    required String restaurantId,
    required String restaurantName,
    required String category,
    String? area,
    String? priceRange,
  }) async {
    try {
      if (!await isOptedIn()) return;
      final ctx = await _baseContext();

      await _db.collection('decided_restaurants').doc(restaurantId).set({
        'restaurant_name': restaurantName,
        'category': category,
        'area': area,
        'decided_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('decision_logs').add({
        ...ctx,
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'category': category,
        'area': area,
        'price_range': priceRange,
      });
    } catch (e) {
      debugPrint('Analytics.logRestaurantDecided: ${e.runtimeType}');
    }
  }

  // ── ランキング取得 ─────────────────────────────────────────────────────
  static Future<List<RankingEntry>> fetchRanking({int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection('station_counts')
          .orderBy('count', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .asMap()
          .entries
          .map((e) => RankingEntry.fromMap(e.value.data(), e.key + 1))
          .toList();
    } catch (e) {
      debugPrint('Analytics.fetchRanking: ${e.runtimeType}');
      return [];
    }
  }

  // ── ヘルパー ──────────────────────────────────────────────────────────
  static String _timeSlot(int hour) {
    if (hour < 6) return 'midnight';
    if (hour < 11) return 'morning';
    if (hour < 14) return 'lunch';
    if (hour < 17) return 'afternoon';
    if (hour < 20) return 'dinner';
    return 'night';
  }
}
