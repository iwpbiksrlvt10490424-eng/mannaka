import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_share_draft.dart';

/// LINE で送る前の「下書き」を端末内に保持するプロバイダ。
/// サーバー同期は不要（個人メモ用途）。SharedPreferences で JSON 配列として保存。
///
/// 契約:
/// - `AsyncNotifier` 化: `build()` の初期ロード完了前に `add()` / `remove()`
///   が呼ばれると既存下書きが上書き消失するレースを防ぐため。
/// - **要素単位の try/catch**: 1件の破損で全件を失わないよう、
///   配列全体を包む try/catch は持たず、各要素の JSON パースを個別に囲む。
/// - 破損した要素は読み込みをスキップし `developer.log(name: 'SavedShareDrafts')`
///   で診断ログを出す。
class SavedShareDraftsNotifier
    extends AsyncNotifier<List<SavedShareDraft>> {
  static const _key = 'saved_share_drafts_v1';

  @override
  Future<List<SavedShareDraft>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final result = <SavedShareDraft>[];
    for (var i = 0; i < raw.length; i++) {
      try {
        final map = jsonDecode(raw[i]) as Map<String, dynamic>;
        result.add(SavedShareDraft.fromJson(map));
      } catch (e) {
        // 1件の破損で他を巻き込まない。診断のためログは出す。
        developer.log(
          'Skip corrupted draft at index $i: ${e.runtimeType}',
          name: 'SavedShareDrafts',
          error: e,
        );
      }
    }
    return result;
  }

  Future<void> _save(List<SavedShareDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      drafts.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  Future<void> add(SavedShareDraft draft) async {
    final current = await future;
    final next = [draft, ...current];
    state = AsyncData(next);
    await _save(next);
  }

  Future<void> remove(String id) async {
    final current = await future;
    final next = current.where((d) => d.id != id).toList();
    state = AsyncData(next);
    await _save(next);
  }
}

final savedShareDraftsProvider = AsyncNotifierProvider<
    SavedShareDraftsNotifier,
    List<SavedShareDraft>>(SavedShareDraftsNotifier.new);
