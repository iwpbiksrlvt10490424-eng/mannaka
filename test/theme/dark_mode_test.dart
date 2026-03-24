// TDD Red フェーズ
// ダークモード対応
//
// スコープ:
//   システムのダークモード設定に自動追従する ThemeData を追加する。
//   - AppTheme.dark() メソッドを新設する
//   - AimaApp に darkTheme / themeMode: ThemeMode.system を設定する
//   - ダークモード時は暗い背景色・明るい文字色になる
//   - プライマリカラー (#FF6B81) はダークモードでも維持される
//
// CLAUDE.md 参照:
//   - Primary: #FF6B81（コーラルピンク）
//   - 背景: Color(0xFFF7F7F7)（ライトモード）
//   - カード: white, borderRadius 12, BoxShadow

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: AppTheme.dark() メソッドの存在確認
  // ─────────────────────────────────────────────────────
  group('AppTheme.dark() メソッドの定義', () {
    test(
      'app_theme.dart に dark() メソッドが存在するとき ダークテーマが定義されている',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) {
          fail('lib/theme/app_theme.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        expect(
          content.contains('static ThemeData dark()'),
          isTrue,
          reason: 'lib/theme/app_theme.dart に `static ThemeData dark()` が見つかりません。\n'
              '\n'
              '実装: AppTheme クラスに dark() メソッドを追加してください:\n'
              '  static ThemeData dark() {\n'
              '    return ThemeData(\n'
              '      useMaterial3: true,\n'
              '      brightness: Brightness.dark,\n'
              '      ...\n'
              '    );\n'
              '  }',
        );
      },
    );

    test(
      'dark() メソッドが Brightness.dark を含むとき 正しいテーマモードが設定されている',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) {
          fail('lib/theme/app_theme.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // dark() メソッドの中に Brightness.dark が含まれていることを確認
        // （light() の ColorScheme.fromSeed で Brightness.light が使われているため
        //   単純な contains ではなく、dark() 定義の後に現れることを確認する）
        final darkMethodIndex = content.indexOf('static ThemeData dark()');
        expect(
          darkMethodIndex,
          isNot(-1),
          reason: '前提: dark() メソッドが存在しません。',
        );

        final afterDark = content.substring(darkMethodIndex);
        expect(
          afterDark.contains('Brightness.dark'),
          isTrue,
          reason: 'dark() メソッド内に `Brightness.dark` が見つかりません。\n'
              '\n'
              '実装: ColorScheme.fromSeed() に brightness: Brightness.dark を設定してください:\n'
              '  colorScheme: ColorScheme.fromSeed(\n'
              '    seedColor: primary,\n'
              '    brightness: Brightness.dark,\n'
              '  ),',
        );
      },
    );

    test(
      'dark() メソッドにダーク用 scaffoldBackgroundColor が設定されているとき 背景色がライトモードと区別される',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) {
          fail('lib/theme/app_theme.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        final darkMethodIndex = content.indexOf('static ThemeData dark()');
        expect(
          darkMethodIndex,
          isNot(-1),
          reason: '前提: dark() メソッドが存在しません。',
        );

        final afterDark = content.substring(darkMethodIndex);
        expect(
          afterDark.contains('scaffoldBackgroundColor'),
          isTrue,
          reason: 'dark() メソッド内に `scaffoldBackgroundColor` が設定されていません。\n'
              '\n'
              '実装: ダーク用の暗い背景色を設定してください:\n'
              '  scaffoldBackgroundColor: const Color(0xFF0F0F0F), // または Color(0xFF121212)',
        );
      },
    );

    test(
      'dark() メソッドにプライマリカラー #FF6B81 が維持されているとき ブランドカラーが一貫している',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) {
          fail('lib/theme/app_theme.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        final darkMethodIndex = content.indexOf('static ThemeData dark()');
        expect(
          darkMethodIndex,
          isNot(-1),
          reason: '前提: dark() メソッドが存在しません。',
        );

        // primary は AppColors.primary (0xFFFF6B81) を参照するはず
        // dark() 内で primary 変数または AppColors.primary を使っていることを確認
        final afterDark = content.substring(darkMethodIndex);
        final hasPrimary = afterDark.contains('AppColors.primary') ||
            afterDark.contains('FF6B81') ||
            afterDark.contains('primary');
        expect(
          hasPrimary,
          isTrue,
          reason: 'dark() メソッド内にプライマリカラー参照が見つかりません。\n'
              '\n'
              '実装: light() と同様に primary カラーを seed として使用してください:\n'
              "  const primary = AppColors.primary; // Color(0xFFFF6B81)\n"
              '  colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark)',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: AimaApp への darkTheme / themeMode 設定
  // ─────────────────────────────────────────────────────
  group('AimaApp ダークモード設定', () {
    test(
      'app.dart に darkTheme が設定されているとき ダークモード時に dark テーマが適用される',
      () {
        final file = File('lib/app.dart');
        if (!file.existsSync()) {
          fail('lib/app.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        expect(
          content.contains('darkTheme:'),
          isTrue,
          reason: 'lib/app.dart に `darkTheme:` が見つかりません。\n'
              '\n'
              '実装: MaterialApp に darkTheme を追加してください:\n'
              '  MaterialApp(\n'
              '    theme: AppTheme.light(),\n'
              '    darkTheme: AppTheme.dark(),   // ← 追加\n'
              '    themeMode: ThemeMode.system,  // ← 追加\n'
              '    ...\n'
              '  )',
        );
      },
    );

    test(
      'app.dart に ThemeMode.system が設定されているとき iOS のシステム設定に自動追従する',
      () {
        final file = File('lib/app.dart');
        if (!file.existsSync()) {
          fail('lib/app.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        expect(
          content.contains('ThemeMode.system'),
          isTrue,
          reason: 'lib/app.dart に `ThemeMode.system` が見つかりません。\n'
              '\n'
              '実装: MaterialApp に themeMode を追加してください:\n'
              '  themeMode: ThemeMode.system,\n'
              '\n'
              'これにより iOS の設定 > 画面表示と明るさ > ダーク に追従します。',
        );
      },
    );

    test(
      'app.dart の darkTheme が AppTheme.dark() を参照しているとき テーマが正しく接続されている',
      () {
        final file = File('lib/app.dart');
        if (!file.existsSync()) {
          fail('lib/app.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        expect(
          content.contains('AppTheme.dark()'),
          isTrue,
          reason: 'lib/app.dart に `AppTheme.dark()` 呼び出しが見つかりません。\n'
              '\n'
              '実装: darkTheme に AppTheme.dark() を渡してください:\n'
              '  darkTheme: AppTheme.dark(),',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: ダークモード用 AppColors 定義
  // ─────────────────────────────────────────────────────
  group('AppColors ダークモード対応', () {
    test(
      'app_theme.dart にダーク用背景色定義が存在するとき ダークモードの視認性が確保されている',
      () {
        final file = File('lib/theme/app_theme.dart');
        if (!file.existsSync()) {
          fail('lib/theme/app_theme.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // ダーク用の暗い背景色 (例: 0xFF0F0F0F, 0xFF121212, 0xFF1C1C1E など iOS ダーク標準)
        // または darkBackground という名前の定数が定義されていることを確認
        final hasDarkBg = content.contains('darkBackground') ||
            content.contains('0xFF0F0F') ||
            content.contains('0xFF121212') ||
            content.contains('0xFF1C1C1E') ||
            content.contains('0xFF111111');
        expect(
          hasDarkBg,
          isTrue,
          reason: 'lib/theme/app_theme.dart にダーク用背景色が定義されていません。\n'
              '\n'
              '実装: AppColors にダーク背景色定数を追加してください:\n'
              '  static const Color darkBackground = Color(0xFF0F0F0F);\n'
              '  static const Color darkSurface    = Color(0xFF1C1C1E);\n'
              '\n'
              'iOS ダークモード標準: システム背景 #000000, グループ背景 #1C1C1E',
        );
      },
    );
  });
}
