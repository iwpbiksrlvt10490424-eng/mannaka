import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_share_draft.dart';

/// LINE で送る前の「下書き」を端末内に保持するプロバイダ。
/// サーバー同期は不要（個人メモ用途）。SharedPreferences で JSON 配列として保存。
class SavedShareDraftsNotifier extends Notifier<List<SavedShareDraft>> {
  static const _key = 'saved_share_drafts_v1';

  @override
  List<SavedShareDraft> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      state = raw
          .map((s) =>
              SavedShareDraft.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  Future<void> add(SavedShareDraft draft) async {
    state = [draft, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _save();
  }
}

final savedShareDraftsProvider =
    NotifierProvider<SavedShareDraftsNotifier, List<SavedShareDraft>>(
        SavedShareDraftsNotifier.new);
