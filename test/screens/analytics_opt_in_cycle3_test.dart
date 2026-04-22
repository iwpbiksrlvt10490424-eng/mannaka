// TDD Red フェーズ（Cycle 3）
// 分析 opt-in トグル — Critic Cycle 2 残課題の修正テスト
//
// スコープ（current_task.md / review_feedback.md より）:
//   1. [ISSUE / UX バグ]
//      `_handleChanged` の `catch (_)` がサイレントで、`setOptIn` 失敗時に
//      ユーザーが失敗に気付けない（`settings_screen.dart:1179`）。
//      分析 opt-out は意思表示なので黙って失敗させるべきでない。
//   2. [WARNING / 命名]
//      コンストラクタ引数 `initialValue` が `didUpdateWidget` でリアクティブに
//      取り込まれている（`settings_screen.dart:1153, 1167-1172`）ため、
//      「初期値」という名前と実態が乖離している。`value` に改名すべき。
//
// 受け入れ条件:
//   A. `AnalyticsOptInTile` のコンストラクタ引数名が `value`（`initialValue` ではない）
//      — 実態（リアクティブ値）と名前が一致する。
//   B. `onChanged` が例外を投げたとき `SnackBar` で失敗フィードバックが表示される
//      — `catch (_)` でサイレントに握り潰さない。
//   C. `onChanged` が成功したとき `SnackBar` は表示されない
//      — 成功時にまでエラーフィードバックを出さない（誤発火防止）。
//   D. 失敗フィードバックの文言に生の例外メッセージ（`$e` / `Exception:` 等）が
//      含まれない — 内部エラーの露出防止（`snackbar_error_exposure_test.dart` 方針と整合）。
//
// Engineer への実装依頼:
//   - `AnalyticsOptInTile` の `initialValue` を `value` に一括リネーム
//     （コンストラクタ引数 / `widget.xxx` 参照 / `didUpdateWidget` の比較 / 呼び出し側
//     `settings_screen.dart:552-559`）。既存テスト `analytics_opt_in_widget_test.dart`
//     もあわせて `value:` に更新すること。
//   - `_AnalyticsOptInTileState._handleChanged` の `catch` で:
//       a. ロールバック (`setState` で previous に戻す) はそのまま維持
//       b. `ScaffoldMessenger.of(context).showSnackBar(...)` で固定文言の
//          SnackBar を表示（例: 「設定の保存に失敗しました。時間をおいて再度お試しください。」）
//       c. `mounted` チェックを先に行う
//       d. 生の例外 (`$e`) は含めない

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/screens/settings_screen.dart';

String _readSettingsScreen() {
  final file = File('lib/screens/settings_screen.dart');
  if (!file.existsSync()) {
    fail(
      'lib/screens/settings_screen.dart が見つかりません。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [A] 命名: initialValue → value リネーム
  // ══════════════════════════════════════════════════════════════

  group('AnalyticsOptInTile — コンストラクタ引数の命名', () {
    test('AnalyticsOptInTile が required this.value を受け取るとき '
        '実態（リアクティブ値）と名前が一致する', () {
      final content = _readSettingsScreen();

      // クラス定義ブロックを抽出
      final classBlock = RegExp(
        r'class AnalyticsOptInTile extends StatefulWidget[\s\S]*?State<AnalyticsOptInTile>',
      ).firstMatch(content);
      expect(
        classBlock,
        isNotNull,
        reason: 'class AnalyticsOptInTile extends StatefulWidget 定義を抽出できませんでした。\n'
            'クラス名・継承関係が変わっていないか確認してください。',
      );

      final block = classBlock!.group(0)!;

      // required this.value が存在する
      final hasValueParam = RegExp(r'required\s+this\.value\s*,').hasMatch(block);
      // required this.initialValue は存在しない
      final hasInitialValueParam =
          RegExp(r'required\s+this\.initialValue\s*,').hasMatch(block);

      expect(
        hasValueParam,
        isTrue,
        reason: 'AnalyticsOptInTile のコンストラクタに `required this.value` が見つかりません。\n'
            '`didUpdateWidget` でリアクティブに取り込んでいるため「initialValue」は'
            '実態と乖離しています。`value` に改名してください。',
      );
      expect(
        hasInitialValueParam,
        isFalse,
        reason: 'AnalyticsOptInTile のコンストラクタに `required this.initialValue` が'
            '残っています。`value` に改名し、フィールド名・`didUpdateWidget` の比較も'
            '一括で更新してください。',
      );
    });

    test('AnalyticsOptInTile のフィールド宣言が final bool value のとき '
        '外部 API として命名が統一される', () {
      final content = _readSettingsScreen();

      final classBlock = RegExp(
        r'class AnalyticsOptInTile extends StatefulWidget[\s\S]*?State<AnalyticsOptInTile>',
      ).firstMatch(content);
      expect(classBlock, isNotNull);

      final block = classBlock!.group(0)!;
      // `final bool value;` のようなフィールド宣言
      final hasValueField = RegExp(r'final\s+bool\s+value\s*;').hasMatch(block);
      final hasInitialValueField =
          RegExp(r'final\s+bool\s+initialValue\s*;').hasMatch(block);

      expect(
        hasValueField,
        isTrue,
        reason: 'AnalyticsOptInTile のフィールドに `final bool value;` が見つかりません。\n'
            'コンストラクタ引数の改名にあわせてフィールドも `value` にしてください。',
      );
      expect(
        hasInitialValueField,
        isFalse,
        reason: 'AnalyticsOptInTile に `final bool initialValue;` が残っています。',
      );
    });

    test('SettingsScreen 側の呼び出しが AnalyticsOptInTile(value: ...) のとき '
        '呼び出し側と API が整合する', () {
      final content = _readSettingsScreen();

      // AnalyticsOptInTile( ... ) の呼び出し箇所を抽出
      final callMatch = RegExp(
        r'AnalyticsOptInTile\s*\(\s*([\s\S]*?)\)\s*,',
      ).firstMatch(content);
      expect(
        callMatch,
        isNotNull,
        reason: 'AnalyticsOptInTile(...) の呼び出しが見つかりません。',
      );

      final args = callMatch!.group(1)!;
      expect(
        RegExp(r'\bvalue\s*:').hasMatch(args),
        isTrue,
        reason: 'AnalyticsOptInTile の呼び出しに `value:` 名前付き引数が見つかりません。\n'
            '`initialValue:` から `value:` に更新してください。',
      );
      expect(
        RegExp(r'\binitialValue\s*:').hasMatch(args),
        isFalse,
        reason: 'AnalyticsOptInTile の呼び出しに `initialValue:` が残っています。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [B] setOptIn 失敗時のユーザーフィードバック (SnackBar)
  // ══════════════════════════════════════════════════════════════

  group('AnalyticsOptInTile — setOptIn 失敗時のフィードバック', () {
    testWidgets('onChanged が例外を投げたとき SnackBar が表示される '
        '（ユーザーが失敗に気付ける）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                throw Exception('simulated SharedPreferences failure');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      // onChanged の Future 完結 → catch 節で SnackBar 表示 → アニメーション進行
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'onChanged が例外を投げたのに SnackBar が表示されていません。\n'
            '`catch (_)` がサイレントになっている現状では、ユーザーは'
            '設定保存の失敗に気付けません。\n'
            '`_handleChanged` の catch 節で `ScaffoldMessenger.of(context).showSnackBar(...)` '
            'を呼び、ユーザーに固定文言で失敗を知らせてください。',
      );
    });

    testWidgets('onChanged が例外を投げたとき SnackBar 文言に生の例外は含まれない '
        '（内部エラー露出防止）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                throw Exception('INTERNAL_SECRET_PATH_LEAK');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SnackBar 文言に例外メッセージ/Exception プレフィックスが含まれない
      expect(
        find.textContaining('INTERNAL_SECRET_PATH_LEAK'),
        findsNothing,
        reason: 'SnackBar に生の例外メッセージが表示されています。\n'
            '`\$e` のような形式ではなく、固定文言（例: 「設定の保存に失敗しました。'
            '時間をおいて再度お試しください。」）で表示してください。\n'
            '（`snackbar_error_exposure_test.dart` と同じセキュリティ方針）',
      );
      expect(
        find.textContaining('Exception:'),
        findsNothing,
        reason: 'SnackBar に `Exception:` プレフィックスが出ています。固定文言にしてください。',
      );
    });

    testWidgets('onChanged が成功したとき SnackBar は表示されない '
        '（誤発火防止）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                // 成功ケース: 何もしない
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'onChanged が成功しているのに SnackBar が表示されました。\n'
            '失敗時のみ SnackBar を出すようにしてください（`catch` 節のみで `show`）。',
      );
    });

    testWidgets('onChanged が例外を投げたあとも Switch の値はロールバックされる '
        '（Cycle 2 の挙動を回帰させない）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                throw Exception('x');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Switch sw = tester.widget(find.byType(Switch));
      expect(
        sw.value,
        isTrue,
        reason: 'ロールバックが効いていません。SnackBar 追加で既存のロールバック挙動を'
            '壊してはいけません（Cycle 2 の受け入れ条件）。',
      );
    });
  });
}
