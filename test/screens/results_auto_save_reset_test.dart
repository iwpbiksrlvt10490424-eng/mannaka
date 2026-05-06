import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 履歴は「ユーザーが詳細を開くために実際にタップした店」だけを残す方針。
/// 1 検索セッション内で複数の店をタップしたら 1 つのエントリーに束ねる。
///
/// 過去の不具合と方針変更:
/// 1. 旧: _autoSaved フラグが画面ライフサイクル全体で持続し、2 回目以降の検索が
///    履歴に保存されなかった
/// 2. 旧: 検索完了で上位 N 店を一括保存していたが、表示されただけの店は
///    ユーザーの好みかわからないため不適切と判断
/// 3. 現行: タップ追跡 (_tappedIds) と現セッションのエントリー id (_currentEntryId)
///    を保持し、新検索完了で両方リセット。タップ時に追記/新規作成。
void main() {
  test('results_screen.dart: タップした店だけを履歴に保存する仕掛けが残っている', () {
    final src = File('lib/screens/results_screen.dart').readAsStringSync();

    // 1) 新検索完了時にタップ追跡をリセットする listenManual がある
    expect(
      src.contains('ref.listenManual'),
      isTrue,
      reason: 'initState で ref.listenManual による監視が登録されているべき',
    );
    expect(
      src.contains("searchProvider.select((s) => s.isCalculating)") ||
          src.contains('searchProvider.select((s)=>s.isCalculating)'),
      isTrue,
      reason: 'isCalculating セレクタで検索状態を購読しているべき',
    );

    // 2) タップ追跡と「駅ごと」のエントリー id マップがある
    //    （検索単位ではなく駅単位で束ねる：タブ切替で違う駅のタップが
    //     同じエントリーに混ざらないように）
    expect(
      src.contains('_tappedIds'),
      isTrue,
      reason: 'タップ済み restaurant id の追跡集合が残っているべき',
    );
    expect(
      src.contains('_entryIdByStation'),
      isTrue,
      reason: '駅名 → エントリー id のマップを保持しているべき（駅単位で束ねる）',
    );
    expect(
      src.contains('_currentEntryId'),
      isFalse,
      reason: '旧 _currentEntryId（検索単位の単一 id）は撤廃されているべき',
    );

    // 3) タップ時の保存メソッドが定義されている
    expect(
      src.contains('_saveTappedRestaurant'),
      isTrue,
      reason: 'タップした店を履歴保存するメソッドが定義されているべき',
    );

    // 4) onFirstDetailOpen が _saveTappedRestaurant に接続されている
    expect(
      src.contains('onFirstDetailOpen: _saveTappedRestaurant'),
      isTrue,
      reason: 'onFirstDetailOpen が _saveTappedRestaurant に接続されているべき',
    );

    // 4-2) タブの point をコールバックに渡している（state.selectedMeetingPoint を
    //       グローバルに読まない。同期ズレで古い駅が混入するのを防ぐ）
    expect(
      src.contains('widget.onFirstDetailOpen(s.restaurant, widget.point)'),
      isTrue,
      reason: 'タブ自身の point を保存に渡しているべき',
    );
    expect(
      RegExp(r'_saveTappedRestaurant\([^)]*MeetingPoint[^)]*\)').hasMatch(src),
      isTrue,
      reason: '_saveTappedRestaurant は引数で MeetingPoint を受け取るべき',
    );

    // 5) 旧仕様（上位 N 店一括保存）が残っていない
    expect(
      src.contains('_saveTopRestaurantsToHistory'),
      isFalse,
      reason: '旧 _saveTopRestaurantsToHistory* は撤廃されているべき',
    );

    // 6) 追記用の appendRestaurant を呼んでいる
    expect(
      src.contains('appendRestaurant'),
      isTrue,
      reason: '同セッション 2 店目以降は appendRestaurant で追記しているべき',
    );

    // 7) build に ref.listen を書かない（CLAUDE.md ルール）
    final buildBlock = RegExp(
      r'Widget\s+build\(BuildContext\s+context\)\s*\{[\s\S]*?\n\s*\}',
    );
    final builds = buildBlock.allMatches(src).toList();
    for (final m in builds) {
      expect(
        m.group(0)!.contains('ref.listen('),
        isFalse,
        reason: 'build() 内に ref.listen を書かない（CLAUDE.md Riverpod ルール）',
      );
    }
  });
}
