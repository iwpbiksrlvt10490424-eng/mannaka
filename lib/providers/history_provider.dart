import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_point.dart';
import 'auth_provider.dart';

/// 履歴に保存する軽量レストラン情報
class HistoryRestaurant {
  const HistoryRestaurant({
    required this.name,
    required this.category,
    this.rating = 0,
    this.imageUrl,
  });

  final String name;
  final String category;
  final double rating;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'rating': rating,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory HistoryRestaurant.fromJson(Map<String, dynamic> j) =>
      HistoryRestaurant(
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        rating: (j['rating'] as num? ?? 0).toDouble(),
        imageUrl: j['imageUrl'] as String?,
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

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final uid = await ensureUid();
      final snapshot = await FirebaseFirestore.instance
          .collection('users/$uid/search_history')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      state = snapshot.docs
          .map((d) => HistoryEntry.fromJson(d.data()))
          .toList();
    } catch (e) {
      debugPrint('HistoryNotifier: _load failed - ${e.runtimeType}');
    }
  }

  Future<void> add(
    List<String> names,
    MeetingPoint point, {
    List<HistoryRestaurant> restaurants = const [],
  }) async {
    try {
      final uid = await ensureUid();
      final entry = HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        participantNames: names,
        meetingPoint: point,
        restaurants: restaurants,
      );
      await FirebaseFirestore.instance
          .collection('users/$uid/search_history')
          .doc(entry.id)
          .set(entry.toJson());
      state = [entry, ...state];
    } catch (e) {
      debugPrint('HistoryNotifier: add failed - ${e.runtimeType}');
    }
  }

  Future<void> remove(String id) async {
    try {
      final uid = await ensureUid();
      await FirebaseFirestore.instance
          .collection('users/$uid/search_history')
          .doc(id)
          .delete();
      state = state.where((e) => e.id != id).toList();
    } catch (e) {
      debugPrint('HistoryNotifier: remove failed - ${e.runtimeType}');
    }
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
