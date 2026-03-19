// TDD Red フェーズ
// Cycle 17: Cycle16 残件修正テスト
//
// スコープ:
//   [🔴 CRITICAL] location_session_service.dart — createSession() に ownerUid が含まれない
//                 → Firestore の allow create ルールが PERMISSION_DENIED になる
//   [🔴 HIGH]    voting_security_cycle16_test.dart — 'A' * 40 は Dart で無効な構文
//                 → 自己検証テストが実装不可能になっている
//   [🟡 MEDIUM]  voting_security_cycle13_test.dart:70-72 — allow write フォールバックが
//                 リグレッションを隠蔽する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: CRITICAL — LocationSessionService.createSession() ownerUid 欠落
  // ─────────────────────────────────────────────────────
  group('[CRITICAL] location_session_service — createSession() に ownerUid が含まれる', () {
    test(
      'createSession() が ownerUid フィールドを Firestore に書くとき '
      'firestore.rules の allow create 条件を満たしアクセスが許可される',
      () {
        final file = File('lib/services/location_session_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/location_session_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 問題:
        //   firestore.rules の location_sessions に
        //     allow create: if request.auth != null
        //         && request.auth.uid == request.resource.data.ownerUid;
        //   というルールがあるが、createSession() は ownerUid を書き込んでいない。
        //   → 本番で PERMISSION_DENIED が発生し、位置情報シェア機能が完全に動作しない。
        //
        // 修正:
        //   createSession() の引数に ownerUid を追加し、
        //   set() するデータマップに 'ownerUid': ownerUid を含める。

        // createSession の set() 呼び出し内に 'ownerUid' キーが存在することを確認
        final hasOwnerUidField = content.contains("'ownerUid'") ||
            content.contains('"ownerUid"');

        expect(
          hasOwnerUidField,
          isTrue,
          reason: '`lib/services/location_session_service.dart` の '
              '`createSession()` が Firestore に `ownerUid` を書き込んでいません。\n'
              '\n'
              '問題: `firestore.rules` の `location_sessions` コレクションには\n'
              '  allow create: if request.auth != null\n'
              '      && request.auth.uid == request.resource.data.ownerUid;\n'
              'というルールがあります。`ownerUid` フィールドが書き込まれないと\n'
              '`PERMISSION_DENIED` になり位置情報シェア機能が動作しません。\n'
              '\n'
              '修正例:\n'
              '  static Future<String> createSession({\n'
              '    required String hostName,\n'
              '    required int slotIndex,\n'
              '    required String participantName,\n'
              '    required String ownerUid,   // ← 追加\n'
              '  }) async {\n'
              '    await _db.collection(_collection).doc(sessionId).set({\n'
              "      'ownerUid': ownerUid,     // ← 追加\n"
              "      'hostName': hostName,\n"
              '      ...\n'
              '    });\n'
              '  }\n',
        );
      },
    );

    test(
      'createSession() の引数に ownerUid が required パラメータとして存在するとき '
      '呼び出し側が UID を渡し忘れるコンパイルエラーで防止できる',
      () {
        final file = File('lib/services/location_session_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/location_session_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // createSession の引数リストに required String ownerUid があることを確認
        final hasOwnerUidParam =
            content.contains('required String ownerUid') ||
            content.contains('required final String ownerUid');

        expect(
          hasOwnerUidParam,
          isTrue,
          reason: '`createSession()` のシグネチャに `required String ownerUid` が\n'
              'ありません。ownerUid は呼び出し側から渡す必要があります。\n'
              '\n'
              '修正例:\n'
              '  static Future<String> createSession({\n'
              '    required String hostName,\n'
              '    required int slotIndex,\n'
              '    required String participantName,\n'
              '    required String ownerUid,   // ← 追加\n'
              '  }) async {\n',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: HIGH — cycle16_test の 'A' * 40 は Dart で無効な構文
  // ─────────────────────────────────────────────────────
  group("[HIGH] cycle16_test — 'A' * 40 は無効な Dart 構文のため自己検証テストが実装不能", () {
    test(
      "cycle16_test の hasSelfValidationTest が 'A' * 40 を要求しないとき "
      '有効な Dart 構文で自己検証テストが実装できる',
      () {
        final file = File('test/security/voting_security_cycle16_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle16_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 問題:
        //   cycle16_test.dart の Group3 Test3 (hasSelfValidationTest) に
        //     content.contains("'A' * 40")
        //   が含まれている。
        //
        //   しかし Dart は文字列の * 演算子をサポートしていない。
        //   → cycle15_test.dart に `'A' * 40` を書こうとするとコンパイルエラーになる。
        //   → cycle16_test が Green になる実装が存在しない（永久に Red）。
        //
        // 修正:
        //   cycle16_test.dart の hasSelfValidationTest 変数内の
        //   `"'A' * 40"` / `'"A" * 40'` を、有効な Dart の代替表現に変更する。
        //   例:
        //     content.contains('List.filled(40')   // List.filled(40, 'A').join()
        //     content.contains('String.fromCharCodes')
        //     content.contains("'A' * 40")         // ← これを削除
        //
        // 現状: `"'A' * 40"` という文字列が含まれている → テストは Red のまま
        final hasInvalidSyntaxCheck =
            content.contains("content.contains(\"'A' * 40\")") ||
            content.contains("content.contains('\"A\" * 40')");

        expect(
          hasInvalidSyntaxCheck,
          isFalse,
          reason: '`voting_security_cycle16_test.dart` の `hasSelfValidationTest` に\n'
              "`content.contains(\"'A' * 40\")` が含まれています。\n"
              '\n'
              "問題: Dart は文字列の `*` 演算子をサポートしていません。\n"
              "      `'A' * 40` を cycle15_test.dart に追加しようとすると\n"
              '      コンパイルエラーになり、cycle16_test が永久に Green になれません。\n'
              '\n'
              '修正（cycle16_test.dart の hasSelfValidationTest を変更）:\n'
              '  // 修正前:\n'
              "  content.contains(\"'A' * 40\") ||\n"
              "  content.contains('\"A\" * 40') ||\n"
              '\n'
              '  // 修正後（有効な Dart の代替）:\n'
              "  content.contains('List.filled(40') ||\n"
              "  content.contains('String.fromCharCodes') ||\n",
        );
      },
    );

    test(
      "cycle16_test の hasSelfValidationTest が有効な Dart の 40 文字生成パターンを要求するとき "
      'cycle15_test に実装可能な自己検証テストが書ける',
      () {
        final file = File('test/security/voting_security_cycle16_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle16_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 期待: hasSelfValidationTest が有効な Dart の代替表現を含む
        //   例1: `List.filled(40, 'A').join()` でランダム長文字列を生成
        //   例2: `String.fromCharCodes(List.filled(40, 65))` でASCIIから生成
        //   例3: `'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'` (40文字のリテラル)
        //   例4: `hasMatch('AAAA` など実際のパターン検証
        //
        // 現状: 有効な代替表現が含まれていない → Red
        final hasValidDartPattern =
            content.contains("'List.filled(40'") ||
            content.contains("List.filled(40,") ||
            content.contains("'String.fromCharCodes'") ||
            content.contains("String.fromCharCodes") &&
                content.contains("hasSelfValidationTest");

        expect(
          hasValidDartPattern,
          isTrue,
          reason: '`voting_security_cycle16_test.dart` の `hasSelfValidationTest` に\n'
              '有効な Dart の 40 文字生成パターンチェックが含まれていません。\n'
              '\n'
              '修正例（cycle16_test の hasSelfValidationTest を更新）:\n'
              '  final hasSelfValidationTest =\n'
              "      content.contains('List.filled(40') ||\n"
              "      content.contains('String.fromCharCodes') ||\n"
              "      content.contains(\"RegExp(r'[A-Z0-9]{40\") &&\n"
              "          content.contains('hasMatch');\n"
              '\n'
              'また cycle15_test.dart の自己検証テスト例:\n'
              '  test(\n'
              "    'RegExp が 40 文字以上の大文字英数字を検出するとき 39 文字以下は検出しない',\n"
              '    () {\n'
              "      final pattern = RegExp(r'[A-Z0-9]{40,}');\n"
              "      expect(pattern.hasMatch('SHORTKEY'), isFalse);\n"
              "      expect(pattern.hasMatch(List.filled(40, 'A').join()), isTrue);\n"
              '    },\n'
              '  );\n',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: MEDIUM — cycle13_test:70-72 の allow write フォールバック
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] cycle13_test — allow write フォールバックがリグレッションを隠蔽', () {
    test(
      'cycle13_test の Group1 Test2 が allow write フォールバックを持たないとき '
      'firestore.rules を allow write に戻してもテストが通過しない',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 問題:
        //   cycle13_test.dart Line 70-72 の hasCreateRule に
        //     content.contains('allow create') ||
        //     (content.contains('allow write') &&       // ← フォールバック
        //         content.contains('request.auth != null'))
        //   というフォールバックがある。
        //
        //   これにより firestore.rules が:
        //     allow write: if request.auth != null;  ← セキュリティ上問題のある状態
        //   に戻されても `hasCreateRule` が true になりテストが通過する。
        //   → allow create への分離という要件がリグレッションしても検出できない。
        //
        // 修正:
        //   フォールバックを削除して `allow create` のみを検証する:
        //     final hasCreateRule = content.contains('allow create');
        //
        // 現状: `allow write` フォールバックが含まれている → Red
        final hasAllowWriteFallback =
            content.contains("content.contains('allow write')") ||
            content.contains('content.contains("allow write")');

        expect(
          hasAllowWriteFallback,
          isFalse,
          reason: '`voting_security_cycle13_test.dart` Line 70-72 に\n'
              '`allow write` フォールバックが含まれています。\n'
              '\n'
              '問題: このフォールバックにより、`firestore.rules` が\n'
              '  allow write: if request.auth != null;  （セキュリティ上問題）\n'
              'に戻されても `hasCreateRule` が `true` になりテストが通過します。\n'
              '→ `allow create` への分離が後退してもテストが検出できません。\n'
              '\n'
              '現在のコード（Line 70-72）:\n'
              "  final hasCreateRule = content.contains('allow create') ||\n"
              '      (content.contains(\'allow write\') &&\n'
              "          content.contains('request.auth != null'));\n"
              '\n'
              '修正後:\n'
              "  final hasCreateRule = content.contains('allow create');\n",
        );
      },
    );
  });
}
