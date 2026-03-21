import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reserved_restaurant.dart';

class ReservedRestaurantsNotifier extends Notifier<List<ReservedRestaurant>> {
  static const _key = 'reserved_restaurants_v1';

  @override
  List<ReservedRestaurant> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      state = raw
          .map((s) => ReservedRestaurant.fromJson(
              jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ReservedRestaurantsNotifier: _load failed - $e');
      state = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, state.map((e) => jsonEncode(e.toJson())).toList());
    } catch (e) {
      debugPrint('ReservedRestaurantsNotifier: _save failed - $e');
    }
  }

  void add(ReservedRestaurant entry) {
    // 同じIDが既にあれば追加しない
    if (state.any((e) => e.id == entry.id)) return;
    state = [entry, ...state];
    _save();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _save();
  }
}

final reservedRestaurantsProvider = NotifierProvider<ReservedRestaurantsNotifier,
    List<ReservedRestaurant>>(ReservedRestaurantsNotifier.new);
