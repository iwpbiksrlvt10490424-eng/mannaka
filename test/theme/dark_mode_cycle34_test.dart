// TDD Red フェーズ — Cycle 34
// ダークモード残件修正: navigationBarTheme 補完 & border 色修正
//
// スコープ:
//   1. navigationBarTheme — labelTextStyle (selected/unselected) を追加
//   2. navigationBarTheme — iconTheme (selected/unselected) を追加
//   3. AppColors.darkBorder — 新定数追加 Color(0xFF3A3A3C)
//   4. inputDecorationTheme の border/enabledBorder に darkBorder を適用

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: navigationBarTheme — labelTextStyle
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — navigationBarTheme labelTextStyle', () {
    test(
      'dark() の navigationBarTheme に labelTextStyle が設定されているとき ナビバーのラベルが Material3 デフォルト色にフォールバックしない',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final navBarIdx = afterDark.indexOf('navigationBarTheme');
        expect(navBarIdx, isNot(-1), reason: '前提: navigationBarTheme が存在しません。');

        // navigationBarTheme ブロック内に labelTextStyle が含まれているか
        final afterNavBar = afterDark.substring(navBarIdx);

        expect(
          afterNavBar.contains('labelTextStyle'),
          isTrue,
          reason:
              'dark() の navigationBarTheme 内に `labelTextStyle` が設定されていません。\n'
              '\n'
              '実装: light() と同構造で、unselected に Colors.white70 を使用してください:\n'
              '  labelTextStyle: WidgetStateProperty.resolveWith((states) {\n'
              '    if (states.contains(WidgetState.selected)) {\n'
              '      return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,\n'
              '          color: AppColors.primary, letterSpacing: -0.2);\n'
              '    }\n'
              '    return const TextStyle(fontSize: 11, color: Colors.white70);\n'
              '  }),',
        );
      },
    );

    test(
      'dark() の navigationBarTheme の labelTextStyle が unselected に white70 を使うとき ダークモードでラベルが視認できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final navBarIdx = afterDark.indexOf('navigationBarTheme');
        expect(navBarIdx, isNot(-1), reason: '前提: navigationBarTheme が存在しません。');

        final afterNavBar = afterDark.substring(navBarIdx);
        // labelTextStyle の範囲を特定
        final labelIdx = afterNavBar.indexOf('labelTextStyle');
        expect(labelIdx, isNot(-1), reason: '前提: labelTextStyle が存在しません。');

        final afterLabel = afterNavBar.substring(labelIdx);
        // white70 か white54 相当の色指定があるか
        expect(
          afterLabel.contains('white70') || afterLabel.contains('white54'),
          isTrue,
          reason:
              'labelTextStyle の unselected 状態に `Colors.white70` (または white54) が設定されていません。\n'
              '\n'
              '実装: unselected 時は Colors.white70 を使用してダークモードで視認できるようにしてください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: navigationBarTheme — iconTheme
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — navigationBarTheme iconTheme', () {
    test(
      'dark() の navigationBarTheme に iconTheme が設定されているとき ナビバーのアイコンが Material3 デフォルト色にフォールバックしない',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final navBarIdx = afterDark.indexOf('navigationBarTheme');
        expect(navBarIdx, isNot(-1), reason: '前提: navigationBarTheme が存在しません。');

        final afterNavBar = afterDark.substring(navBarIdx);

        expect(
          afterNavBar.contains('iconTheme'),
          isTrue,
          reason:
              'dark() の navigationBarTheme 内に `iconTheme` が設定されていません。\n'
              '\n'
              '実装: light() と同構造で、unselected に Colors.white70 を使用してください:\n'
              '  iconTheme: WidgetStateProperty.resolveWith((states) {\n'
              '    if (states.contains(WidgetState.selected)) {\n'
              '      return const IconThemeData(color: AppColors.primary, size: 22);\n'
              '    }\n'
              '    return const IconThemeData(color: Colors.white70, size: 22);\n'
              '  }),',
        );
      },
    );

    test(
      'dark() の navigationBarTheme の iconTheme が unselected に white70 を使うとき ダークモードでアイコンが視認できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final navBarIdx = afterDark.indexOf('navigationBarTheme');
        expect(navBarIdx, isNot(-1), reason: '前提: navigationBarTheme が存在しません。');

        final afterNavBar = afterDark.substring(navBarIdx);
        final iconIdx = afterNavBar.indexOf('iconTheme');
        expect(iconIdx, isNot(-1), reason: '前提: iconTheme が存在しません。');

        final afterIcon = afterNavBar.substring(iconIdx);
        expect(
          afterIcon.contains('white70') || afterIcon.contains('white54'),
          isTrue,
          reason:
              'iconTheme の unselected 状態に `Colors.white70` (または white54) が設定されていません。\n'
              '\n'
              '実装: unselected 時は Colors.white70 を使用してダークモードで視認できるようにしてください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: AppColors.darkBorder
  // ─────────────────────────────────────────────────────
  group('AppColors.darkBorder 定数', () {
    test(
      'AppColors に darkBorder 定数が定義されているとき ボーダー色が fillColor と区別できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        expect(
          content.contains('darkBorder'),
          isTrue,
          reason: '`AppColors.darkBorder` が定義されていません。\n'
              '\n'
              '実装: AppColors クラスに darkBorder 定数を追加してください:\n'
              '  static const Color darkBorder = Color(0xFF3A3A3C);\n'
              '\n'
              '（darkSurface = 0xFF1C1C1E と同色では border が不可視になるため分離が必要）',
        );
      },
    );

    test(
      'AppColors.darkBorder が Color(0xFF3A3A3C) であるとき iOS ダーク separator 色に準拠する',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        // darkBorder の定義行を探す
        final darkBorderIdx = content.indexOf('darkBorder');
        expect(darkBorderIdx, isNot(-1), reason: '前提: darkBorder が存在しません。');

        // 定義行の近傍（150文字以内）に 0xFF3A3A3C があるか
        final snippet = content.substring(
          darkBorderIdx,
          (darkBorderIdx + 150).clamp(0, content.length),
        );
        expect(
          snippet.contains('3A3A3C'),
          isTrue,
          reason:
              '`AppColors.darkBorder` の値が `Color(0xFF3A3A3C)` ではありません。\n'
              '\n'
              '実装: static const Color darkBorder = Color(0xFF3A3A3C); を設定してください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: inputDecorationTheme border/enabledBorder に darkBorder を適用
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — inputDecorationTheme border 色修正', () {
    test(
      'dark() の inputDecorationTheme.border が darkBorder を使うとき border が fillColor と同色にならず視認できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final inputIdx = afterDark.indexOf('inputDecorationTheme');
        expect(inputIdx, isNot(-1), reason: '前提: inputDecorationTheme が存在しません。');

        // inputDecorationTheme ブロック全体を contentPadding 以降まで取得
        // （hintStyle の '),\n' でブロックが切れないよう、focusedBorder 以降で終端を探す）
        final afterInput = afterDark.substring(inputIdx);
        final contentPaddingIdx = afterInput.indexOf('contentPadding');
        final inputBlock = contentPaddingIdx > 0
            ? afterInput.substring(0, contentPaddingIdx + 200)
            : afterInput.substring(0, afterInput.length.clamp(0, 1200));

        // border: OutlineInputBorder(...) のブロックを探す
        final borderIdx = inputBlock.indexOf('border:');
        expect(borderIdx, isNot(-1), reason: 'inputDecorationTheme 内に border: が見つかりません。');

        final borderSnippet = inputBlock.substring(borderIdx);

        // 現状: borderSide の color が darkSurface (0xFF1C1C1E) と同じ → 不可視
        // 期待: borderSide に darkBorder を使う
        expect(
          borderSnippet.contains('darkBorder'),
          isTrue,
          reason:
              'inputDecorationTheme の `border` に `darkBorder` が使われていません。\n'
              '\n'
              '問題: 現在 borderSide の color が darkSurface (0xFF1C1C1E) と同じため border が不可視。\n'
              '実装: border の borderSide を darkBorder に変更してください:\n'
              '  border: OutlineInputBorder(\n'
              '    borderRadius: BorderRadius.all(Radius.circular(12)),\n'
              '    borderSide: BorderSide(color: AppColors.darkBorder),\n'
              '  ),',
        );
      },
    );

    test(
      'dark() の inputDecorationTheme.enabledBorder が darkBorder を使うとき 非フォーカス時の border が視認できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final inputIdx = afterDark.indexOf('inputDecorationTheme');
        expect(inputIdx, isNot(-1), reason: '前提: inputDecorationTheme が存在しません。');

        // inputDecorationTheme ブロック全体を contentPadding まで取得
        final afterInput = afterDark.substring(inputIdx);
        final contentPaddingIdx = afterInput.indexOf('contentPadding');
        final inputBlock = contentPaddingIdx > 0
            ? afterInput.substring(0, contentPaddingIdx + 200)
            : afterInput.substring(0, afterInput.length.clamp(0, 1200));

        // enabledBorder ブロックを探す
        final enabledIdx = inputBlock.indexOf('enabledBorder');
        expect(enabledIdx, isNot(-1),
            reason: 'inputDecorationTheme 内に enabledBorder が見つかりません。');

        final afterEnabled = inputBlock.substring(enabledIdx);

        expect(
          afterEnabled.contains('darkBorder'),
          isTrue,
          reason:
              'inputDecorationTheme の `enabledBorder` に `darkBorder` が使われていません。\n'
              '\n'
              '問題: 現在 borderSide の color が darkSurface (0xFF1C1C1E) と同じため enabledBorder が不可視。\n'
              '実装: enabledBorder の borderSide を darkBorder に変更してください:\n'
              '  enabledBorder: OutlineInputBorder(\n'
              '    borderRadius: BorderRadius.all(Radius.circular(12)),\n'
              '    borderSide: BorderSide(color: AppColors.darkBorder),\n'
              '  ),',
        );
      },
    );
  });
}
