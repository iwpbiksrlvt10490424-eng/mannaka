// TDD Red フェーズ
// Cycle 15: Cycle14 残件修正のテスト
//
// スコープ:
//   [🔴 CRITICAL] firestore.rules — voting_sessions の update/delete を分離し参加者の votes 更新を許可
//   [🔴 HIGH]     share_preview_screen.dart — 未認証時（currentUser == null）に createSession() を中断 + SnackBar エラー
//   [🔴 HIGH]     voting_security_cycle13_test.dart — Group3 の OR 条件を廃止し share_preview_screen.dart のみ検査
//   [🟡 MEDIUM]   firestore.rules — location_sessions の write に ownerUid 制限を追加

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: [CRITICAL] firestore.rules — update/delete 分離
  // ─────────────────────────────────────────────────────
  group('[CRITICAL] firestore.rules — voting_sessions の update/delete 分離', () {
    test(
      'voting_sessions の allow update と allow delete が別ルールのとき '
      '参加者が votes フィールドを更新でき、削除はホストのみ可能',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状: `allow update, delete: if ... && resource.data.hostUid`
        // → update も hostUid チェックがかかるため、参加者は vote() で tx.update() できない
        //
        // 期待: update と delete が分離されていること
        //   allow update: if request.auth != null;          ← 参加者も更新可
        //   allow delete: if request.auth != null           ← 削除はホストのみ
        //       && request.auth.uid == resource.data.hostUid;
        //
        // 検出方法: `allow update, delete:` のような一括指定がなく、
        //   `allow update:` と `allow delete:` が別々に存在すること
        final hasComboUpdateDelete =
            RegExp(r'allow\s+update\s*,\s*delete\s*:').hasMatch(content);

        expect(
          hasComboUpdateDelete,
          isFalse,
          reason: '`firestore.rules` の `voting_sessions` で `allow update, delete:` が\n'
              '一括指定されています。\n'
              '\n'
              '問題: update にも `request.auth.uid == resource.data.hostUid` チェックがかかるため、\n'
              '      ホスト以外の参加者が `VotingService.vote()` の `tx.update()` を\n'
              '      実行できません（本番で投票機能が完全に動作しないバグ）。\n'
              '\n'
              '修正例:\n'
              '  match /voting_sessions/{sessionId} {\n'
              '    allow read: if request.auth != null;\n'
              '    allow create: if request.auth != null;\n'
              '    allow update: if request.auth != null;  // 参加者も投票更新可\n'
              '    allow delete: if request.auth != null\n'
              '        && request.auth.uid == resource.data.hostUid;  // 削除はホストのみ\n'
              '  }\n'
              '\n'
              '現在の firestore.rules の内容:\n$content',
        );
      },
    );

    test(
      'voting_sessions の allow update が hostUid チェックなしのとき '
      '参加者が tx.update() で candidates を更新できる',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // voting_sessions ブロックを抽出
        final votingSessionsBlock = _extractBlock(content, 'voting_sessions');

        // `allow update:` ルールが `request.auth != null` のみで
        // `resource.data.hostUid` を含まないことを確認
        //
        // 許容パターン:
        //   allow update: if request.auth != null;
        //
        // 拒否パターン（hostUid チェックつき update）:
        //   allow update: if request.auth != null && ... hostUid ...
        //   allow update, delete: if ... hostUid ...
        final hasUpdateWithHostUidOnly = RegExp(
          r'allow\s+update[^;]*resource\.data\.hostUid',
        ).hasMatch(votingSessionsBlock);

        expect(
          hasUpdateWithHostUidOnly,
          isFalse,
          reason: '`voting_sessions` の `allow update` ルールに `resource.data.hostUid` '
              'チェックが含まれています。\n'
              '\n'
              '問題: update に hostUid チェックがあると、ホスト以外が投票できません。\n'
              '      `VotingService.vote()` は参加者（ホスト以外）が呼び出すため、\n'
              '      update は全認証ユーザーに許可する必要があります。\n'
              '\n'
              '修正:\n'
              '  allow update: if request.auth != null;\n'
              '\n'
              'voting_sessions ブロック:\n$votingSessionsBlock',
        );
      },
    );

    test(
      'voting_sessions に allow delete が単独で存在するとき '
      'セッション削除はホストのみに制限される',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // `allow delete:` が単独で存在し、かつ hostUid チェックがあることを確認
        final hasStandaloneDeleteWithHostUid =
            content.contains('allow delete') &&
            content.contains('resource.data.hostUid');

        expect(
          hasStandaloneDeleteWithHostUid,
          isTrue,
          reason: '`firestore.rules` に `allow delete` + `resource.data.hostUid` の\n'
              '組み合わせが見つかりません。\n'
              '\n'
              'セッションの削除はホスト（hostUid）のみに制限してください:\n'
              '  allow delete: if request.auth != null\n'
              '      && request.auth.uid == resource.data.hostUid;\n'
              '\n'
              '現在の firestore.rules の内容:\n$content',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: [HIGH] share_preview_screen — 未認証時の中断
  // ─────────────────────────────────────────────────────
  group('[HIGH] share_preview_screen.dart — 未認証時に createSession() を中断', () {
    test(
      'share_preview_screen.dart の _startVoting が currentUser == null を検査するとき '
      '未認証ユーザーが createSession() を呼び出せない',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // `currentUser == null` チェックが存在することを確認
        // 現状: currentUser を uid 取得にしか使っておらず、null 時でも createSession() を呼び出してしまう
        //
        // 期待:
        //   final user = FirebaseAuth.instance.currentUser;
        //   if (user == null) {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(content: Text('ログインが必要です。')),
        //     );
        //     return;
        //   }
        final hasCurrentUserNullCheck =
            content.contains('currentUser == null') ||
            content.contains('currentUser != null');

        expect(
          hasCurrentUserNullCheck,
          isTrue,
          reason: '`share_preview_screen.dart` の `_startVoting()` に\n'
              '`currentUser == null` のガードがありません。\n'
              '\n'
              '問題: 未認証状態（ゲストユーザー）で「みんなで投票する」ボタンを押すと\n'
              '      `createSession()` が呼ばれ、`hostUid` が空文字のまま\n'
              '      Firestore に書き込まれます。\n'
              '      これにより Firestore Rules の `hostUid` チェックが機能しません。\n'
              '\n'
              '修正例:\n'
              '  Future<void> _startVoting() async {\n'
              '    if (_startingVote) return;\n'
              '    final user = FirebaseAuth.instance.currentUser;\n'
              '    if (user == null) {\n'
              '      if (!mounted) return;\n'
              "      ScaffoldMessenger.of(context).showSnackBar(\n"
              "        const SnackBar(content: Text('ログインが必要です。')),\n"
              '      );\n'
              '      return;\n'
              '    }\n'
              '    setState(() => _startingVote = true);\n'
              '    ...\n'
              '  }',
        );
      },
    );

    test(
      'share_preview_screen.dart が未認証時に SnackBar エラーを表示するとき '
      'ユーザーが操作不能にならずログインを促される',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 認証エラーメッセージが含まれることを確認
        // 「ログイン」「サインイン」「認証」「未ログイン」などの表現を許容
        final hasAuthErrorMessage =
            content.contains('ログインが必要') ||
            content.contains('サインインが必要') ||
            content.contains('ログインしてください') ||
            content.contains('ログインが必要です') ||
            content.contains('未ログイン');

        expect(
          hasAuthErrorMessage,
          isTrue,
          reason: '`share_preview_screen.dart` に未認証時のエラーメッセージが見つかりません。\n'
              '\n'
              '問題: `currentUser == null` の場合、ユーザーに原因が伝わらないまま\n'
              '      画面が止まる可能性があります。\n'
              '\n'
              '修正例: SnackBar でログインを促すメッセージを表示してください:\n'
              "  const SnackBar(content: Text('ログインが必要です。'))\n"
              "  const SnackBar(content: Text('投票するにはログインが必要です。'))",
        );
      },
    );

    test(
      'share_preview_screen.dart の _startVoting が null チェック後に uid を使うとき '
      'hostUid が空文字にならない',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // `currentUser?.uid ?? ''` の null 合体が消え、
        // null チェック後に `user.uid` が直接参照されることが理想
        // （ただし null チェック + uid 参照でも可）
        //
        // 少なくとも currentUser を変数に受けて null チェックすることを確認:
        //   final user = FirebaseAuth.instance.currentUser;
        //   if (user == null) return;
        //   ...
        //   hostUid: user.uid,
        //
        // OR: currentUser != null の確認後に uid を使う
        // null チェック後に uid を直接参照する（null 合体演算子に頼らない）実装を確認
        // 現状: `currentUser?.uid ?? ''` → null 合体で空文字にフォールバック（NG）
        // 期待: `user.uid` または `currentUser!.uid`（null チェック後）
        final hasNullSafeUid =
            content.contains('user.uid') ||
            content.contains('currentUser!.uid');

        expect(
          hasNullSafeUid,
          isTrue,
          reason: '`share_preview_screen.dart` で `currentUser` の null チェック後に\n'
              '`uid` を参照する実装が見つかりません。\n'
              '\n'
              '修正例:\n'
              '  final user = FirebaseAuth.instance.currentUser;\n'
              '  if (user == null) { /* エラー処理 */ return; }\n'
              '  final sessionId = await VotingService.createSession(\n'
              '    hostName: hostName,\n'
              '    candidates: top3,\n'
              '    hostUid: user.uid,  // null 安全\n'
              '  );',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: [HIGH] cycle13 テスト — OR 条件廃止 + API キー削除
  // ─────────────────────────────────────────────────────
  group('[HIGH] voting_security_cycle13_test.dart — 偽グリーン解消とAPIキー削除', () {
    test(
      'cycle13 テストのグループ3が .any() で複数ファイルを OR 検索しないとき '
      'share_preview_screen.dart のみを対象にした真のグリーンになる',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // 現状の偽グリーンの原因:
        //   `[sharePreviewFile, votingFile].any(...)` という OR 条件で
        //   どちらか一方に ArgumentError ハンドリングがあればパスしてしまう
        //
        // 期待: `.any(` が削除され、sharePreviewFile のみ単独で検査される
        // 検出: `vote_invite_screen.dart` または `voting_screen.dart` を
        //       createSession の ArgumentError ハンドラ検査対象として含む .any() がない
        // 現状: `[sharePreviewFile, votingFile].any((file) { ... })`
        // という形でリストに voting_screen のファイル変数が入っている。
        // 単純な文字列検索で検出する。
        final hasMultipleFileOrCheck =
            content.contains('[sharePreviewFile, votingFile]') ||
            content.contains('[votingFile, sharePreviewFile]') ||
            // votingFile が createSession ArgumentError チェックの any() に含まれるパターン
            (content.contains('votingFile') &&
                content.contains('.any(') &&
                content.contains('ArgumentError'));

        expect(
          hasMultipleFileOrCheck,
          isFalse,
          reason: '`voting_security_cycle13_test.dart` グループ3が\n'
              '`vote_invite_screen.dart` や `voting_screen.dart` を含む `.any()` で\n'
              'ArgumentError ハンドリングを OR 検査しています（偽グリーン）。\n'
              '\n'
              '問題:\n'
              '  `createSession()` の呼び出し元は `share_preview_screen.dart` のみ。\n'
              '  `voting_screen.dart` に ArgumentError 処理があることで\n'
              '  `share_preview_screen.dart` に実装がなくてもテストが通過してしまいます。\n'
              '\n'
              '修正内容:\n'
              '  1. `.any([sharePreviewFile, votingFile])` を削除\n'
              '  2. `sharePreviewFile` のみを単独で検査するように書き換え\n'
              '  3. `voteInviteFile` 変数も不要なら削除\n'
              '\n'
              '修正後の検査例:\n'
              '  final content = sharePreviewFile.readAsStringSync();\n'
              "  final hasHandler = content.contains('is ArgumentError')\n"
              "      || content.contains('on ArgumentError');\n"
              '  expect(hasHandler, isTrue, reason: ...);\n',
        );
      },
    );

    test(
      'cycle13 テストファイルに Foursquare APIキーの実値が含まれないとき '
      'テストコード自体がAPIキー漏洩の媒体にならない',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // テストファイル自体に Foursquare の実APIキーが埋め込まれていないことを確認。
        // SECURITY.md の「既知リスク」からキーが削除済みであれば、
        // テストファイル側でも実値を検索文字列として保持すべきではない。
        //
        // 現状: グループ4 の `hasLiveApiKey` 変数がキーの実値を文字列定数として持っている。
        //       → テストファイルが git にコミットされるとキーが露出する。
        //
        // 修正: 実値の代わりに `[FSQ_API_KEY_REMOVED]` のような無害なプレースホルダーを使うか、
        //       またはグループ4テスト自体を「キーが存在しないこと」ではなく
        //       「secrets.dart に移動済みであること」を確認する形に変更する。
        final hasHardcodedFoursquareKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);

        expect(
          hasHardcodedFoursquareKey,
          isFalse,
          reason: '`test/security/voting_security_cycle13_test.dart` に\n'
              'Foursquare APIキーの実値 `RB4P...` が文字列定数として埋め込まれています。\n'
              '\n'
              '問題: テストファイルが git にプッシュされると APIキーが公開されます。\n'
              '      セキュリティチェックのためにキーを書いても本末転倒です。\n'
              '\n'
              '修正例1（キーパターンをチェックする形式に変更）:\n'
              '  // Foursquare の実キーが SECURITY.md に掲載されていないことを確認\n'
              '  // キーのパターン: 英数字 48文字以上の大文字列\n'
              "  final hasRawKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(riskSection);\n"
              '\n'
              '修正例2（テストをコメントに置き換え）:\n'
              '  // Foursquare APIキーは secrets.dart に移行済みのため、\n'
              '  // このテストは解消済みとしてスキップ\n',
        );
      },
    );

    test(
      "RegExp(r'[A-Z0-9]{40,}') が40文字以上の英大文字列を検出するとき "
      '39文字以下は検出せず40文字以上は検出する',
      () {
        expect(RegExp(r'[A-Z0-9]{40,}').hasMatch('SHORTKEY123'), isFalse);
        expect(RegExp(r'[A-Z0-9]{40,}').hasMatch('A' * 40), isTrue);
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: [MEDIUM] firestore.rules — location_sessions の ownerUid 制限
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] firestore.rules — location_sessions の ownerUid による書き込み制限', () {
    test(
      'location_sessions の write ルールに ownerUid チェックがあるとき '
      '他人の位置情報セッションを上書きできない',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // location_sessions ブロックを抽出
        final locationBlock = _extractBlock(content, 'location_sessions');

        // write（または create/update）ルールに ownerUid チェックがあることを確認
        // 現状: `allow write: if request.auth != null;`
        //       → 認証済みであれば誰でも他人の位置情報セッションを書き換えられる
        //
        // 期待:
        //   allow create: if request.auth != null
        //       && request.auth.uid == request.resource.data.ownerUid;
        //   allow update, delete: if request.auth != null
        //       && request.auth.uid == resource.data.ownerUid;
        final hasOwnerUidCheck =
            locationBlock.contains('ownerUid') ||
            content.contains('location_sessions') &&
                content.contains('ownerUid');

        expect(
          hasOwnerUidCheck,
          isTrue,
          reason: '`firestore.rules` の `location_sessions` write ルールに\n'
              '`ownerUid` チェックがありません。\n'
              '\n'
              '問題: 現在のルール `allow write: if request.auth != null` では\n'
              '      認証済みの任意のユーザーが他人の GPS 位置情報セッションを\n'
              '      書き換えたり削除したりできます。\n'
              '\n'
              '修正例:\n'
              '  match /location_sessions/{sessionId} {\n'
              '    allow read: if request.auth != null;\n'
              '    allow create: if request.auth != null\n'
              '        && request.auth.uid == request.resource.data.ownerUid;\n'
              '    allow update, delete: if request.auth != null\n'
              '        && request.auth.uid == resource.data.ownerUid;\n'
              '  }\n'
              '\n'
              'location_sessions ブロック:\n$locationBlock',
        );
      },
    );

    test(
      'location_sessions の create ルールが request.resource.data.ownerUid を使うとき '
      '作成時に自分の uid だけを ownerUid として設定できる',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // `request.resource.data.ownerUid` は新規作成データの ownerUid を参照する
        // `resource.data.ownerUid` は既存データを参照する（update/delete 用）
        //
        // create には `request.resource.data.ownerUid` が必要
        final hasCreateOwnerUid =
            content.contains('request.resource.data.ownerUid');

        expect(
          hasCreateOwnerUid,
          isTrue,
          reason: '`firestore.rules` に `request.resource.data.ownerUid` がありません。\n'
              '\n'
              '`location_sessions` の create ルールでは、新規作成データの ownerUid が\n'
              '自分の UID と一致することを検証するために `request.resource.data.ownerUid`\n'
              '（`resource.data` ではなく `request.resource.data`）を使う必要があります。\n'
              '\n'
              '修正例:\n'
              '  allow create: if request.auth != null\n'
              '      && request.auth.uid == request.resource.data.ownerUid;\n',
        );
      },
    );
  });
}

// ─────────────────────────────────────────────────────
// ヘルパー
// ─────────────────────────────────────────────────────

/// ファイル内容から指定コレクション名の match ブロックを抽出する
String _extractBlock(String content, String collectionName) {
  final idx = content.indexOf(collectionName);
  if (idx < 0) return '($collectionName ブロックが見つかりません)';
  // match { ... } のブロックを抽出（簡易的に次の match まで）
  final blockStart = content.lastIndexOf('match', idx);
  if (blockStart < 0) return content.substring(idx, (idx + 200).clamp(0, content.length));
  final blockEnd = content.indexOf('\n  }', blockStart + 5);
  if (blockEnd < 0) return content.substring(blockStart);
  return content.substring(blockStart, blockEnd + 4);
}
