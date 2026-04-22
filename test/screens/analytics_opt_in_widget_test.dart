// TDD Red フェーズ（Cycle 2）
// 分析 opt-in UI の Critic Cycle 1 指摘修正テスト
//
// スコープ（review_feedback.md より）:
//   1. [WARNING] `_AnalyticsOptInTile` の vertical padding 10 が隣接 `_NavItem` の 14 と不揃い
//      （settings_screen.dart:1158）
//   2. [ISSUE]   トグル楽観更新で `setOptIn` 失敗時のロールバック無し
//      （settings_screen.dart:554-558）
//   3. [WARNING] 既存テストが regex マッチのみで Widget E2E 未検証
//      （偽グリーン余地）
//
// 受け入れ条件:
//   A. `_AnalyticsOptInTile` の vertical padding が `_NavItem` と同じ値 (14) である
//   B. `AnalyticsOptInTile` が public なウィジェットとして import 可能で
//      `flutter_test` から pumpWidget で実インスタンス化できる（E2E 検証可能性）
//   C. onChanged が例外を投げたとき、Switch の表示値は元（value）に戻る
//      （楽観更新のロールバック）
//
// Engineer への依頼:
//   - `_AnalyticsOptInTile` を public `AnalyticsOptInTile` にリネーム（テスト用）
//   - `StatefulWidget` 化し、`value` と
//     `Future<void> Function(bool) onChanged` を受け取る
//   - onChanged await 中に例外が発生したら setState で元の値に戻す
//   - vertical padding を 14 に変更
//   - SettingsScreen 側は `AnalyticsOptInTile(value: _analyticsOptIn,
//     onChanged: AnalyticsService.setOptIn)` のように呼び出し形を整える

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/screens/settings_screen.dart';

String _readSettingsScreen() {
  final file = File('lib/screens/settings_screen.dart');
  if (!file.existsSync()) {
    fail('lib/screens/settings_screen.dart が見つかりません。');
  }
  return file.readAsStringSync();
}

void main() {
  // ══════════════════════════════════════════════════════════════
  // [A] Padding alignment — _NavItem と _AnalyticsOptInTile の
  //     vertical padding が一致している
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — _NavItem と AnalyticsOptInTile の余白整列', () {
    test('AnalyticsOptInTile の vertical padding が _NavItem と一致するとき'
        ' 設定セクション内で高さが揃う', () {
      final content = _readSettingsScreen();

      final navItemMatch = RegExp(
        r'class _NavItem[\s\S]*?Widget build[\s\S]*?'
        r'EdgeInsets\.symmetric\([^)]*?vertical:\s*(\d+)',
      ).firstMatch(content);

      final tileMatch = RegExp(
        r'class _?AnalyticsOptInTile[\s\S]*?Widget build[\s\S]*?'
        r'EdgeInsets\.symmetric\([^)]*?vertical:\s*(\d+)',
      ).firstMatch(content);

      expect(
        navItemMatch,
        isNotNull,
        reason: '_NavItem の vertical padding を抽出できませんでした。'
            'クラス定義または EdgeInsets.symmetric が変わっていないか確認してください。',
      );
      expect(
        tileMatch,
        isNotNull,
        reason: 'AnalyticsOptInTile の vertical padding を抽出できませんでした。'
            'クラス名（public か private か）と EdgeInsets.symmetric を確認してください。',
      );

      final navV = navItemMatch!.group(1);
      final tileV = tileMatch!.group(1);
      expect(
        tileV,
        equals(navV),
        reason: '設定画面で隣り合う _NavItem (vertical=$navV) と '
            'AnalyticsOptInTile (vertical=$tileV) の padding が揃っていません。\n'
            'ユーザー目線で高さが不揃いに見えるため、AnalyticsOptInTile を vertical=$navV に'
            '合わせてください。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [B] Widget E2E — AnalyticsOptInTile が pumpWidget で生成でき、
  //     Switch タップで onChanged が呼ばれる
  // ══════════════════════════════════════════════════════════════

  group('AnalyticsOptInTile — Widget E2E', () {
    testWidgets('初期値 true のときに「利用統計の提供」ラベルが表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {},
            ),
          ),
        ),
      );

      expect(
        find.text('利用統計の提供'),
        findsOneWidget,
        reason: 'AnalyticsOptInTile はユーザーに何の設定か伝えるラベル「利用統計の提供」を'
            '表示する必要があります。',
      );
    });

    testWidgets('Switch をタップしたとき onChanged に反転した値が渡される', (tester) async {
      final received = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                received.add(v);
              },
            ),
          ),
        ),
      );

      final switchFinder = find.byType(Switch);
      expect(
        switchFinder,
        findsOneWidget,
        reason: 'Switch が見つかりません。Android テーマで Switch.adaptive は'
            ' Switch を描画するはずです。',
      );

      await tester.tap(switchFinder);
      await tester.pump();

      expect(
        received,
        equals([false]),
        reason: '初期値 true の Switch をタップしたら false で onChanged が呼ばれるべきです。',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [C] Rollback — onChanged が例外を投げたとき Switch 表示が戻る
  // ══════════════════════════════════════════════════════════════

  group('AnalyticsOptInTile — setOptIn 失敗時のロールバック', () {
    testWidgets('onChanged が例外を投げたとき Switch の表示値は初期値に戻る', (tester) async {
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

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      // onChanged の Future が完結 → ロールバック setState までを反映
      // （SnackBar の 4s タイマーは待たずに pump(100ms) で迂回）
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Switch sw = tester.widget(switchFinder);
      expect(
        sw.value,
        isTrue,
        reason: 'onChanged が例外を投げたにもかかわらず Switch が false のままです。\n'
            'AnalyticsOptInTile を StatefulWidget 化し、楽観更新の後 onChanged を'
            ' try/catch で囲み、失敗時は setState で初期値に戻してください。\n'
            '（現状 settings_screen.dart:554-558 の onChanged は rollback 無し）',
      );
    });

    testWidgets('onChanged が成功したとき Switch は反転した値で固定される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: AnalyticsOptInTile(
              value: true,
              onChanged: (v) async {
                // 成功ケース: 何もせず完了
              },
            ),
          ),
        ),
      );

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Switch sw = tester.widget(switchFinder);
      expect(
        sw.value,
        isFalse,
        reason: '成功時には楽観更新がそのまま確定し Switch は false で固定されるべきです。',
      );
    });
  });
}
