import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reserved_restaurant.dart';
import 'auth_provider.dart';

class ReservedRestaurantsNotifier extends Notifier<List<ReservedRestaurant>> {
  @override
  List<ReservedRestaurant> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final uid = await ensureUid();
      final snapshot = await FirebaseFirestore.instance
          .collection('users/$uid/reserved_restaurants')
          .orderBy('reservedAt', descending: true)
          .limit(100)
          .get();
      state = snapshot.docs
          .map((d) => ReservedRestaurant.fromJson(d.data()))
          .toList();
    } catch (e) {
      developer.log(
        'ReservedRestaurantsNotifier: _load failed - ${e.runtimeType}',
        name: 'ReservedRestaurantsNotifier',
        error: e,
      );
      state = [];
    }
  }

  Future<void> add(ReservedRestaurant entry) async {
    try {
      if (state.any((e) => e.id == entry.id)) return;
      final uid = await ensureUid();
      await FirebaseFirestore.instance
          .collection('users/$uid/reserved_restaurants')
          .doc(entry.id)
          .set(entry.toJson());
      state = [entry, ...state];
    } catch (e) {
      developer.log(
        'ReservedRestaurantsNotifier: add failed - ${e.runtimeType}',
        name: 'ReservedRestaurantsNotifier',
        error: e,
      );
    }
  }

  Future<void> remove(String id) async {
    try {
      final uid = await ensureUid();
      await FirebaseFirestore.instance
          .collection('users/$uid/reserved_restaurants')
          .doc(id)
          .delete();
      state = state.where((e) => e.id != id).toList();
    } catch (e) {
      developer.log(
        'ReservedRestaurantsNotifier: remove failed - ${e.runtimeType}',
        name: 'ReservedRestaurantsNotifier',
        error: e,
      );
    }
  }
}

final reservedRestaurantsProvider = NotifierProvider<ReservedRestaurantsNotifier,
    List<ReservedRestaurant>>(ReservedRestaurantsNotifier.new);
