import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_group.dart';

class GroupNotifier extends Notifier<List<SavedGroup>> {
  static const _key = 'saved_groups_v1';

  @override
  List<SavedGroup> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      state = raw
          .map((s) =>
              SavedGroup.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, state.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> add(String name, List<String> memberNames) async {
    final group = SavedGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      memberNames: memberNames,
      createdAt: DateTime.now(),
    );
    state = [group, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _save();
  }
}

final groupProvider =
    NotifierProvider<GroupNotifier, List<SavedGroup>>(GroupNotifier.new);
