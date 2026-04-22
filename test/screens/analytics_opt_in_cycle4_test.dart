// TDD Red フェーズ（Cycle 4）
// 分析 opt-in トグル — Critic Cycle 3 残 WARNING 3件の解消テスト
//
// スコープ（current_task.md / review_feedback.md より）:
//   1. [WARNING / in-flight 再タップ]
//      `_handleChanged` が in-flight 中の再タップを直列化せず、
//      連続失敗時に `previous` がずれる edge case
//      （`settings_screen.dart:1174-1188`）
//   2. [WARNING / テストヘッダ不整合]
//      `test/screens/analytics_opt_in_widget_test.dart` のヘッダコメントが
//      `initialValue` 前提のまま（本体は `value:` 更新済）
//   3. [WARNING / 4s タイマー待ち]
//      Cycle 2 ロールバックテストの `pumpAndSettle()` が SnackBar の 4s タイマー
//      を待つ形になる。`pump(100ms)` 置換で CI 時間短縮＆安定化
//
// 受け入れ条件:
//   A. in-flight 中の再タップは onChanged を二重起動しない（直列化／抑制）
//   B. onChanged が連続失敗しても最終的に Switch は元の値に戻る（previous 維持）
//   C. Cycle 2 テストファイルのヘッダコメント／reason 文言に `initialValue` が残っていない
//   D. Cycle 2 ロールバック testWidgets 群で `pumpAndSettle` を使わず
//      `pump(Duration(milliseconds: X))` で SnackBar タイマーを迂回している

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/screens/settings_screen.dart';

String _readCycle2TestFile() {
  final file = File('test/screens/analytics_opt_in_widget_test.dart');
  if (!file.existsSync()) {
    fail(
      'test/screens/analytics_opt_in_widget_test.dart が見つかりません。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [A] in-flight 中の再タップを直列化／抑制する
  // ══════════════════════════════════════════════════════════════

  group('AnalyticsOptInTile — in-flight 中の再タップ直列化', () {
    testWidgets('onChanged が await 中に再タップしても onChanged は二重起動されない', (
      tester,
    ) async {
      final calls = <bool>[];
      final gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                calls.add(v);
                await gate.future;
              },
            ),
          ),
        ),
      );

      // 1回目のタップ → onChanged(false) が await 中
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(
        calls,
        equals([false]),
        reason: '1回目のタップで onChanged(false) が 1 回だけ呼ばれているはずです。',
      );

      // in-flight 中に再タップ → onChanged は呼ばれない
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(
        calls,
        equals([false]),
        reason: 'in-flight 中の再タップで onChanged が二重起動しています。\n'
            '`_handleChanged` 内で in-flight フラグ（例: `_busy`）を持ち、'
            'true の間は早期 return するように直列化してください。\n'
            '連続タップで `previous` がずれる edge case の根本対策です。',
      );

      // 後始末: Future を完了させて pending timer を残さない
      gate.complete();
      await tester.pump();
    });

    testWidgets('onChanged が連続失敗しても最終的に Switch は初期値に復元される', (tester) async {
      // 目的: 連続タップで previous がずれる edge case を回帰防止。
      //   もし in-flight 再タップを抑制していれば、2 回目のタップで previous=false
      //   になることがないため、最終状態は true のままになる。
      final throwers = <Completer<void>>[Completer(), Completer()];
      int callIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                final c = throwers[callIndex.clamp(0, throwers.length - 1)];
                callIndex++;
                await c.future;
                throw Exception('failure #$callIndex');
              },
            ),
          ),
        ),
      );

      // 1回目タップ（失敗させる前に 2回目タップを試みる）
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // in-flight 中の 2回目タップ（無視されるべき）
      await tester.tap(find.byType(Switch));
      await tester.pump();

      // 1回目 onChanged を失敗させる → ロールバックで true に戻る
      throwers[0].completeError(StateError('drop'));
      // 念のため 2つ目も完了させる（直列化で orphan になる場合に備え、
      // 先に listener を付けてから completeError してから unhandled async error を防ぐ）
      // ignore: unawaited_futures
      throwers[1].future.catchError((_) {});
      if (!throwers[1].isCompleted) {
        throwers[1].completeError(StateError('drop2'));
      }
      // SnackBar アニメーションを少し進める（4s タイマーは待たない）
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Switch sw = tester.widget(find.byType(Switch));
      expect(
        sw.value,
        isTrue,
        reason: '連続タップ → 失敗時、Switch が初期値 true に戻っていません。\n'
            'in-flight 中の再タップを抑制すれば 2 回目の `previous = false` による'
            'ずれが発生しません。`_handleChanged` を直列化してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C] Cycle 2 テストヘッダの `initialValue` 除去
  // ══════════════════════════════════════════════════════════════

  group('analytics_opt_in_widget_test.dart — ヘッダ／reason 文言の `value` 追従', () {
    test('Cycle 2 テストファイルのヘッダコメントに `initialValue` が残っていないとき '
        'Cycle 3 の命名リネームと整合する', () {
      final content = _readCycle2TestFile();

      final hits = RegExp(r'initialValue').allMatches(content).length;
      expect(
        hits,
        equals(0),
        reason: '`test/screens/analytics_opt_in_widget_test.dart` 内に'
            ' `initialValue` という文字列が $hits 件残っています。\n'
            'Cycle 3 で `AnalyticsOptInTile` の引数は `value` にリネーム済みなので、'
            'ヘッダコメント・reason 文言の `initialValue` も `value` に統一してください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [D] Cycle 2 ロールバックテストの pumpAndSettle 除去
  // ══════════════════════════════════════════════════════════════

  group('analytics_opt_in_widget_test.dart — SnackBar 4s タイマー待ち迂回', () {
    test('Cycle 2 ロールバック testWidgets 群で `pumpAndSettle()` を使っていないとき '
        'SnackBar の 4 秒タイマー待ちが発生しない', () {
      final content = _readCycle2TestFile();

      // [C] Rollback グループ以降（"setOptIn 失敗時のロールバック"）に絞って検査
      final rollbackGroupIdx = content.indexOf('setOptIn 失敗時のロールバック');
      expect(
        rollbackGroupIdx,
        isNot(equals(-1)),
        reason: 'Cycle 2 テストの「setOptIn 失敗時のロールバック」group が見つかりません。\n'
            'group タイトルを変更した場合はこのテストの探索文字列も追従させてください。',
      );

      final rollbackBlock = content.substring(rollbackGroupIdx);
      final pumpAndSettleHits =
          RegExp(r'pumpAndSettle\s*\(').allMatches(rollbackBlock).length;

      expect(
        pumpAndSettleHits,
        equals(0),
        reason: 'ロールバック group 内で `pumpAndSettle()` が $pumpAndSettleHits 件'
            ' 使用されています。\n'
            'Cycle 3 で SnackBar が追加されたため `pumpAndSettle()` は SnackBar の'
            ' 4 秒タイマー完了まで待ってしまい、CI 時間を浪費します。\n'
            '`await tester.pump();` と '
            '`await tester.pump(const Duration(milliseconds: 100));` の'
            '組み合わせに置換してください（Cycle 3 テストと同じパターン）。',
      );
    });
  });
}
