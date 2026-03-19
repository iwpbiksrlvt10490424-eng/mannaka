import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visit_log.dart';

class VisitLogNotifier extends Notifier<List<VisitLog>> {
  static const _key = 'visit_logs';

  @override
  List<VisitLog> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = VisitLog.decodeList(raw);
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> add(VisitLog log) async {
    state = [log, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((l) => l.id != id).toList();
    await _save();
  }

  Future<void> updateRating(String id, int rating, String memo) async {
    state = state.map((l) {
      if (l.id != id) return l;
      return VisitLog(
        id: l.id,
        restaurantId: l.restaurantId,
        restaurantName: l.restaurantName,
        category: l.category,
        emoji: l.emoji,
        visitedAt: l.visitedAt,
        userRating: rating,
        memo: memo,
        imageUrl: l.imageUrl,
        address: l.address,
        hotpepperUrl: l.hotpepperUrl,
      );
    }).toList();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, VisitLog.encodeList(state));
  }
}

final visitLogProvider =
    NotifierProvider<VisitLogNotifier, List<VisitLog>>(VisitLogNotifier.new);
