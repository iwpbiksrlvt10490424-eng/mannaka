// TDD Red フェーズ — Cycle 33
// ダークモード完成化: AppTheme.dark() 欠落テーマ補完 & darkCardBg 導入
//
// スコープ:
//   1. navigationBarTheme — darkSurface 背景 + primary インジケーター
//   2. inputDecorationTheme — darkSurface fill + primary フォーカスボーダー
//   3. dividerTheme — iOS ダーク区切り線色 Color(0xFF3A3A3C)
//   4. AppBar shadowColor — Colors.black 追加
//   5. AppColors.darkCardBg — const 追加 & cardTheme.color に適用

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: navigationBarTheme
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — navigationBarTheme', () {
    test(
      'dark() に navigationBarTheme が設定されているとき ダークモードのナビバーが Material3 デフォルト色にならない',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        expect(
          afterDark.contains('navigationBarTheme'),
          isTrue,
          reason: 'dark() 内に `navigationBarTheme` が見つかりません。\n'
              '\n'
              '実装: dark() に navigationBarTheme を追加してください:\n'
              '  navigationBarTheme: NavigationBarThemeData(\n'
              '    backgroundColor: AppColors.darkSurface,\n'
              '    indicatorColor: AppColors.primary.withValues(alpha: 0.2),\n'
              '    ...\n'
              '  ),',
        );
      },
    );

    test(
      'dark() の navigationBarTheme が darkSurface 背景を持つとき ナビバー背景がダーク対応になる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        // navigationBarTheme ブロック内に darkSurface が参照されていることを確認
        final navBarIdx = afterDark.indexOf('navigationBarTheme');
        expect(navBarIdx, isNot(-1), reason: '前提: navigationBarTheme が存在しません。');

        // navigationBarTheme 定義の後方に darkSurface が登場するか確認
        final afterNavBar = afterDark.substring(navBarIdx);
        // darkSurface は NavigationBarThemeData の背景として使われる
        // 直後の閉じ括弧までの範囲で確認
        final closingParen = afterNavBar.indexOf('),');
        final navBarBlock = closingParen > 0
            ? afterNavBar.substring(0, closingParen)
            : afterNavBar.substring(0, afterNavBar.length.clamp(0, 500));

        expect(
          navBarBlock.contains('darkSurface'),
          isTrue,
          reason: 'navigationBarTheme 内に `darkSurface` 背景色が設定されていません。\n'
              '\n'
              '実装: backgroundColor: AppColors.darkSurface を設定してください。',
        );
      },
    );

    test(
      'dark() の navigationBarTheme に primary インジケーターが設定されているとき 選択アイテムのブランドカラーが維持される',
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
          afterNavBar.contains('indicatorColor'),
          isTrue,
          reason: 'navigationBarTheme 内に `indicatorColor` が設定されていません。\n'
              '\n'
              '実装: indicatorColor: AppColors.primary.withValues(alpha: 0.2) を追加してください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: inputDecorationTheme
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — inputDecorationTheme', () {
    test(
      'dark() に inputDecorationTheme が設定されているとき フォームがダーク対応になる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        expect(
          afterDark.contains('inputDecorationTheme'),
          isTrue,
          reason: 'dark() 内に `inputDecorationTheme` が見つかりません。\n'
              '\n'
              '実装: dark() に inputDecorationTheme を追加してください:\n'
              '  inputDecorationTheme: InputDecorationTheme(\n'
              '    filled: true,\n'
              '    fillColor: AppColors.darkSurface,\n'
              '    focusedBorder: OutlineInputBorder(\n'
              '      borderSide: BorderSide(color: primary, width: 1.5),\n'
              '    ),\n'
              '  ),',
        );
      },
    );

    test(
      'dark() の inputDecorationTheme が filled: true を持つとき 入力フィールドに背景色が適用される',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final inputIdx = afterDark.indexOf('inputDecorationTheme');
        expect(inputIdx, isNot(-1), reason: '前提: inputDecorationTheme が存在しません。');

        final afterInput = afterDark.substring(inputIdx);
        expect(
          afterInput.contains('filled: true'),
          isTrue,
          reason: 'inputDecorationTheme 内に `filled: true` が設定されていません。\n'
              '\n'
              '実装: filled: true を追加してください。',
        );
      },
    );

    test(
      'dark() の inputDecorationTheme の fillColor が darkSurface であるとき フォーム背景がダーク対応になる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final inputIdx = afterDark.indexOf('inputDecorationTheme');
        expect(inputIdx, isNot(-1), reason: '前提: inputDecorationTheme が存在しません。');

        final afterInput = afterDark.substring(inputIdx);
        expect(
          afterInput.contains('darkSurface'),
          isTrue,
          reason: 'inputDecorationTheme 内に `darkSurface` fillColor が設定されていません。\n'
              '\n'
              '実装: fillColor: AppColors.darkSurface を設定してください。',
        );
      },
    );

    test(
      'dark() の inputDecorationTheme に primary フォーカスボーダーが設定されているとき フォーカス時のブランドカラーが維持される',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final inputIdx = afterDark.indexOf('inputDecorationTheme');
        expect(inputIdx, isNot(-1), reason: '前提: inputDecorationTheme が存在しません。');

        final afterInput = afterDark.substring(inputIdx);
        expect(
          afterInput.contains('focusedBorder'),
          isTrue,
          reason: 'inputDecorationTheme 内に `focusedBorder` が設定されていません。\n'
              '\n'
              '実装: focusedBorder に primary カラーのボーダーを追加してください:\n'
              '  focusedBorder: OutlineInputBorder(\n'
              '    borderRadius: BorderRadius.all(Radius.circular(12)),\n'
              '    borderSide: BorderSide(color: primary, width: 1.5),\n'
              '  ),',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: dividerTheme
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — dividerTheme', () {
    test(
      'dark() に dividerTheme が設定されているとき 区切り線がダーク対応になる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        expect(
          afterDark.contains('dividerTheme'),
          isTrue,
          reason: 'dark() 内に `dividerTheme` が見つかりません。\n'
              '\n'
              '実装: dark() に dividerTheme を追加してください:\n'
              '  dividerTheme: const DividerThemeData(\n'
              '    color: Color(0xFF3A3A3C),\n'
              '    thickness: 1,\n'
              '    space: 1,\n'
              '  ),',
        );
      },
    );

    test(
      'dark() の dividerTheme が iOS ダーク区切り線色 0xFF3A3A3C を使用するとき ネイティブ iOS 準拠のデザインになる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final dividerIdx = afterDark.indexOf('dividerTheme');
        expect(dividerIdx, isNot(-1), reason: '前提: dividerTheme が存在しません。');

        final afterDivider = afterDark.substring(dividerIdx);
        expect(
          afterDivider.contains('3A3A3C'),
          isTrue,
          reason: 'dividerTheme 内に iOS ダーク区切り線色 `0xFF3A3A3C` が設定されていません。\n'
              '\n'
              '実装: color: const Color(0xFF3A3A3C) を設定してください。\n'
              '（iOS separator dark: #3A3A3C に準拠）',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: AppBar shadowColor
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() — AppBar shadowColor', () {
    test(
      'dark() の appBarTheme に shadowColor が設定されているとき ライトモードと非対称にならない',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final appBarIdx = afterDark.indexOf('appBarTheme');
        expect(appBarIdx, isNot(-1), reason: '前提: appBarTheme が dark() 内に存在しません。');

        // appBarTheme ブロック内（次の '),' まで）に shadowColor が含まれているか
        final afterAppBar = afterDark.substring(appBarIdx);
        // AppBarTheme ブロックの終わり（最初の '), 'に相当する部分）
        final blockEnd = afterAppBar.indexOf('),\n');
        final appBarBlock = blockEnd > 0
            ? afterAppBar.substring(0, blockEnd)
            : afterAppBar.substring(0, afterAppBar.length.clamp(0, 600));

        expect(
          appBarBlock.contains('shadowColor'),
          isTrue,
          reason: 'dark() の appBarTheme 内に `shadowColor` が設定されていません。\n'
              '\n'
              '実装: appBarTheme に shadowColor を追加してください:\n'
              '  shadowColor: Colors.black,\n'
              '\n'
              'ライトモードでは AppColors.divider が使われているため、ダークモードでも設定が必要です。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ5: AppColors.darkCardBg & cardTheme
  // ─────────────────────────────────────────────────────
  group('AppColors.darkCardBg と cardTheme', () {
    test(
      'AppColors に darkCardBg 定数が定義されているとき カードのダーク背景色が使用できる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        expect(
          content.contains('darkCardBg'),
          isTrue,
          reason: '`AppColors.darkCardBg` が定義されていません。\n'
              '\n'
              '実装: AppColors クラスに darkCardBg 定数を追加してください:\n'
              '  static const Color darkCardBg = Color(0xFF2C2C2E);\n'
              '\n'
              '（iOS grouped secondary background dark: #2C2C2E に準拠）',
        );
      },
    );

    test(
      'dark() に cardTheme が設定されているとき カードにダーク背景色が適用される',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        expect(
          afterDark.contains('cardTheme'),
          isTrue,
          reason: 'dark() 内に `cardTheme` が見つかりません。\n'
              '\n'
              '実装: dark() に cardTheme を追加してください:\n'
              '  cardTheme: const CardThemeData(\n'
              '    color: AppColors.darkCardBg,\n'
              '  ),',
        );
      },
    );

    test(
      'dark() の cardTheme が darkCardBg を使用するとき カード背景がダーク対応になる',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) fail('lib/theme/app_theme.dart が存在しません。');
        final content = file.readAsStringSync();

        final darkStart = content.indexOf('static ThemeData dark()');
        expect(darkStart, isNot(-1), reason: '前提: dark() が存在しません。');

        final afterDark = content.substring(darkStart);
        final cardIdx = afterDark.indexOf('cardTheme');
        expect(cardIdx, isNot(-1), reason: '前提: cardTheme が存在しません。');

        final afterCard = afterDark.substring(cardIdx);
        expect(
          afterCard.contains('darkCardBg'),
          isTrue,
          reason: 'cardTheme 内に `darkCardBg` が設定されていません。\n'
              '\n'
              '実装: color: AppColors.darkCardBg を設定してください。',
        );
      },
    );
  });
}
