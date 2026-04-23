import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_group.dart';

/// 保存済みグループを扱う NotifierProvider。
///
/// 設計上の注意：
/// build() で永続化済みグループを _load() するが、これは非同期なので
/// **add()/remove() が _load() 完了前に呼ばれると、後から到着した _load()
/// が新規追加分を上書き消失させる**レースがある（「保存してもすぐに
/// 保存グループに出ない」という挙動の根本原因）。
///
/// 修正: build() で _load() の Future を保持し、add/remove は必ず
/// それを先に await する。これで初期読込完了を保証できる。
class GroupNotifier extends Notifier<List<SavedGroup>> {
  static const _key = 'saved_groups_v1';

  /// 初期ロードの完了を追跡する Future。null のときはまだ build されていない。
  Future<void>? _loadFuture;

  @override
  List<SavedGroup> build() {
    _loadFuture = _load();
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

  Future<void> add(
    String name,
    List<String> memberNames, {
    List<String?> memberStations = const [],
    List<int?> memberStationIndices = const [],
  }) async {
    // 初期 _load() が終わる前に state を書き換えると、あとから _load() が
    // 完了して新規追加分が上書き消失する。必ず待ってから変更する。
    await _loadFuture;
    final group = SavedGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      memberNames: memberNames,
      createdAt: DateTime.now(),
      memberStations: memberStations,
      memberStationIndices: memberStationIndices,
    );
    state = [group, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    await _loadFuture;
    state = state.where((g) => g.id != id).toList();
    await _save();
  }
}

final groupProvider =
    NotifierProvider<GroupNotifier, List<SavedGroup>>(GroupNotifier.new);
