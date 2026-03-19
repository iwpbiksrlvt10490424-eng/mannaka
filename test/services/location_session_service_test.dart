// TDD テスト
// Cycle 18: LocationSessionService ownerUid フィールド書き込み検証
//
// スコープ:
//   [🟢 LOW] location_session_service.dart — createSession() が ownerUid を
//            Firestore に書き込むことをテストで証明する（Cycle 17 で実装済み）
//
// 注意: このテストは Cycle 17 完了時点で実装済みのため、初回から Green になります。
//      テストの目的は「ownerUid 書き込み」という要件をコードで文書化することです。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: createSession() ownerUid フィールド書き込み
  // ─────────────────────────────────────────────────────
  group('LocationSessionService.createSession() — ownerUid フィールド検証', () {
    test(
      'createSession() が required String ownerUid パラメータを持つとき '
      '呼び出し側が UID を渡し忘れるとコンパイルエラーで防止できる',
      () {
        final file = File('lib/services/location_session_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/location_session_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // createSession() のシグネチャに required String ownerUid が含まれること
        final hasOwnerUidParam =
            content.contains('required String ownerUid') ||
            content.contains('required final String ownerUid');

        expect(
          hasOwnerUidParam,
          isTrue,
          reason:
              '`createSession()` のシグネチャに `required String ownerUid` が\n'
              'ありません。\n'
              '\n'
              '問題: `ownerUid` は呼び出し側（search_screen.dart）から\n'
              '      `FirebaseAuth.instance.currentUser?.uid` を渡す必要があります。\n'
              '      `required` にすることでコンパイル時に渡し忘れを防止できます。\n'
              '\n'
              '期待するシグネチャ:\n'
              '  static Future<String> createSession({\n'
              '    required String hostName,\n'
              '    required int slotIndex,\n'
              '    required String participantName,\n'
              '    required String ownerUid,   // ← これが必要\n'
              '  }) async {\n',
        );
      },
    );

    test(
      'createSession() が Firestore の set() に ownerUid キーを含むとき '
      'firestore.rules の allow create 条件を満たしてアクセスが許可される',
      () {
        final file = File('lib/services/location_session_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/location_session_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // Firestore の set() に 'ownerUid': ownerUid が含まれること
        final hasOwnerUidInSetCall =
            content.contains("'ownerUid': ownerUid") ||
            content.contains('"ownerUid": ownerUid');

        expect(
          hasOwnerUidInSetCall,
          isTrue,
          reason:
              '`createSession()` の Firestore `set()` 呼び出しに\n'
              "`'ownerUid': ownerUid` が含まれていません。\n"
              '\n'
              '問題: `firestore.rules` の `location_sessions` コレクションには:\n'
              '  allow create: if request.auth != null\n'
              '      && request.auth.uid == request.resource.data.ownerUid;\n'
              'というルールがあります。\n'
              '`ownerUid` フィールドを書き込まないと `PERMISSION_DENIED` になります。\n'
              '\n'
              '期待する set() の内容:\n'
              '  await _db.collection(_collection).doc(sessionId).set({\n'
              "    'ownerUid': ownerUid,   // ← firestore.rules の allow create を満たす\n"
              "    'hostName': hostName,\n"
              '    ...\n'
              '  });\n',
        );
      },
    );

    test(
      'createSession() の ownerUid が set() の最初のフィールドとして書かれているとき '
      'セキュリティ要件として明示的に確認できる',
      () {
        final file = File('lib/services/location_session_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/location_session_service.dart が存在しません。');
        }
        final lines = file.readAsLinesSync();

        // set() ブロックの開始位置を探す
        final setCallIdx = lines.indexWhere(
          (l) => l.contains('.set({') || l.contains('.set( {'),
        );
        expect(
          setCallIdx,
          isNot(-1),
          reason: '`.set({` の行が見つかりません。',
        );

        // set() の最初の数行（10行以内）に 'ownerUid' が含まれること
        final setBlock = lines
            .skip(setCallIdx)
            .take(10)
            .join('\n');
        final hasOwnerUidEarly = setBlock.contains("'ownerUid'") ||
            setBlock.contains('"ownerUid"');

        expect(
          hasOwnerUidEarly,
          isTrue,
          reason:
              '`createSession()` の `set()` の最初の10行以内に\n'
              "`'ownerUid'` フィールドが見つかりません。\n"
              '\n'
              '`ownerUid` は firestore.rules の allow create を満たすために必須のフィールドです。\n'
              '意図を明示するため set() の先頭付近に記述することが推奨されます。\n',
        );
      },
    );
  });
}
