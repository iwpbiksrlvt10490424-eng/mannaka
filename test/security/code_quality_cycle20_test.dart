// TDD Red フェーズ
// Cycle 20: flutter test 全パス回復 & 残存セキュリティ修正
//
// スコープ:
//   [🔴 HIGH]    restaurant_cache_service.dart — debugPrint に $e が2箇所
//                → スタックトレースがデバイスログに残存
//   [🔴 HIGH]    search_provider.dart — debugPrint に $e が1箇所
//                → 同上
//   [🟡 MEDIUM]  share_preview_screen.dart — App Store URL '/app/mannaka'
//                → 無効なURLがシェアテキストに含まれてユーザーに届く
//   [🟡 LOW]     settings_screen.dart — LINE フォールバックの Share.share() に
//                sharePositionOrigin がない → iOS クラッシュリスク（CLAUDE.md 違反）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// debugPrint に生例外 $e が含まれる行を返す。
/// ファイル非存在は fail() で偽グリーン防止。
List<String> _findRawExceptionLogs(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail(
      '$filePath が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  final lines = file.readAsLinesSync();
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // debugPrint / print を対象に $e 単体（${e.xxx} は安全なので除外）を検出
    if ((line.contains('debugPrint') || line.contains('print(')) &&
        RegExp(r'\$e[^{a-zA-Z_]').hasMatch(line)) {
      violations.add('行${i + 1}: ${line.trim()}');
    }
  }
  return violations;
}

/// Share.share( 呼び出しのうち sharePositionOrigin を持たないブロックを返す。
/// iOS では sharePositionOrigin 必須（CLAUDE.md）。
List<String> _findShareWithoutPositionOrigin(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail(
      '$filePath が存在しません。\n'
      'ファイルパスが正しいか確認してください。',
    );
  }
  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].contains('Share.share(')) continue;

    // 呼び出しブロックをカッコの深さで追跡して収集する（最大20行）
    final buffer = StringBuffer();
    var depth = 0;
    var started = false;

    for (var j = i; j < lines.length && j < i + 20; j++) {
      final ln = lines[j];
      buffer.write(ln);
      for (var k = 0; k < ln.length; k++) {
        if (ln[k] == '(') {
          depth++;
          started = true;
        } else if (ln[k] == ')' && started) {
          depth--;
        }
      }
      if (started && depth <= 0) break;
    }

    if (!buffer.toString().contains('sharePositionOrigin')) {
      violations.add('行${i + 1}: ${lines[i].trim()}');
    }
  }

  return violations;
}

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: HIGH — restaurant_cache_service.dart debugPrint 生例外ログ
  // ─────────────────────────────────────────────────────
  group(
      '[HIGH] restaurant_cache_service — debugPrint 生例外 \$e が含まれない', () {
    test(
      'restaurant_cache_service.dart の debugPrint に \$e がないとき '
      'キャッシュI/Oエラーのスタックトレースがデバイスログに漏洩しない',
      () {
        final violations = _findRawExceptionLogs(
            'lib/services/restaurant_cache_service.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/services/restaurant_cache_service.dart` の debugPrint に\n'
              '生例外 `\$e` が直接埋め込まれています。\n'
              '\n'
              '問題: `\$e` は Exception.toString() を展開するため、\n'
              '      スタックトレースや内部パスがデバイスログに出力されます。\n'
              '\n'
              '修正（全2箇所）:\n'
              '  // 修正前:\n'
              "  debugPrint('RestaurantCacheService.get: \$e');\n"
              "  debugPrint('RestaurantCacheService.set: \$e');\n"
              '  // 修正後:\n'
              "  debugPrint('RestaurantCacheService.get: \${e.runtimeType}');\n"
              "  debugPrint('RestaurantCacheService.set: \${e.runtimeType}');\n"
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: HIGH — search_provider.dart debugPrint 生例外ログ
  // ─────────────────────────────────────────────────────
  group('[HIGH] search_provider — debugPrint 生例外 \$e が含まれない', () {
    test(
      'search_provider.dart の debugPrint に \$e がないとき '
      'プリフェッチエラーのスタックトレースがデバイスログに漏洩しない',
      () {
        final violations =
            _findRawExceptionLogs('lib/providers/search_provider.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/providers/search_provider.dart` の debugPrint に\n'
              '生例外 `\$e` が直接埋め込まれています。\n'
              '\n'
              '問題: `\$e` は Exception.toString() を展開するため、\n'
              '      スタックトレースや内部パスがデバイスログに出力されます。\n'
              '\n'
              '修正（1箇所）:\n'
              '  // 修正前:\n'
              "  debugPrint('prefetch: \${point.stationName} failed - \$e');\n"
              '  // 修正後:\n'
              "  debugPrint('prefetch: \${point.stationName} failed - \${e.runtimeType}');\n"
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: MEDIUM — share_preview_screen.dart App Store URL プレースホルダー
  // ─────────────────────────────────────────────────────
  group(
      '[MEDIUM] share_preview_screen — App Store URL にプレースホルダーが含まれない',
      () {
    test(
      'share_preview_screen.dart のシェアテキスト内 App Store URL が '
      'プレースホルダーでないとき ユーザーに有効なリンクが届く',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // '/app/mannaka' のような数値IDなしのプレースホルダーURLを検出
        // 有効な App Store URL は id<数字> を含む形式が必要
        final hasPlaceholderUrl =
            content.contains('apps.apple.com/jp/app/mannaka') ||
            content.contains('apps.apple.com/app/mannaka');

        expect(
          hasPlaceholderUrl,
          isFalse,
          reason:
              '`lib/screens/share_preview_screen.dart` の App Store URL に\n'
              'プレースホルダー `/app/mannaka` が含まれています。\n'
              '\n'
              '問題: `/app/mannaka` は有効な App Store URL ではありません。\n'
              '      App Store URL は `/app/<app-name>/id<numeric_id>` の形式が必要です。\n'
              '\n'
              '修正方針: App Store 公開後に実際のApp IDに置き換えるため、\n'
              '  現時点では URL をコメントアウトして TODO を残してください。\n'
              '  例:\n'
              "  // TODO(release): App Store公開後に実際のApp IDに置き換える\n"
              "  // '▶ App Store: https://apps.apple.com/jp/app/aima/id<実際のID>'\n",
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: LOW — settings_screen.dart LINE フォールバック Share.share()
  //   に sharePositionOrigin が必須（CLAUDE.md: iOS クラッシュ防止）
  // ─────────────────────────────────────────────────────
  group(
      '[LOW] settings_screen — Share.share() に sharePositionOrigin が設定されている',
      () {
    test(
      'settings_screen.dart の Share.share() 呼び出し全てに sharePositionOrigin があるとき '
      'iOS で iPad/iPhone の iPad Split View クラッシュが発生しない',
      () {
        final violations =
            _findShareWithoutPositionOrigin('lib/screens/settings_screen.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/screens/settings_screen.dart` に\n'
              '`sharePositionOrigin` を持たない `Share.share()` 呼び出しがあります。\n'
              '\n'
              '問題: iOS（特に iPad）では sharePositionOrigin がないと\n'
              '      UIPopoverPresentationController の anchor が nil になりクラッシュします。\n'
              '      CLAUDE.md: `Share.share()` on iOS は `sharePositionOrigin` 必須\n'
              '\n'
              '修正（LINE フォールバック箇所 ～line 545）:\n'
              '  // 修正前:\n'
              '  await Share.share(text);\n'
              '  // 修正後:\n'
              '  await Share.share(\n'
              '    text,\n'
              '    sharePositionOrigin: Rect.fromCenter(\n'
              '      center: Offset(\n'
              '        MediaQuery.of(context).size.width / 2,\n'
              '        MediaQuery.of(context).size.height / 2,\n'
              '      ),\n'
              '      width: 100,\n'
              '      height: 100,\n'
              '    ),\n'
              '  );\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });
}
