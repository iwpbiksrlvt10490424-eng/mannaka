// TDD Red テスト: Cycle 1 Critic指摘修正
//
// 受け入れ条件:
//   1. ranking_screen.dart:121 の「Aimachichi指数」→「Aimachi指数」タイポ修正
//   2. share_utils.dart の _appStoreUrl → public appStoreUrl に変更
//   3. share_preview_screen.dart:93 の URL直書き → ShareUtils.appStoreUrl 使用
//   4. settings_screen.dart (3箇所) の URL直書き → ShareUtils.appStoreUrl 使用
//
// 注: 実装前の Red テスト。現状すべて FAIL する。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ══════════════════════════════════════════════════════════════
  // [1] ranking_screen.dart — 「Aimachichi」タイポが存在しないこと
  // ══════════════════════════════════════════════════════════════

  group('ranking_screen — Aimachichi タイポ修正', () {
    test('ranking_screen.dart に「Aimachichi」が残っていないとき', () {
      final file = File('lib/screens/ranking_screen.dart');
      expect(file.existsSync(), isTrue,
          reason: 'ranking_screen.dart が存在しません');

      final content = file.readAsStringSync();
      expect(content, isNot(contains('Aimachichi')),
          reason: '「Aimachichi指数」タイポが残っています。'
              '「Aimachi指数」に修正してください。');
    });

    test('ranking_screen.dart に「Aimachi指数」が存在するとき', () {
      final file = File('lib/screens/ranking_screen.dart');
      final content = file.readAsStringSync();
      expect(content, contains('Aimachi指数'),
          reason: '修正後「Aimachi指数」が存在するべきです');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [2] share_utils.dart — appStoreUrl が public であること
  // ══════════════════════════════════════════════════════════════

  group('share_utils — appStoreUrl public化', () {
    test('share_utils.dart に public な appStoreUrl 定数が存在するとき', () {
      final file = File('lib/utils/share_utils.dart');
      expect(file.existsSync(), isTrue,
          reason: 'share_utils.dart が存在しません');

      final content = file.readAsStringSync();
      // private (_appStoreUrl) ではなく public (appStoreUrl) であること
      final hasPublicConst = RegExp(
        r'static\s+const\s+appStoreUrl\s*=',
      ).hasMatch(content);

      expect(hasPublicConst, isTrue,
          reason: 'share_utils.dart に `static const appStoreUrl` が'
              '見つかりません。_appStoreUrl を public に変更してください。');
    });

    test('share_utils.dart に private な _appStoreUrl が残っていないとき', () {
      final file = File('lib/utils/share_utils.dart');
      final content = file.readAsStringSync();

      final hasPrivateConst = content.contains('_appStoreUrl');
      expect(hasPrivateConst, isFalse,
          reason: 'private な _appStoreUrl が残っています。'
              'appStoreUrl（public）に変更してください。');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [3] share_preview_screen.dart — URL直書きが存在しないこと
  // ══════════════════════════════════════════════════════════════

  group('share_preview_screen — URL一元管理', () {
    test('share_preview_screen.dart に App Store URL 直書きが残っていないとき', () {
      final file = File('lib/screens/share_preview_screen.dart');
      expect(file.existsSync(), isTrue,
          reason: 'share_preview_screen.dart が存在しません');

      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // import 文やコメントはスキップ
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

        // App Store URL のハードコードを検出
        if (line.contains('apps.apple.com/jp/app/aimachi')) {
          violations.add('  L${i + 1}: ${line.trim()}');
        }
      }

      expect(violations, isEmpty,
          reason: 'share_preview_screen.dart に App Store URL が直書きされています。'
              'ShareUtils.appStoreUrl を使用してください。\n\n'
              '違反箇所:\n${violations.join('\n')}');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [4] settings_screen.dart — URL直書きが存在しないこと（3箇所）
  // ══════════════════════════════════════════════════════════════

  group('settings_screen — URL一元管理', () {
    test('settings_screen.dart に App Store URL 直書きが残っていないとき', () {
      final file = File('lib/screens/settings_screen.dart');
      expect(file.existsSync(), isTrue,
          reason: 'settings_screen.dart が存在しません');

      final content = file.readAsStringSync();
      final lines = content.split('\n');
      final violations = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

        if (line.contains('apps.apple.com/jp/app/aimachi')) {
          violations.add('  L${i + 1}: ${line.trim()}');
        }
      }

      expect(violations, isEmpty,
          reason: 'settings_screen.dart に App Store URL が直書きされています。'
              'ShareUtils.appStoreUrl を使用してください。\n\n'
              '違反箇所（${violations.length}箇所）:\n${violations.join('\n')}');
    });

    test('settings_screen.dart の紹介・シェア・レビュー機能が ShareUtils.appStoreUrl を参照するとき', () {
      final file = File('lib/screens/settings_screen.dart');
      final content = file.readAsStringSync();

      // ShareUtils をインポートしていること
      expect(content, contains('share_utils'),
          reason: 'settings_screen.dart が share_utils.dart をインポートしていません。'
              'URL一元管理のために import を追加してください。');
    });
  });

  // ══════════════════════════════════════════════════════════════
  // [5] 全体チェック: lib/ 配下に App Store URL 直書きが share_utils.dart 以外にないこと
  // ══════════════════════════════════════════════════════════════

  group('App Store URL 一元管理 — lib/ 全体', () {
    test('share_utils.dart 以外のファイルに App Store URL 直書きが残っていないとき', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'lib/ ディレクトリが存在しません');

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('share_utils.dart'))
          .toList();

      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('import ')) continue;

          if (line.contains('apps.apple.com/jp/app/aimachi')) {
            violations.add('  ${file.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'share_utils.dart 以外に App Store URL の直書きが残っています。'
              'ShareUtils.appStoreUrl を使用してください。\n\n'
              '違反箇所（${violations.length}件）:\n${violations.join('\n')}');
    });
  });
}
