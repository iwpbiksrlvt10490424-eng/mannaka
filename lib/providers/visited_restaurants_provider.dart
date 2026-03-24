import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visited_restaurant.dart';
import 'auth_provider.dart';

class VisitedRestaurantsNotifier extends Notifier<List<VisitedRestaurant>> {
  @override
  List<VisitedRestaurant> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final uid = await ensureUid();
      final snapshot = await FirebaseFirestore.instance
          .collection('users/$uid/visited_restaurants')
          .orderBy('visitedAt', descending: true)
          .limit(100)
          .get();
      state = snapshot.docs
          .map((d) => VisitedRestaurant.fromJson(d.data()))
          .toList();
    } catch (e) {
      debugPrint('VisitedRestaurantsNotifier: _load failed - ${e.runtimeType}');
    }
  }

  Future<void> add(VisitedRestaurant entry) async {
    try {
      if (state.any((e) => e.id == entry.id)) return;
      final uid = await ensureUid();
      await FirebaseFirestore.instance
          .collection('users/$uid/visited_restaurants')
          .doc(entry.id)
          .set(entry.toJson());
      state = [entry, ...state];
    } catch (e) {
      debugPrint('VisitedRestaurantsNotifier: add failed - ${e.runtimeType}');
    }
  }

  Future<void> remove(String id) async {
    try {
      final uid = await ensureUid();
      await FirebaseFirestore.instance
          .collection('users/$uid/visited_restaurants')
          .doc(id)
          .delete();
      state = state.where((e) => e.id != id).toList();
    } catch (e) {
      debugPrint('VisitedRestaurantsNotifier: remove failed - ${e.runtimeType}');
    }
  }
}

final visitedRestaurantsProvider = NotifierProvider<VisitedRestaurantsNotifier,
    List<VisitedRestaurant>>(VisitedRestaurantsNotifier.new);
