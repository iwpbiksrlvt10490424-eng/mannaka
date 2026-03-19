// TDD Red フェーズ
// Cycle 16: Cycle15 残件修正テスト
//
// スコープ:
//   [🔴 HIGH] voting_security_cycle13_test.dart — Group1 Test1: allow delete ブロックに絞った hostUid 検証 + 説明文修正
//   [🔴 HIGH] voting_security_cycle13_test.dart — Group1 Test2: allow update / allow delete が別行で存在することを行単位で確認
//   [🔴 HIGH] voting_security_cycle15_test.dart — Line 359: RB4P... 実値 → RegExp(r'[A-Z0-9]{40,}') に置換 + 自己検証テスト追加

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: cycle13_test Group1 Test1 — allow delete 特化検証
  // ─────────────────────────────────────────────────────
  group('[HIGH] cycle13_test Group1 Test1 — allow delete ブロックに絞った hostUid 検証', () {
    test(
      'cycle13_test の Group1 Test1 説明文が allow delete ブロックに言及するとき '
      'テスト意図と実装が一致する（write ルール全体の検証ではない）',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状: Group1 Test1 の説明文が "write ルールに" と書かれており、
        //       allow update / allow delete を区別せず write 全体を確認する意図に見える。
        //
        // 問題: firestore.rules が allow update（無制限）と allow delete（hostUid制限）に
        //       分離された後も "write ルールに" の説明のままでは、
        //       テストの意図（削除のみホスト限定）と実際の検証対象がズレている。
        //
        // 修正後: 説明文に "allow delete" または "削除" への言及が含まれていること
        //
        // 現在の説明: "voting_sessions の write ルールに request.auth.uid == ... が含まれるとき"
        // 期待する説明例: "voting_sessions の allow delete ブロックに hostUid チェックがあるとき"
        final hasOutdatedWriteRuleDescription =
            content.contains("voting_sessions の write ルールに request.auth.uid");

        expect(
          hasOutdatedWriteRuleDescription,
          isFalse,
          reason: '`cycle13_test.dart` Group1 Test1 の説明文に '
              '"write ルールに request.auth.uid" が残っています。\n'
              '\n'
              '問題: Cycle15 で firestore.rules を allow update（無制限）と\n'
              '      allow delete（hostUid制限）に分離した後、\n'
              '      テスト説明は "allow delete ブロックに hostUid チェックがある" に\n'
              '      対応するよう更新が必要です。\n'
              '\n'
              '現在の説明（修正前）:\n'
              '  "voting_sessions の write ルールに request.auth.uid == resource.data.hostUid が含まれるとき\n'
              '   ホスト以外のユーザーがセッションを改ざんできない"\n'
              '\n'
              '修正後の説明例:\n'
              '  "voting_sessions の allow delete ブロックに hostUid チェックがあるとき\n'
              '   セッション削除はホストのみに制限される"\n',
        );
      },
    );

    test(
      'cycle13_test の Group1 Test1 が allow delete 行を特定して hostUid を検証するとき '
      'allow update の無制限書き込みを allow delete の制限と混同しない',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状の問題（偽グリーン）:
        //   `content.contains('request.auth.uid == resource.data.hostUid')` の
        //   全文検索を使っているため、allow delete 行にある hostUid チェックで
        //   テストが通ってしまう。
        //   → allow update に hostUid チェックがないことは検証されていない。
        //
        // 期待: Group1 Test1 の検証ロジックが allow delete の行/ブロックに絞られていること。
        //       例:
        //         final lines = content.split('\n');
        //         final deleteIdx = lines.indexWhere((l) => l.contains('allow delete'));
        //         final deleteBlock = lines.skip(deleteIdx).take(3).join('\n');
        //         final hasHostUid = deleteBlock.contains('resource.data.hostUid');
        //
        // 検出方法: Group1 Test1 の検証ロジック部分（hasHostUidCheck の定義付近）に
        //           行単位の抽出や allow delete ブロックの特定がある
        //
        // 現状: Group1 Test1 の hasHostUidCheck は全文 contains のみ → 行単位チェックなし
        // 注: Group1 Test2 の _extractBlock ヘルパー使用は別カウント
        final test1Block = _extractTest1Block(content);

        final hasLineSpecificCheck =
            test1Block.contains("split('\\n')") ||
            test1Block.contains('split("\n")') ||
            test1Block.contains(".split('\n')") ||
            test1Block.contains('.split("\n")') ||
            test1Block.contains('indexWhere') ||
            test1Block.contains('deleteIdx') ||
            test1Block.contains('deleteBlock') ||
            test1Block.contains('deleteRule') ||
            (test1Block.contains("'allow delete'") &&
                test1Block.contains('hostUid'));

        expect(
          hasLineSpecificCheck,
          isTrue,
          reason: '`cycle13_test.dart` Group1 Test1 の検証ロジックが\n'
              '`allow delete` の行/ブロックに絞った確認をしていません。\n'
              '\n'
              '問題: `content.contains(\'request.auth.uid == resource.data.hostUid\')` の\n'
              '      全文検索では、allow delete / allow update / allow write の\n'
              '      どのルールに hostUid チェックがあるかを区別できません。\n'
              '\n'
              '修正例（行単位で allow delete ブロックを特定）:\n'
              "  final lines = content.split('\\n');\n"
              "  final deleteIdx = lines.indexWhere((l) => l.contains('allow delete'));\n"
              '  expect(deleteIdx, isNot(-1), reason: \'allow delete 行が見つかりません\');\n'
              "  final deleteBlock = lines.skip(deleteIdx).take(3).join('\\n');\n"
              "  final hasHostUid = deleteBlock.contains('resource.data.hostUid');\n"
              '  expect(hasHostUid, isTrue, reason: ...);\n',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: cycle13_test Group1 Test2 — 行単位確認
  // ─────────────────────────────────────────────────────
  group('[HIGH] cycle13_test Group1 Test2 — allow update / allow delete 行単位確認', () {
    test(
      'cycle13_test の Group1 Test2 が allow update と allow delete を行単位で検証するとき '
      'allow update, delete: の一括指定を正しく検出できる',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状の問題:
        //   `content.contains('allow update') || content.contains('allow delete')` では
        //   `allow update, delete:` の一括指定（コンマつき）でも通過してしまう。
        //   → "別行で存在する" という条件を検証できていない。
        //
        // 期待: Group1 Test2 が行を分割して allow update と allow delete が
        //       それぞれ独立した行として存在することを確認している
        //       例:
        //         final lines = content.split('\n');
        //         final hasUpdateLine = lines.any((l) => RegExp(r'allow\s+update\s*:').hasMatch(l));
        //         final hasDeleteLine = lines.any((l) => RegExp(r'allow\s+delete\s*:').hasMatch(l));
        //
        // 検出方法: Group1 Test2 のブロック内に行単位チェックのパターンがある
        final test2Block = _extractTest2Block(content);

        final hasLineByLineCheck =
            test2Block.contains("split('\\n')") ||
            test2Block.contains('split("\n")') ||
            test2Block.contains(".split('\n')") ||
            test2Block.contains('.split("\n")') ||
            test2Block.contains('.any(') ||
            test2Block.contains('RegExp(r\'allow update') ||
            test2Block.contains('RegExp(r"allow update') ||
            test2Block.contains('RegExp(r\'allow delete') ||
            test2Block.contains('RegExp(r"allow delete') ||
            test2Block.contains('trimLeft') ||
            test2Block.contains('startsWith(\'allow update\')') ||
            test2Block.contains('startsWith(\'allow delete\')');

        expect(
          hasLineByLineCheck,
          isTrue,
          reason: '`cycle13_test.dart` Group1 Test2 が行単位での\n'
              '`allow update` / `allow delete` の分離を確認していません。\n'
              '\n'
              '問題: `content.contains(\'allow update\') || content.contains(\'allow delete\')`\n'
              '      の単純 OR チェックでは、`allow update, delete:` の一括指定でも\n'
              '      `allow update` の部分文字列がマッチしてテストが通過します。\n'
              '\n'
              '修正例（行単位チェック）:\n'
              "  final lines = content.split('\\n');\n"
              "  final hasUpdateLine = lines.any((l) => RegExp(r'allow\\s+update\\s*:').hasMatch(l));\n"
              "  final hasDeleteLine = lines.any((l) => RegExp(r'allow\\s+delete\\s*:').hasMatch(l));\n"
              "  final hasComboLine = lines.any((l) => RegExp(r'allow\\s+update\\s*,\\s*delete').hasMatch(l));\n"
              '  expect(hasUpdateLine && hasDeleteLine && !hasComboLine, isTrue);\n',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: cycle15_test — APIキー実値除去 + 自己検証テスト
  // ─────────────────────────────────────────────────────
  group('[HIGH] cycle15_test — APIキー実値除去と RegExp 置換', () {
    test(
      'cycle15_test に Foursquare APIキーの実値が含まれないとき '
      'テストファイル自体がキー漏洩の媒体にならない',
      () {
        final file = File('test/security/voting_security_cycle15_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle15_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状（Line 359）:
        //   final hasHardcodedFoursquareKey = content.contains(
        //     'RB4P...',
        //   );
        //
        // 問題: cycle15_test.dart 自体に実APIキーが文字列定数として埋め込まれている。
        //       このファイルが git にコミットされるとキーが公開される。
        //
        // 修正: 実値を削除し RegExp(r'[A-Z0-9]{40,}') などのパターンに置換する。
        final hasHardcodedKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);

        expect(
          hasHardcodedKey,
          isFalse,
          reason: '`voting_security_cycle15_test.dart` に\n'
              'Foursquare APIキーの実値 `RB4P...`\n'
              'が文字列定数として埋め込まれています（Line 359付近）。\n'
              '\n'
              '問題: セキュリティチェックのためにキーをテストコードに書いても\n'
              '      テストファイルが git にプッシュされるとキーが公開されます。\n'
              '\n'
              '修正（Line 358-360 付近を書き換え）:\n'
              '  // 修正前:\n'
              "  final hasHardcodedFoursquareKey = content.contains(\n"
              "    'RB4P...',\n"
              '  );\n'
              '\n'
              '  // 修正後（APIキーの形式パターンで検出）:\n'
              "  final hasHardcodedFoursquareKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);\n",
        );
      },
    );

    test(
      'cycle15_test の hasHardcodedFoursquareKey 変数が RegExp で初期化されているとき '
      '実値ではなくパターンマッチでキー形式を検出する',
      () {
        final file = File('test/security/voting_security_cycle15_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle15_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状（Line 358-360）:
        //   final hasHardcodedFoursquareKey = content.contains(
        //     'RB4P...',
        //   );
        //
        // 期待:
        //   final hasHardcodedFoursquareKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);
        //
        // 検出方法: 変数代入行が `RegExp` で始まる（実値 `.contains(` ではない）
        //           `final hasHardcodedFoursquareKey = RegExp` のパターンで確認
        final hasRegExpAssignment =
            content.contains('final hasHardcodedFoursquareKey = RegExp');

        expect(
          hasRegExpAssignment,
          isTrue,
          reason: '`voting_security_cycle15_test.dart` の\n'
              '`hasHardcodedFoursquareKey` 変数が `content.contains(...)` の\n'
              '実値チェックのままです（RegExp に置換されていません）。\n'
              '\n'
              '問題: `.contains(\'RB4P...\')` の実値チェックを削除した後、\n'
              '      「APIキーの形式をした文字列（40文字以上の英大文字・数字列）」\n'
              '      で検出できるよう RegExp に置換する必要があります。\n'
              '\n'
              '修正（Line 358 付近）:\n'
              '  // 修正前:\n'
              "  final hasHardcodedFoursquareKey = content.contains(\n"
              "    'RB4P...',\n"
              '  );\n'
              '\n'
              '  // 修正後:\n'
              "  final hasHardcodedFoursquareKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);\n",
        );
      },
    );

    test(
      'cycle15_test に RegExp パターンの自己検証テストが追加されているとき '
      'パターンが実際のAPIキー形式を正しく検出できることを保証する',
      () {
        final file = File('test/security/voting_security_cycle15_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle15_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 期待: RegExp パターンの自己検証テストが追加されていること。
        //       自己検証テストは「40文字以上の文字列が検出される」かつ
        //       「短い文字列が検出されない」という両ケースを確認する。
        //       → `'A' * 40` のような programmatic な40文字列を使うのが典型パターン。
        //
        // 現状: 自己検証テストが存在しない（'A' * 40 のような構造がない）
        final hasSelfValidationTest =
            content.contains('List.filled(40') ||
            content.contains('String.fromCharCodes') ||
            content.contains("* 40") && content.contains("RegExp(r'[A-Z0-9]{40") ||
            content.contains('40文字以上') && content.contains("RegExp(r'[A-Z0-9]{40");

        expect(
          hasSelfValidationTest,
          isTrue,
          reason: '`voting_security_cycle15_test.dart` に RegExp パターンの\n'
              '自己検証テストが追加されていません。\n'
              '\n'
              '問題: `RegExp(r\'[A-Z0-9]{40,}\')` パターンが実際に正しく動作するか\n'
              '      保証する方法がありません。\n'
              '      （例: 39文字では検出しない・40文字で検出する両ケース）\n'
              '\n'
              '追加するテスト例:\n'
              '  test(\n'
              "    'RegExp(r\"[A-Z0-9]{40,}\") が 40文字以上の英大文字列を検出するとき '\n"
              "    '39文字以下は検出せず40文字以上は検出する',\n"
              '    () {\n'
              "      expect(RegExp(r'[A-Z0-9]{40,}').hasMatch('SHORTKEY123'), isFalse);\n"
              "      expect(RegExp(r'[A-Z0-9]{40,}').hasMatch('A' * 40), isTrue);\n"
              '    },\n'
              '  );\n',
        );
      },
    );
  });
}

// ─────────────────────────────────────────────────────
// ヘルパー
// ─────────────────────────────────────────────────────

/// cycle13_test.dart から Group1 Test1 の本体ブロックを抽出する
String _extractTest1Block(String content) {
  // Group1 の最初の test( から次の test( までを抽出
  final groupStart = content.indexOf(
    "group('[HIGH] firestore.rules — voting_sessions write の hostUid 制約'",
  );
  if (groupStart < 0) return '';
  final firstTestStart = content.indexOf('test(', groupStart);
  if (firstTestStart < 0) return '';
  final secondTestStart = content.indexOf('test(', firstTestStart + 5);
  if (secondTestStart < 0) {
    return content.substring(firstTestStart);
  }
  return content.substring(firstTestStart, secondTestStart);
}

/// cycle13_test.dart から Group1 Test2 の本体ブロックを抽出する
String _extractTest2Block(String content) {
  // Group1 の2番目の test( から次の group( または 3番目の test( までを抽出
  final groupStart = content.indexOf(
    "group('[HIGH] firestore.rules — voting_sessions write の hostUid 制約'",
  );
  if (groupStart < 0) return '';
  final firstTestStart = content.indexOf('test(', groupStart);
  if (firstTestStart < 0) return '';
  final secondTestStart = content.indexOf('test(', firstTestStart + 5);
  if (secondTestStart < 0) return '';
  // Group1 の終わり（次の group まで）
  final groupEnd = content.indexOf('\n  group(', secondTestStart);
  if (groupEnd < 0) return content.substring(secondTestStart);
  return content.substring(secondTestStart, groupEnd);
}
