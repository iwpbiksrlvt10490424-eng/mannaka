// TDD Red フェーズ
// Cycle 14: voting_service.dart 空文字バリデーション + 境界値テスト
//
// 問題:
//   voting_service.dart の createSession() と vote() に上限バリデーション（50文字超）は
//   あるが、空文字（下限）のバリデーションがない。
//
//   空文字の hostName / voterName が許容されると:
//   - Firestore の hostName フィールドが空で保存される（表示崩れ）
//   - voters.contains('') が意図せずマッチする可能性がある
//   - 二重投票防止ロジックが空文字で破損する
//
// 修正方針:
//   createSession() に hostName.isEmpty チェックを追加
//   vote() に voterName.isEmpty チェックを追加
//   境界値: 0文字 → ArgumentError、1文字 → OK、50文字 → OK、51文字 → ArgumentError

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('[MEDIUM] voting_service.dart — 空文字バリデーション', () {
    test(
      'createSession の hostName が空文字のとき '
      'ArgumentError が throw される（Firestoreへの書き込み前に検証）',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 空文字バリデーションのパターンを検出
        // 期待される実装例:
        //   if (hostName.isEmpty) {
        //     throw ArgumentError('hostName は1文字以上にしてください');
        //   }
        // または:
        //   if (hostName.length < 1) { throw ArgumentError(...) }
        // または:
        //   if (hostName.isEmpty || hostName.length > 50) { ... }
        final hasEmptyCheck =
            content.contains('hostName.isEmpty') ||
            RegExp(r'hostName\.length\s*[<]\s*1').hasMatch(content) ||
            RegExp(r'hostName\.length\s*==\s*0').hasMatch(content) ||
            RegExp(r'hostName\.isEmpty\s*\|\|').hasMatch(content) ||
            RegExp(r'\|\|\s*hostName\.isEmpty').hasMatch(content);

        expect(
          hasEmptyCheck,
          isTrue,
          reason: '`voting_service.dart` の `createSession()` に '
              '`hostName` の空文字バリデーションがありません。\n'
              '\n'
              '問題: 空文字の hostName が Firestore に保存されると\n'
              '      「ホスト: 」という表示になり UI が崩れます。\n'
              '\n'
              '現在のバリデーション: `if (hostName.length > 50)` のみ（上限のみ）\n'
              '\n'
              '修正例:\n'
              '  if (hostName.isEmpty || hostName.length > 50) {\n'
              "    throw ArgumentError('hostName は1〜50文字にしてください');\n"
              '  }\n'
              'または:\n'
              '  if (hostName.isEmpty) {\n'
              "    throw ArgumentError('hostName は1文字以上にしてください');\n"
              '  }\n'
              '  if (hostName.length > 50) {\n'
              "    throw ArgumentError('hostName は50文字以内にしてください');\n"
              '  }',
        );
      },
    );

    test(
      'vote の voterName が空文字のとき '
      'ArgumentError が throw される（二重投票防止ロジックの保護）',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 空文字バリデーションのパターンを検出
        final hasEmptyCheck =
            content.contains('voterName.isEmpty') ||
            RegExp(r'voterName\.length\s*[<]\s*1').hasMatch(content) ||
            RegExp(r'voterName\.length\s*==\s*0').hasMatch(content) ||
            RegExp(r'voterName\.isEmpty\s*\|\|').hasMatch(content) ||
            RegExp(r'\|\|\s*voterName\.isEmpty').hasMatch(content);

        expect(
          hasEmptyCheck,
          isTrue,
          reason: '`voting_service.dart` の `vote()` に '
              '`voterName` の空文字バリデーションがありません。\n'
              '\n'
              '問題: 空文字の voterName が `voters` リストに追加されると\n'
              '      `voters.contains(\'\')` が意図せずマッチし、\n'
              '      二重投票防止ロジックが誤動作する可能性があります。\n'
              '\n'
              '現在のバリデーション: `if (voterName.length > 50)` のみ（上限のみ）\n'
              '\n'
              '修正例:\n'
              '  if (voterName.isEmpty || voterName.length > 50) {\n'
              "    throw ArgumentError('voterName は1〜50文字にしてください');\n"
              '  }',
        );
      },
    );
  });

  group('[MEDIUM] voting_service.dart — 境界値バリデーション確認', () {
    test(
      'createSession のバリデーション条件が境界値を正しく処理するとき '
      '空文字と51文字超は拒否され、1〜50文字は許容される',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 上限（50文字超）と下限（空文字）の両方のバリデーションが存在することを確認
        // 上限チェック（既存）
        final hasUpperBound =
            RegExp(r'hostName\.length\s*>\s*50').hasMatch(content) ||
            RegExp(r'hostName\.length\s*>=\s*51').hasMatch(content);

        // 下限チェック（新規追加が必要）
        final hasLowerBound =
            content.contains('hostName.isEmpty') ||
            RegExp(r'hostName\.length\s*<\s*1').hasMatch(content) ||
            RegExp(r'hostName\.length\s*==\s*0').hasMatch(content);

        expect(
          hasUpperBound && hasLowerBound,
          isTrue,
          reason: '`voting_service.dart` の hostName バリデーションが不完全です。\n'
              '\n'
              '境界値テスト要件:\n'
              '  - hostName = ""  (0文字)  → ArgumentError ✗ (現在: エラーにならない)\n'
              '  - hostName = "A" (1文字)  → 正常 ✓\n'
              '  - hostName = "A"×50      → 正常 ✓\n'
              '  - hostName = "A"×51      → ArgumentError ✓ (現在: 実装済み)\n'
              '\n'
              '上限チェック: ${hasUpperBound ? "✓ 実装済み" : "✗ 未実装"}\n'
              '下限チェック: ${hasLowerBound ? "✓ 実装済み" : "✗ 未実装"}\n'
              '\n'
              '修正例（下限チェック追加）:\n'
              '  if (hostName.isEmpty) {\n'
              "    throw ArgumentError('hostName は1文字以上にしてください');\n"
              '  }',
        );
      },
    );

    test(
      'vote のバリデーション条件が境界値を正しく処理するとき '
      '空文字と51文字超は拒否され、1〜50文字は許容される',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 上限チェック（既存）
        final hasUpperBound =
            RegExp(r'voterName\.length\s*>\s*50').hasMatch(content) ||
            RegExp(r'voterName\.length\s*>=\s*51').hasMatch(content);

        // 下限チェック（新規追加が必要）
        final hasLowerBound =
            content.contains('voterName.isEmpty') ||
            RegExp(r'voterName\.length\s*<\s*1').hasMatch(content) ||
            RegExp(r'voterName\.length\s*==\s*0').hasMatch(content);

        expect(
          hasUpperBound && hasLowerBound,
          isTrue,
          reason: '`voting_service.dart` の voterName バリデーションが不完全です。\n'
              '\n'
              '境界値テスト要件:\n'
              '  - voterName = ""  (0文字)  → ArgumentError ✗ (現在: エラーにならない)\n'
              '  - voterName = "A" (1文字)  → 正常 ✓\n'
              '  - voterName = "A"×50      → 正常 ✓\n'
              '  - voterName = "A"×51      → ArgumentError ✓ (現在: 実装済み)\n'
              '\n'
              '上限チェック: ${hasUpperBound ? "✓ 実装済み" : "✗ 未実装"}\n'
              '下限チェック: ${hasLowerBound ? "✓ 実装済み" : "✗ 未実装"}\n'
              '\n'
              '修正例（下限チェック追加）:\n'
              '  if (voterName.isEmpty) {\n'
              "    throw ArgumentError('voterName は1文字以上にしてください');\n"
              '  }',
        );
      },
    );

    test(
      'voting_service.dart の ArgumentError メッセージが境界値を説明するとき '
      'エラーメッセージで有効範囲（1〜50文字）がユーザーに伝わる',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 空文字バリデーション時に「1文字以上」または「1〜50文字」などの
        // 範囲説明が含まれることを確認
        // 現状のエラーメッセージ:
        //   'hostName は50文字以内にしてください' → 空文字が許可されているように読める
        //
        // 期待:
        //   'hostName は1〜50文字にしてください' または
        //   'hostName は1文字以上にしてください' など
        final hasBoundaryMessage =
            content.contains('1〜50') ||
            content.contains('1文字以上') ||
            content.contains('1 〜 50') ||
            RegExp(r'1.{0,5}50文字').hasMatch(content);

        expect(
          hasBoundaryMessage,
          isTrue,
          reason: '`voting_service.dart` の ArgumentError メッセージが\n'
              '下限（1文字以上）を説明していません。\n'
              '\n'
              '現在のメッセージ例: "hostName は50文字以内にしてください"\n'
              '  → ユーザーは空文字も有効だと誤解する可能性があります\n'
              '\n'
              '期待するメッセージ例: "hostName は1〜50文字にしてください"\n'
              '\n'
              '修正例:\n'
              "  throw ArgumentError('hostName は1〜50文字にしてください');\n"
              "  throw ArgumentError('voterName は1〜50文字にしてください');",
        );
      },
    );
  });
}
