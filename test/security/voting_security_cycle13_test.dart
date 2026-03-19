// TDD Red フェーズ
// Cycle 13: Voting機能セキュリティ強化テスト
//
// スコープ:
//   [🔴 HIGH]   firestore.rules — voting_sessions write に hostUid 制約追加
//   [🔴 HIGH]   voting_service.dart — hostName/voterName 50文字バリデーション
//   [🟡 MEDIUM] voting_screen.dart — ArgumentError のユーザー向けメッセージ表示
//   [🟢 LOW]    SECURITY.md — 解消済み Foursquare APIキー記載を削除

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: Firestore Rules — hostUid write 制約
  // ─────────────────────────────────────────────────────
  group('[HIGH] firestore.rules — voting_sessions write の hostUid 制約', () {
    test(
      'voting_sessions の allow delete ブロックに hostUid チェックがあるとき '
      'セッション削除はホストのみに制限される',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // allow delete ブロックに絞って hostUid チェックがあることを確認。
        // allow update（参加者も更新可）と allow delete（ホストのみ削除可）が
        // 分離されていることが前提。
        final lines = content.split('\n');
        final deleteIdx = lines.indexWhere((l) => l.contains('allow delete'));
        expect(deleteIdx, isNot(-1), reason: 'firestore.rules に allow delete 行が見つかりません');
        final deleteBlock = lines.skip(deleteIdx).take(3).join('\n');
        final hasHostUid = deleteBlock.contains('resource.data.hostUid');

        expect(
          hasHostUid,
          isTrue,
          reason: '`firestore.rules` の `allow delete` ブロックに '
              '`resource.data.hostUid` チェックが含まれていません。\n'
              '\n'
              '問題: allow delete に hostUid チェックがないと、\n'
              '      認証済みの任意のユーザーが他人のセッションを削除できます。\n'
              '\n'
              '修正例:\n'
              '  allow delete: if request.auth != null\n'
              '      && request.auth.uid == resource.data.hostUid;\n'
              '\n'
              '現在の firestore.rules の内容:\n$content',
        );
      },
    );

    test(
      'voting_sessions の create と update/delete が分離されているとき '
      '新規作成はできるが既存セッションの変更はホストのみ可能',
      () {
        final file = File('firestore.rules');
        if (!file.existsSync()) {
          fail('firestore.rules が存在しません。');
        }
        final content = file.readAsStringSync();

        // create（新規作成）と update/delete（変更・削除）でルールが分離されていることを確認。
        // `allow write` の一括指定では create にも hostUid チェックがかかり、
        // 新規セッション作成時に resource.data（既存データ）が存在しないため常に失敗する。
        final lines = content.split('\n');
        final hasCreateRule = content.contains('allow create');
        final hasUpdateLine =
            lines.any((l) => RegExp(r'allow\s+update\s*:').hasMatch(l));
        final hasDeleteLine =
            lines.any((l) => RegExp(r'allow\s+delete\s*:').hasMatch(l));

        expect(
          hasCreateRule && hasUpdateLine && hasDeleteLine,
          isTrue,
          reason: '`voting_sessions` のルールで create と update/delete が分離されていません。\n'
              '\n'
              '問題: `allow write: if request.auth.uid == resource.data.hostUid` と\n'
              '      一括指定すると、新規作成時に resource.data が存在しないため常に失敗します。\n'
              '\n'
              '修正例:\n'
              '  allow create: if request.auth != null;\n'
              '  allow update, delete: if request.auth != null\n'
              '      && request.auth.uid == resource.data.hostUid;\n'
              '\n'
              '現在の firestore.rules の内容:\n$content',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: VotingService — 50文字バリデーション
  // ─────────────────────────────────────────────────────
  group('[HIGH] voting_service.dart — hostName/voterName 50文字バリデーション', () {
    test(
      'createSession の hostName が 50文字を超えるとき '
      'ArgumentError が throw される（Firestoreへの書き込み前に検証）',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // hostName のバリデーション: `hostName.length > 50` または `hostName.length >= 51`
        // かつ ArgumentError を throw する実装があることを確認
        final hasHostNameValidation =
            RegExp(r'hostName\.length\s*[>≥]\s*5[01]').hasMatch(content) ||
            RegExp(r'hostName\.length\s*>\s*50').hasMatch(content) ||
            RegExp(r'if\s*\(.*hostName.*\)\s*\n?\s*throw\s+ArgumentError')
                .hasMatch(content);

        expect(
          hasHostNameValidation,
          isTrue,
          reason: '`voting_service.dart` の `createSession()` に '
              '`hostName` の文字数バリデーションがありません。\n'
              '\n'
              '問題: Firestoreに50文字超えの名前が書き込まれると、\n'
              '      UI表示が崩れたり、他のユーザーへの通知が破損する可能性があります。\n'
              '\n'
              '修正例:\n'
              "  if (hostName.length > 50) {\n"
              "    throw ArgumentError('hostName は50文字以内にしてください');\n"
              "  }\n"
              '\n'
              '現在の voting_service.dart の内容（抜粋）:\n'
              '${_extractLines(content, 'createSession')}',
        );
      },
    );

    test(
      'vote の voterName が 50文字を超えるとき '
      'ArgumentError が throw される（Firestoreへの書き込み前に検証）',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // voterName のバリデーション
        final hasVoterNameValidation =
            RegExp(r'voterName\.length\s*[>≥]\s*5[01]').hasMatch(content) ||
            RegExp(r'voterName\.length\s*>\s*50').hasMatch(content) ||
            RegExp(r'if\s*\(.*voterName.*\)\s*\n?\s*throw\s+ArgumentError')
                .hasMatch(content);

        expect(
          hasVoterNameValidation,
          isTrue,
          reason: '`voting_service.dart` の `vote()` に '
              '`voterName` の文字数バリデーションがありません。\n'
              '\n'
              '問題: 50文字超えの voterName が voters リストに追加されると\n'
              '      二重投票防止ロジック（`voters.contains(voterName)`）が\n'
              '      長い文字列同士の比較で意図しない動作をする可能性があります。\n'
              '\n'
              '修正例:\n'
              "  if (voterName.length > 50) {\n"
              "    throw ArgumentError('voterName は50文字以内にしてください');\n"
              "  }\n",
        );
      },
    );

    test(
      'voting_service.dart に ArgumentError の throw が含まれるとき '
      'バリデーション実装が存在する',
      () {
        final file = File('lib/services/voting_service.dart');
        if (!file.existsSync()) {
          fail('lib/services/voting_service.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        final hasArgumentError = content.contains('throw ArgumentError');

        expect(
          hasArgumentError,
          isTrue,
          reason: '`voting_service.dart` に `throw ArgumentError` がありません。\n'
              '\n'
              '`hostName` と `voterName` の両方に対して:\n'
              "  throw ArgumentError('...');\n"
              'を追加してください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: VotingScreen — ArgumentError のユーザーメッセージ
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] voting_screen.dart — ArgumentError のユーザー向けメッセージ表示', () {
    test(
      'vote() の catch ブロックが ArgumentError を識別するとき '
      '「名前が長すぎます」など具体的なメッセージをSnackBarで表示する',
      () {
        final file = File('lib/screens/voting_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/voting_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // ArgumentError を専用ハンドリングしているかチェック
        // 例: `catch (e)` ブロック内で `e is ArgumentError` または
        //     `on ArgumentError catch(e)` パターン
        final hasArgumentErrorHandling =
            content.contains('is ArgumentError') ||
            content.contains('on ArgumentError') ||
            content.contains('ArgumentError');

        expect(
          hasArgumentErrorHandling,
          isTrue,
          reason: '`voting_screen.dart` の `_vote()` catch ブロックが '
              '`ArgumentError` を識別していません。\n'
              '\n'
              '問題: VotingService.vote() が ArgumentError を throw しても\n'
              '      現在のキャッチは「投票に失敗しました。もう一度お試しください。」のみ表示。\n'
              '      ユーザーは名前が長すぎることを理解できず、操作不能になります。\n'
              '\n'
              '修正例:\n'
              '  } catch (e) {\n'
              '    if (!mounted) return;\n'
              '    setState(() => _voting = false);\n'
              '    final message = e is ArgumentError\n'
              "        ? e.message?.toString() ?? '入力値が正しくありません'\n"
              "        : '投票に失敗しました。もう一度お試しください。';\n"
              '    ScaffoldMessenger.of(context).showSnackBar(\n'
              '      SnackBar(content: Text(message)),\n'
              '    );\n'
              '  }',
        );
      },
    );

    test(
      'createSession の ArgumentError が share_preview_screen でハンドルされるとき '
      'ユーザーに原因が伝わるメッセージが表示される',
      () {
        // createSession の呼び出し元は share_preview_screen.dart のみ
        final sharePreviewFile = File('lib/screens/share_preview_screen.dart');

        if (!sharePreviewFile.existsSync()) {
          fail('lib/screens/share_preview_screen.dart が存在しません。');
        }
        final content = sharePreviewFile.readAsStringSync();
        final hasHandler = content.contains('ArgumentError') ||
            content.contains('is ArgumentError') ||
            content.contains('on ArgumentError');

        expect(
          hasHandler,
          isTrue,
          reason: '`share_preview_screen.dart` に `ArgumentError` のハンドリングがありません。\n'
              '\n'
              'VotingService.createSession() が ArgumentError を throw した場合、\n'
              'ユーザーに「名前が長すぎます（50文字以内）」などのメッセージを表示してください。',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ4: SECURITY.md — 解消済み Foursquare 記載の削除
  // ─────────────────────────────────────────────────────
  group('[LOW] SECURITY.md — 解消済み Foursquare APIキー記載の削除', () {
    test(
      'SECURITY.md に Foursquare APIキーのハードコードが「現在の既知リスク」として記載されていないとき '
      '対応済みのリスクが残存して混乱を招かない',
      () {
        final file = File('SECURITY.md');
        if (!file.existsSync()) {
          fail('SECURITY.md が存在しません。');
        }
        final content = file.readAsStringSync();

        // 「現在の既知リスク」セクションに Foursquare ハードコードの記載が残っていないことを確認。
        // キーのパターン（英大文字・数字 40文字以上）が掲載されていなければ削除済みとみなす。
        // ただし「推奨改善」セクションでの言及は許容する（別セクション）。
        final riskSection = _extractSection(content, '## 🔴 現在の既知リスク');
        // 40文字以上の英大文字・数字列（= APIキーのパターン）が既知リスクセクションに含まれるか
        final hasLiveApiKey =
            RegExp(r'[A-Z0-9]{40,}').hasMatch(riskSection);

        expect(
          hasLiveApiKey,
          isFalse,
          reason: '`SECURITY.md` の「現在の既知リスク」セクションに Foursquare APIキーの実値が残っています。\n'
              '\n'
              '問題: セキュリティドキュメントにAPIキーを掲載することは\n'
              '      それ自体が漏洩リスクです（GitHub等にプッシュ時に検出される）。\n'
              '\n'
              '前提確認: lib/config/api_config.dart のFoursquareキーが '
              'secrets.dart に移動済みであることを確認してから削除してください。\n'
              '\n'
              '修正内容:\n'
              '  1. api_config.dart のキーが secrets.dart（gitignore済み）に移動済みか確認\n'
              '  2. SECURITY.md の「### 1. Foursquare APIキーのハードコード」セクションを削除\n'
              '  3. 「推奨改善」リストの対応済み項目も更新',
        );
      },
    );

    test(
      'SECURITY.md の「現在の既知リスク」セクションが最新状態のとき '
      '対応済みのリスクが未対応として誤記録されていない',
      () {
        final file = File('SECURITY.md');
        if (!file.existsSync()) {
          fail('SECURITY.md が存在しません。');
        }
        final content = file.readAsStringSync();

        // 「現在の既知リスク」に Foursquare ハードコードの節が残っていないことを確認
        final riskSection = _extractSection(content, '## 🔴 現在の既知リスク');
        final hasOutdatedFoursquareSection =
            riskSection.contains('Foursquare APIキーのハードコード') &&
            riskSection.contains('lib/config/api_config.dart');

        expect(
          hasOutdatedFoursquareSection,
          isFalse,
          reason: '`SECURITY.md` の「現在の既知リスク」セクションに\n'
              '`Foursquare APIキーのハードコード` の記載が残っています。\n'
              '\n'
              'api_config.dart のキーが secrets.dart（gitignore済み）に移行済みであれば、\n'
              'このセクションを削除し「チェック実施記録」テーブルに対応完了を記録してください。\n'
              '\n'
              '該当セクション（先頭500文字）:\n'
              '${riskSection.substring(0, riskSection.length.clamp(0, 500))}',
        );
      },
    );
  });
}

// ─────────────────────────────────────────────────────
// ヘルパー
// ─────────────────────────────────────────────────────

/// ファイル内容から指定メソッド名付近の行を抽出する（デバッグ用）
String _extractLines(String content, String keyword) {
  final lines = content.split('\n');
  final idx = lines.indexWhere((l) => l.contains(keyword));
  if (idx < 0) return '（$keyword が見つかりません）';
  final start = (idx - 2).clamp(0, lines.length - 1);
  final end = (idx + 10).clamp(0, lines.length);
  return lines.sublist(start, end).join('\n');
}

/// Markdown ファイルから指定見出し以降のセクションを抽出する
String _extractSection(String content, String heading) {
  final idx = content.indexOf(heading);
  if (idx < 0) return '';
  final nextHeading = content.indexOf('\n## ', idx + heading.length);
  if (nextHeading < 0) return content.substring(idx);
  return content.substring(idx, nextHeading);
}
