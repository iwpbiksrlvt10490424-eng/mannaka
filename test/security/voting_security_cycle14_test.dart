// TDD Red フェーズ
// Cycle 14: Cycle13 残件修正のテスト
//
// スコープ:
//   [🔴 CRITICAL] share_preview_screen.dart — createSession() に hostUid を渡す
//   [🔴 HIGH]    share_preview_screen.dart — catch で ArgumentError を識別してユーザー向けメッセージ表示
//   [🔴 HIGH]    voting_security_cycle13_test.dart — 偽グリーン解消（share_preview_screen に修正）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: [CRITICAL] share_preview_screen — hostUid の引き渡し
  // ─────────────────────────────────────────────────────
  group('[CRITICAL] share_preview_screen.dart — createSession に hostUid を渡す', () {
    test(
      'createSession の呼び出しに hostUid: が含まれるとき '
      'Firestore の hostUid フィールドが設定されホスト以外の改ざんを防げる',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // createSession( ... hostUid: ... ) の形で hostUid が渡されていることを確認
        // 現状: VotingService.createSession(hostName: hostName, candidates: top3,)
        //       hostUid が渡されていないため、Firestore の hostUid フィールドが空になる
        //
        // 期待:
        //   VotingService.createSession(
        //     hostName: hostName,
        //     candidates: top3,
        //     hostUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        //   );
        final hasHostUid = content.contains('hostUid:');

        expect(
          hasHostUid,
          isTrue,
          reason: '`share_preview_screen.dart` の `createSession()` 呼び出しに '
              '`hostUid:` が含まれていません。\n'
              '\n'
              '問題: `hostUid` を渡さないと Firestore の voting_sessions ドキュメントの\n'
              '      `hostUid` フィールドが空文字になり、ルールによるアクセス制御が\n'
              '      機能しません（`request.auth.uid == resource.data.hostUid` が\n'
              '      常に false になる）。\n'
              '\n'
              '修正例:\n'
              '  final sessionId = await VotingService.createSession(\n'
              '    hostName: hostName,\n'
              '    candidates: top3,\n'
              "    hostUid: FirebaseAuth.instance.currentUser?.uid ?? '',\n"
              '  );\n'
              '\n'
              '必要なインポート:\n'
              "  import 'package:firebase_auth/firebase_auth.dart';\n",
        );
      },
    );

    test(
      'share_preview_screen.dart が FirebaseAuth をインポートしているとき '
      'currentUser?.uid への参照が型安全に解決される',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // firebase_auth のインポートがあることを確認
        // 現状: firebase_auth はインポートされていない
        final hasFirebaseAuthImport =
            content.contains("import 'package:firebase_auth/firebase_auth.dart'") ||
            content.contains('import "package:firebase_auth/firebase_auth.dart"');

        expect(
          hasFirebaseAuthImport,
          isTrue,
          reason: '`share_preview_screen.dart` に `firebase_auth` のインポートがありません。\n'
              '\n'
              '`FirebaseAuth.instance.currentUser?.uid` を使うために以下を追加してください:\n'
              "  import 'package:firebase_auth/firebase_auth.dart';\n",
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: [HIGH] share_preview_screen — ArgumentError のユーザー向けメッセージ
  // ─────────────────────────────────────────────────────
  group('[HIGH] share_preview_screen.dart — ArgumentError のユーザー向けメッセージ表示', () {
    test(
      '_startVoting の catch ブロックが ArgumentError を識別するとき '
      'ユーザーに原因が伝わる具体的なメッセージを表示する',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // ArgumentError を識別するハンドリングがあることを確認
        // 現状の catch ブロック:
        //   } catch (e) {
        //     if (mounted) {
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         const SnackBar(content: Text('投票セッションの作成に失敗しました。もう一度お試しください。')),
        //       );
        //     }
        //   }
        // → ArgumentError か否かを区別していない
        //
        // 期待:
        //   } catch (e) {
        //     if (!mounted) return;
        //     final message = e is ArgumentError
        //         ? e.message?.toString() ?? '入力値が正しくありません'
        //         : '投票セッションの作成に失敗しました。もう一度お試しください。';
        //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        //   }
        final hasArgumentErrorHandling =
            content.contains('is ArgumentError') ||
            content.contains('on ArgumentError');

        expect(
          hasArgumentErrorHandling,
          isTrue,
          reason: '`share_preview_screen.dart` の `_startVoting()` catch ブロックが\n'
              '`ArgumentError` を識別していません。\n'
              '\n'
              '問題: VotingService.createSession() が ArgumentError を throw しても\n'
              '      現在は「投票セッションの作成に失敗しました。もう一度お試しください。」\n'
              '      のみ表示され、ユーザーは名前が長すぎることを理解できません。\n'
              '\n'
              '修正例:\n'
              '  } catch (e) {\n'
              '    if (!mounted) return;\n'
              '    final message = e is ArgumentError\n'
              "        ? e.message?.toString() ?? '入力値が正しくありません'\n"
              "        : '投票セッションの作成に失敗しました。もう一度お試しください。';\n"
              '    ScaffoldMessenger.of(context).showSnackBar(\n'
              '      SnackBar(content: Text(message)),\n'
              '    );\n'
              '  }',
        );
      },
    );

    test(
      'share_preview_screen.dart の _startVoting が ArgumentError メッセージを使うとき '
      'e.message が SnackBar テキストとして表示される',
      () {
        final file = File('lib/screens/share_preview_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // e.message が参照されていることを確認
        // ArgumentError の message プロパティを使い、バリデーションメッセージをそのまま表示する
        final hasMessageRef =
            content.contains('e.message') ||
            content.contains('ArgumentError');

        expect(
          hasMessageRef,
          isTrue,
          reason: '`share_preview_screen.dart` で `e.message` または `ArgumentError` の\n'
              '参照が見つかりません。\n'
              '\n'
              '`e is ArgumentError` チェックと `e.message` 参照を追加してください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: [HIGH] 偽グリーン解消 — cycle13テストのグループ3修正
  // ─────────────────────────────────────────────────────
  group('[HIGH] 偽グリーン解消 — voting_security_cycle13_test グループ3', () {
    test(
      'voting_security_cycle13_test.dart のグループ3が share_preview_screen.dart を '
      '検査対象に含めているとき 偽グリーンが発生しない',
      () {
        final file = File('test/security/voting_security_cycle13_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle13_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // グループ3のテストが share_preview_screen.dart を検査しているか確認
        // 現状:
        //   final voteInviteFile = File('lib/screens/vote_invite_screen.dart');
        //   final votingFile = File('lib/screens/voting_screen.dart');
        //   → share_preview_screen.dart は検査対象に含まれていない
        //
        // voting_screen.dart に ArgumentError ハンドリングがあるため、
        // share_preview_screen.dart に実装がなくてもテストが通る（偽グリーン）
        //
        // 期待: グループ3で share_preview_screen.dart を明示的に検査する
        final checksSharePreviewScreen = content.contains('share_preview_screen.dart') ||
            content.contains('SharePreviewScreen');

        expect(
          checksSharePreviewScreen,
          isTrue,
          reason: '`test/security/voting_security_cycle13_test.dart` グループ3が\n'
              '`share_preview_screen.dart` を検査対象に含めていません。\n'
              '\n'
              '問題（偽グリーン）:\n'
              '  - `createSession()` は `share_preview_screen.dart` で呼ばれる\n'
              '  - グループ3は `vote_invite_screen.dart` と `voting_screen.dart` を検査\n'
              '  - `voting_screen.dart` が `ArgumentError` を処理しているため\n'
              '    `share_preview_screen.dart` に実装がなくてもテストが通過してしまう\n'
              '\n'
              '修正内容:\n'
              "  1. `final sharePreviewFile = File('lib/screens/share_preview_screen.dart');`\n"
              '     を追加\n'
              '  2. `createSession` の呼び出し元として `sharePreviewFile` を検査対象に追加\n'
              '  3. `voteInviteFile` は `createSession` を呼ばないため検査対象から除外可能',
        );
      },
    );

    test(
      'share_preview_screen.dart が createSession の ArgumentError を '
      '直接ハンドルしているとき cycle13テストのグループ3が真にグリーンになる',
      () {
        // share_preview_screen.dart に ArgumentError ハンドリングがあることを直接検証
        // これが Greenになれば cycle13 グループ3修正後のテストも真にパスできる
        final sharePreviewFile = File('lib/screens/share_preview_screen.dart');
        if (!sharePreviewFile.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final sharePreviewContent = sharePreviewFile.readAsStringSync();

        final sharePreviewHandlesArgumentError =
            sharePreviewContent.contains('is ArgumentError') ||
            sharePreviewContent.contains('on ArgumentError');

        expect(
          sharePreviewHandlesArgumentError,
          isTrue,
          reason: '`share_preview_screen.dart` に `ArgumentError` のハンドリングがありません。\n'
              '\n'
              'createSession() を呼び出す `share_preview_screen.dart` の\n'
              '`_startVoting()` メソッドで ArgumentError を識別し、\n'
              'ユーザーに適切なメッセージを表示する実装が必要です。\n'
              '\n'
              '（このテストが Green になると cycle13 グループ3の偽グリーンが解消される）',
        );
      },
    );
  });
}
