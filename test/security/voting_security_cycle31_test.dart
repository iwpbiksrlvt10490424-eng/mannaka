// TDD Red フェーズ
// Cycle 31: voting_security_cycle18_test.dart 内の APIキー実値除去
//
// スコープ:
//   [🔴 HIGH] voting_security_cycle18_test.dart — APIキー実値が10箇所残存
//             → cycle18テスト自体がキー漏洩の媒体になっている
//             → cycle18はcycle16の修正を検証するテストだが、
//               その検証ロジックに実キーを埋め込んでいるという矛盾
//
// 修正内容:
//   line 161: RegExp(r'実キー') → RegExp(r'[A-Z0-9]{40,}')
//   lines 152-157, 179, 183, 216: コメント・reason文字列内の実値を除去
//
// ※ このテスト自体はキー実値を含まない。
//    構造パターン RegExp(r'[A-Z0-9]{40,}') で検出する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: HIGH — voting_security_cycle18_test APIキー実値除去
  // ─────────────────────────────────────────────────────
  group('[HIGH] voting_security_cycle18_test — APIキー実値が含まれない', () {
    test(
      'voting_security_cycle18_test.dart に40文字以上の大文字英数字列がないとき '
      'テストファイル自体がAPIキーの漏洩媒体にならない',
      () {
        final file = File('test/security/voting_security_cycle18_test.dart');
        if (!file.existsSync()) {
          fail(
            'test/security/voting_security_cycle18_test.dart が存在しません。\n'
            'ファイルパスが正しいか確認してください。',
          );
        }
        final content = file.readAsStringSync();

        // Foursquare/Hotpepper APIキーは40文字以上の大文字英字・数字のみで構成される。
        // 実値を直接書かずに構造パターンで検出する。
        final apiKeyPattern = RegExp(r'[A-Z0-9]{40,}');
        final matches = apiKeyPattern.allMatches(content).toList();
        final occurrences = matches.length;

        expect(
          occurrences,
          0,
          reason:
              '`test/security/voting_security_cycle18_test.dart` に\n'
              'APIキー実値（40文字以上の大文字英数字列）が $occurrences 箇所残っています。\n'
              '\n'
              '問題: テストファイルが git にプッシュされると APIキーが公開されます。\n'
              '      セキュリティチェックのためにキーを書いても本末転倒です。\n'
              '      (cycle18はcycle16の修正を検証するテストですが、\n'
              '       検証ロジック自体に実キーが埋め込まれています)\n'
              '\n'
              '修正内容:\n'
              '  [line 161] 実値 RegExp → 構造パターン RegExp に置換:\n'
              "    修正後: final apiKeyPattern = RegExp(r'[A-Z0-9]{40,}');\n"
              '\n'
              '  [lines 152-157] コメント内の実値をプレースホルダーに置換:\n'
              "    修正後: //   Line 208: //     'RB4P...',\n"
              '\n'
              '  [lines 179, 183, 216] reason文字列内の実値をプレースホルダーに置換:\n'
              "    修正後: \"  // 修正前: content.contains('RB4P...')\"\n",
        );
      },
    );

    test(
      'voting_security_cycle18_test.dart のAPIキー検出ロジックが構造パターン RegExp のとき '
      'キー実値を持たずにキー形式を検出できる',
      () {
        final file = File('test/security/voting_security_cycle18_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle18_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // line 161 が構造パターン RegExp に置換されていることを確認
        // 変数宣言パターンで確認（reason文字列内の例示とは区別）
        final hasRegExpPattern = content.contains(
          "final apiKeyPattern = RegExp(r'[A-Z0-9]{40,}')",
        );

        expect(
          hasRegExpPattern,
          isTrue,
          reason:
              '`voting_security_cycle18_test.dart` のAPIキー検出ロジック (line 161) が\n'
              '構造パターン RegExp に置換されていません。\n'
              '\n'
              '修正例:\n'
              '  // 修正前:\n'
              "  final apiKeyPattern = RegExp(r'[実際の40文字以上のキー実値]');\n"
              '\n'
              '  // 修正後:\n'
              "  final apiKeyPattern = RegExp(r'[A-Z0-9]{40,}');\n",
        );
      },
    );
  });
}
