import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/secrets.dart';
import '../models/meeting_point.dart';
import '../utils/photo_ref.dart';

/// 履歴に保存する軽量レストラン情報
class HistoryRestaurant {
  const HistoryRestaurant({
    required this.name,
    required this.category,
    this.rating,
    this.imageUrl,
    this.photoRefs = const [],
    this.hotpepperUrl,
    this.lat,
    this.lng,
    this.address = '',
  });

  final String name;
  final String category;
  final double? rating;
  /// 単一サムネイル URL（後方互換用）。
  final String? imageUrl;

  /// 複数枚写真の参照。
  /// - "https://" で始まる文字列 = Hotpepper 等の完全 URL（そのまま使う）
  /// - それ以外 = Google Places の photo reference（例: "places/abc/photos/xyz"）
  ///   表示時に API キーを付けて URL を構築する。
  /// API キーを Firestore に書かない設計。
  final List<String> photoRefs;
  final String? hotpepperUrl;
  final double? lat;
  final double? lng;
  final String address;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'rating': rating,
        if (imageUrl != null) 'imageUrl': PhotoRef.toRef(imageUrl!),
        if (photoRefs.isNotEmpty) 'photoRefs': photoRefs,
        if (hotpepperUrl != null) 'hotpepperUrl': hotpepperUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'address': address,
      };

  factory HistoryRestaurant.fromJson(Map<String, dynamic> j) =>
      HistoryRestaurant(
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble(),
        imageUrl: (j['imageUrl'] as String?) == null
            ? null
            : PhotoRef.toUrl(j['imageUrl'] as String,
                googleApiKey: Secrets.placesApiKey),
        photoRefs: (j['photoRefs'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        hotpepperUrl: j['hotpepperUrl'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        address: j['address'] as String? ?? '',
      );
}

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.participantNames,
    required this.meetingPoint,
    this.restaurants = const [],
  });

  final String id;
  final DateTime createdAt;
  final List<String> participantNames;
  final MeetingPoint meetingPoint;
  final List<HistoryRestaurant> restaurants;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'participantNames': participantNames,
        'meetingPoint': meetingPoint.toJson(),
        'restaurants': restaurants.map((r) => r.toJson()).toList(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        participantNames:
            List<String>.from(j['participantNames'] as List),
        meetingPoint:
            MeetingPoint.fromJson(j['meetingPoint'] as Map<String, dynamic>),
        restaurants: (j['restaurants'] as List? ?? [])
            .map((r) =>
                HistoryRestaurant.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

/// 検索履歴をローカルの SharedPreferences に永続化する Notifier。
///
/// 設計判断（2026-04-30 ローカル化）:
/// - Firestore 同期をやめてローカル保存に切替。古いバグ由来エントリーが
///   ユーザーの環境ごとに残り続けて混乱を招いていたため。
/// - ユーザーごとの認証は不要（端末単位の履歴）。
/// - JSON シリアライズして 1 つのキーに保存。最大 50 件で打ち切り（古いものから捨てる）。
class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  static const _prefsKey = 'search_history_v2';
  static const _maxEntries = 50;

  @override
  List<HistoryEntry> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
      state = list;
    } catch (e) {
      developer.log(
        'HistoryNotifier: _load failed - ${e.runtimeType}',
        name: 'HistoryNotifier',
        error: e,
      );
    }
  }

  Future<void> _save(List<HistoryEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, json);
    } catch (e) {
      developer.log(
        'HistoryNotifier: _save failed - ${e.runtimeType}',
        name: 'HistoryNotifier',
        error: e,
      );
    }
  }

  /// 新規エントリーを作成して保存。生成した entry id を返す。
  /// 呼び出し側はその id を保持しておけば、後から `appendRestaurant` で
  /// 同じエントリーに店を追記できる（同じ検索セッション内の複数タップを束ねる用）。
  Future<String> add(
    List<String> names,
    MeetingPoint point, {
    List<HistoryRestaurant> restaurants = const [],
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final entry = HistoryEntry(
        id: id,
        createdAt: DateTime.now(),
        participantNames: names,
        meetingPoint: point,
        restaurants: restaurants,
      );
      final next = [entry, ...state].take(_maxEntries).toList();
      state = next;
      await _save(next);
    } catch (e) {
      developer.log(
        'HistoryNotifier: add failed - ${e.runtimeType}',
        name: 'HistoryNotifier',
        error: e,
      );
    }
    return id;
  }

  /// 既存エントリーにレストランを追記する。
  /// 同じ検索セッション内でユーザーが複数の店をタップした場合に、
  /// 1 つの履歴エントリーへ束ねるために使う。
  /// 同名の店が既にあれば追記しない（重複防止）。
  Future<void> appendRestaurant(String entryId, HistoryRestaurant r) async {
    try {
      final idx = state.indexWhere((e) => e.id == entryId);
      if (idx < 0) return;
      final entry = state[idx];
      if (entry.restaurants.any((x) => x.name == r.name)) return;
      final updated = HistoryEntry(
        id: entry.id,
        createdAt: entry.createdAt,
        participantNames: entry.participantNames,
        meetingPoint: entry.meetingPoint,
        restaurants: [...entry.restaurants, r],
      );
      final next = [...state];
      next[idx] = updated;
      state = next;
      await _save(next);
    } catch (e) {
      developer.log(
        'HistoryNotifier: appendRestaurant failed - ${e.runtimeType}',
        name: 'HistoryNotifier',
        error: e,
      );
    }
  }

  Future<void> remove(String id) async {
    try {
      final next = state.where((e) => e.id != id).toList();
      state = next;
      await _save(next);
    } catch (e) {
      developer.log(
        'HistoryNotifier: remove failed - ${e.runtimeType}',
        name: 'HistoryNotifier',
        error: e,
      );
    }
  }

  /// すべての履歴をクリア（ユーザーが「全削除」を選んだ時用）。
  Future<void> clearAll() async {
    state = [];
    await _save([]);
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
