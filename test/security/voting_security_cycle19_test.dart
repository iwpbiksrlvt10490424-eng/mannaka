// TDD Red フェーズ
// Cycle 19: 残存 debugPrint 生例外ログ + App Store URL プレースホルダー
//
// スコープ:
//   [🔴 HIGH]    visited_restaurants_provider.dart — debugPrint('...: $e') 3箇所
//                → スタックトレースがデバイスログに残存
//   [🔴 HIGH]    reserved_restaurants_provider.dart — debugPrint('...: $e') 3箇所
//                → 同上
//   [🟡 MEDIUM]  main.dart — debugPrint('Firebase初期化エラー: $e')
//                → Firebase の認証エラー詳細がログ漏洩
//   [🟡 MEDIUM]  share_utils.dart — App Store URL '/app/mannaka' (プレースホルダー)
//                → 無効なURLがシェアテキストに含まれてユーザーに届く
//   [🟡 MEDIUM]  settings_screen.dart — App Store URL 'id0000000000' (プレースホルダー)
//                → シェアテキストの App Store リンクが無効

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
    if (line.contains('debugPrint') &&
        RegExp(r'\$e[^{a-zA-Z_]').hasMatch(line)) {
      violations.add('行${i + 1}: ${line.trim()}');
    }
  }
  return violations;
}

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: HIGH — visited_restaurants_provider debugPrint 生例外ログ
  // ─────────────────────────────────────────────────────
  group(
      '[HIGH] visited_restaurants_provider — debugPrint 生例外 \$e が含まれない',
      () {
    test(
      'visited_restaurants_provider.dart の debugPrint に \$e がないとき '
      'SharedPreferences エラーのスタックトレースがデバイスログに漏洩しない',
      () {
        final violations = _findRawExceptionLogs(
            'lib/providers/visited_restaurants_provider.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/providers/visited_restaurants_provider.dart` の debugPrint に\n'
              '生例外 `\$e` が直接埋め込まれています。\n'
              '\n'
              '問題: `\$e` は Exception.toString() を展開するため、\n'
              '      スタックトレースや内部パスがデバイスログに出力されます。\n'
              '\n'
              '修正（全3箇所）:\n'
              '  // 修正前:\n'
              "  debugPrint('VisitedRestaurantsNotifier: _load failed - \$e');\n"
              '  // 修正後:\n'
              "  debugPrint('VisitedRestaurantsNotifier: _load failed - \${e.runtimeType}');\n"
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: HIGH — reserved_restaurants_provider debugPrint 生例外ログ
  // ─────────────────────────────────────────────────────
  group(
      '[HIGH] reserved_restaurants_provider — debugPrint 生例外 \$e が含まれない',
      () {
    test(
      'reserved_restaurants_provider.dart の debugPrint に \$e がないとき '
      'SharedPreferences エラーのスタックトレースがデバイスログに漏洩しない',
      () {
        final violations = _findRawExceptionLogs(
            'lib/providers/reserved_restaurants_provider.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/providers/reserved_restaurants_provider.dart` の debugPrint に\n'
              '生例外 `\$e` が直接埋め込まれています。\n'
              '\n'
              '修正（全3箇所）:\n'
              '  // 修正前:\n'
              "  debugPrint('ReservedRestaurantsNotifier: _load failed - \$e');\n"
              '  // 修正後:\n'
              "  debugPrint('ReservedRestaurantsNotifier: _load failed - \${e.runtimeType}');\n"
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: MEDIUM — main.dart Firebase エラーログ
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] main.dart — Firebase 初期化エラーログに生例外が含まれない', () {
    test(
      'main.dart の debugPrint に \$e がないとき '
      'Firebase の認証エラー詳細（APIキーや設定情報）がログに漏洩しない',
      () {
        final violations = _findRawExceptionLogs('lib/main.dart');

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/main.dart` の debugPrint に\n'
              '生例外 `\$e` が直接埋め込まれています。\n'
              '\n'
              '問題: Firebase の初期化エラーには APIキーや設定情報が含まれる場合があります。\n'
              '      `\$e` をログに出力するとこれらの情報が漏洩します。\n'
              '\n'
              '修正（main.dart:31 付近）:\n'
              '  // 修正前:\n'
              "  debugPrint('Firebase初期化エラー: \$e');\n"
              '  // 修正後:\n'
              "  debugPrint('Firebase初期化エラー: \${e.runtimeType}');\n"
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: MEDIUM — share_utils.dart App Store URL プレースホルダー
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] share_utils — App Store URL にプレースホルダーが含まれない', () {
    test(
      'share_utils.dart の App Store URL が有効な形式のとき '
      'シェアテキストに届いたユーザーが App Store に遷移できる',
      () {
        final file = File('lib/utils/share_utils.dart');
        if (!file.existsSync()) {
          fail('lib/utils/share_utils.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // '/app/mannaka' のような数値IDなしのプレースホルダーURLを検出
        // 有効なApp Store URLは id<数字> を含む形式が必要
        final hasPlaceholderMannakaUrl =
            content.contains('apps.apple.com/jp/app/mannaka') ||
            content.contains('apps.apple.com/app/mannaka');

        expect(
          hasPlaceholderMannakaUrl,
          isFalse,
          reason:
              '`lib/utils/share_utils.dart` の App Store URL に\n'
              'プレースホルダー `/app/mannaka` が含まれています。\n'
              '\n'
              '問題: `/app/mannaka` は有効な App Store URL ではありません。\n'
              '      App Store URL は `/app/<app-name>/id<numeric_id>` の形式が必要です。\n'
              '\n'
              '違反箇所（2箇所）:\n'
              '  行49:  sb.writeln(\'▶ App Store: https://apps.apple.com/jp/app/mannaka\');\n'
              '  行122: https://apps.apple.com/jp/app/mannaka\n'
              '\n'
              '修正: App Store に公開後、実際のApp IDに置き換えてください。\n'
              '  例: https://apps.apple.com/jp/app/aima/id1234567890',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ5: MEDIUM — settings_screen.dart App Store URL プレースホルダー
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] settings_screen — App Store URL にプレースホルダーが含まれない', () {
    test(
      'settings_screen.dart のシェアテキスト内 App Store URL が有効なとき '
      'アプリシェア機能でユーザーに正しいリンクが届く',
      () {
        final file = File('lib/screens/settings_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/settings_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 'id0000000000' のようなゼロ埋めプレースホルダーIDを検出
        final hasPlaceholderId = RegExp(r'id0{6,}').hasMatch(content);

        expect(
          hasPlaceholderId,
          isFalse,
          reason:
              '`lib/screens/settings_screen.dart` のシェアテキストに\n'
              'ゼロ埋めプレースホルダー `id0000000000` が含まれています。\n'
              '\n'
              '問題: このURLはApp Storeに存在せず、シェアされたユーザーが\n'
              '      App Storeに遷移できません。リリース前に修正が必要です。\n'
              '\n'
              '違反箇所（約 line 535）:\n'
              "  'Aima — ...\\nhttps://apps.apple.com/app/id0000000000'\n"
              '\n'
              '修正: App Store に公開後、実際のApp IDに置き換えてください。\n'
              '  例: https://apps.apple.com/jp/app/aima/id1234567890',
        );
      },
    );
  });
}
