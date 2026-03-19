// TDD Red フェーズ
// Cycle 7: firestore.rules 未設定問題のテスト (Security ISSUE-S1)
//
// 問題:
//   `firestore.rules` ファイルが存在しない。
//   Firestore のデフォルトルールでは認証なしのユーザーにも
//   読み書きが許可される可能性があり、投票セッションデータが全公開になる。
//
// 修正方針:
//   `firestore.rules` を新規作成し、以下のルールを設定する:
//   - 認証されていないユーザーの書き込みを禁止
//   - デフォルト deny（明示的に許可されていないアクセスは全て拒否）
//
// テスト戦略:
//   1. firestore.rules ファイルが存在することを確認する
//   2. デフォルト deny ルール (`allow read, write: if false`) が含まれることを確認する
//   3. 認証チェック (`request.auth != null`) が含まれることを確認する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('セキュリティ — Firestore Rules 設定', () {
    test(
        'firestore.rules が存在するとき '
        '投票セッションデータが無防備に公開されない',
        () {
      final file = File('firestore.rules');
      expect(
        file.existsSync(),
        isTrue,
        reason: '`firestore.rules` ファイルが存在しません。\n'
            'Firestore のデフォルトルールは認証なしアクセスを許可する場合があります。\n'
            'プロジェクトルートに `firestore.rules` を作成してください。\n'
            '\n'
            '最低限のルール例:\n'
            'rules_version = "2";\n'
            'service cloud.firestore {\n'
            '  match /databases/{database}/documents {\n'
            '    // デフォルト deny\n'
            '    match /{document=**} {\n'
            '      allow read, write: if false;\n'
            '    }\n'
            '    // 投票セッション: 認証ユーザーのみ\n'
            '    match /votingSessions/{sessionId} {\n'
            '      allow read: if request.auth != null;\n'
            '      allow write: if request.auth != null;\n'
            '    }\n'
            '  }\n'
            '}',
      );
    });

    test(
        'firestore.rules がデフォルト deny ルールを含むとき '
        '未定義パスへの無許可アクセスが拒否される',
        () {
      final file = File('firestore.rules');
      if (!file.existsSync()) {
        fail(
          'firestore.rules が存在しません。\n'
          'このテストは firestore.rules の存在を前提としています。\n'
          '先に「firestore.rules が存在するとき」テストを修正してください。',
        );
      }

      final content = file.readAsStringSync();

      // デフォルト deny パターンを検出:
      // `allow read, write: if false` または `allow read, write: if false;`
      final hasDefaultDeny = content.contains('allow read, write: if false') ||
          content.contains('allow write: if false') ||
          content.contains('allow read: if false');

      expect(
        hasDefaultDeny,
        isTrue,
        reason: 'firestore.rules にデフォルト deny ルールが含まれていません。\n'
            '明示的に許可されていないパスへのアクセスを拒否するために\n'
            '以下のパターンのいずれかを追加してください:\n'
            '  allow read, write: if false;\n'
            '\n'
            '現在の firestore.rules の内容:\n$content',
      );
    });

    test(
        'firestore.rules が認証チェックを含むとき '
        '認証されていないユーザーの書き込みが禁止される',
        () {
      final file = File('firestore.rules');
      if (!file.existsSync()) {
        fail(
          'firestore.rules が存在しません。\n'
          'このテストは firestore.rules の存在を前提としています。\n'
          '先に「firestore.rules が存在するとき」テストを修正してください。',
        );
      }

      final content = file.readAsStringSync();

      // `request.auth != null` による認証チェックを検出
      final hasAuthCheck = content.contains('request.auth != null');

      expect(
        hasAuthCheck,
        isTrue,
        reason: 'firestore.rules に `request.auth != null` の認証チェックがありません。\n'
            '投票セッションへの書き込みは認証ユーザーのみに限定してください。\n'
            '\n'
            '例:\n'
            '  match /votingSessions/{sessionId} {\n'
            '    allow write: if request.auth != null;\n'
            '  }\n'
            '\n'
            '現在の firestore.rules の内容:\n$content',
      );
    });

    // --- Cycle 8 追加テスト ---

    test(
        'firestore.rules のコレクション名が voting_sessions (snake_case) であるとき '
        'VotingService._col と一致してデータが読み書きできる',
        () {
      final file = File('firestore.rules');
      if (!file.existsSync()) {
        fail('firestore.rules が存在しません。');
      }

      final content = file.readAsStringSync();

      // VotingService._col = 'voting_sessions'（snake_case）と一致するパスが必要
      // `match /voting_sessions/{...}` または `/voting_sessions/` の形式を確認
      final hasSnakeCaseCollection = content.contains('/voting_sessions/') ||
          content.contains("'voting_sessions'") ||
          content.contains('"voting_sessions"');

      expect(
        hasSnakeCaseCollection,
        isTrue,
        reason: '`firestore.rules` に `voting_sessions`（snake_case）のコレクション定義がありません。\n'
            '\n'
            '問題: VotingService._col = \'voting_sessions\' だが、\n'
            '      firestore.rules には `votingSessions`（camelCase）が定義されている。\n'
            '      コレクション名の不一致により、本番環境で投票データが\n'
            '      Firestore のデフォルトルール（deny）によって書き込み禁止になる。\n'
            '\n'
            '修正: firestore.rules の `match /votingSessions/{sessionId}` を\n'
            '      `match /voting_sessions/{sessionId}` に変更してください。\n'
            '\n'
            '現在の firestore.rules の内容:\n$content',
      );
    });

    test(
        'firestore.rules に location_sessions コレクションが定義されているとき '
        'GPS座標データが無防備に公開されない',
        () {
      final file = File('firestore.rules');
      if (!file.existsSync()) {
        fail('firestore.rules が存在しません。');
      }

      final content = file.readAsStringSync();

      // LocationSessionService._collection = 'location_sessions'
      final hasLocationSessions = content.contains('location_sessions');

      expect(
        hasLocationSessions,
        isTrue,
        reason: '`firestore.rules` に `location_sessions` コレクションの定義がありません。\n'
            '\n'
            '問題: LocationSessionService は `location_sessions` コレクションに\n'
            '      ユーザーの GPS 座標（lat/lng）を書き込む。\n'
            '      現在の rules では `location_sessions` が明示的に許可されておらず、\n'
            '      デフォルト deny により位置情報の送受信が本番で完全に失敗する。\n'
            '\n'
            '修正: 以下を firestore.rules に追加してください:\n'
            '  match /location_sessions/{sessionId} {\n'
            '    allow read: if request.auth != null;\n'
            '    allow write: if request.auth != null;\n'
            '  }\n'
            '\n'
            '現在の firestore.rules の内容:\n$content',
      );
    });
  });
}
