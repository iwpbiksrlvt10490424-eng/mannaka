// TDD Red フェーズ
// Cycle 18: Cycle17 残件修正テスト
//
// スコープ:
//   [🔴 HIGH]    search_screen.dart:1145 — Share.share() 直後に if (!mounted) return; が不足
//                → dispose後に setState() が呼ばれクラッシュする
//   [🔴 HIGH]    voting_security_cycle16_test.dart — APIキー実値 RB4P... が6箇所残存
//                → テストファイル自体がキー漏洩の媒体になっている
//   [🟡 MEDIUM]  search_screen.dart:1130 — Firestoreエラー詳細が $e でUIに露出
//                → 内部エラー情報がユーザーに表示される

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: HIGH — search_screen Share.share() 直後の mounted チェック
  // ─────────────────────────────────────────────────────
  group('[HIGH] search_screen — Share.share() 直後に mounted チェックがある', () {
    test(
      'Share.share() の直後に if (!mounted) return; があるとき '
      'ダイアログ表示中に画面が破棄されても setState でクラッシュしない',
      () {
        final file = File('lib/screens/search_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/search_screen.dart が存在しません。');
        }
        final lines = file.readAsLinesSync();

        // Share.share() を await している行を探す
        final shareShareIdx = lines.indexWhere(
          (l) => l.contains('await Share.share(') && l.contains('sharePositionOrigin'),
        );
        expect(
          shareShareIdx,
          isNot(-1),
          reason: '`await Share.share(` の行が見つかりません。\n'
              '`lib/screens/search_screen.dart` に `await Share.share(shareText, sharePositionOrigin:` '
              'が存在することを確認してください。',
        );

        // Share.share() の直後から setState(_waitingForLocation) の前までに
        // if (!mounted) return; があることを確認
        final setStateIdx = lines.indexWhere(
          (l) => l.contains('setState') && l.contains('_waitingForLocation'),
          shareShareIdx + 1,
        );
        expect(
          setStateIdx,
          isNot(-1),
          reason: '`setState(() => _waitingForLocation` の行が '
              '`await Share.share(` より後で見つかりません。\n'
              'ロジックが変更された可能性があります。',
        );

        final betweenLines = lines.sublist(shareShareIdx + 1, setStateIdx);
        final hasMountedCheck = betweenLines.any(
          (l) => l.trim().startsWith('if (!mounted)') || l.trim() == 'if (!mounted) return;',
        );

        expect(
          hasMountedCheck,
          isTrue,
          reason:
              '`await Share.share(...)` の直後（setState の前）に\n'
              '`if (!mounted) return;` がありません。\n'
              '\n'
              '問題: Share.share() は OS のシェアシートを開く非同期処理で、\n'
              '      ユーザーが画面を戻ってウィジェットが dispose された後に\n'
              '      完了する可能性があります。\n'
              '      その場合 setState() を呼ぶと FlutterError が発生します。\n'
              '\n'
              '修正（search_screen.dart の await Share.share() の直後）:\n'
              '  await Share.share(shareText, sharePositionOrigin: shareOrigin);\n'
              '\n'
              '  if (!mounted) return;   // ← 追加\n'
              '\n'
              '  // Start watching for location\n'
              '  setState(() => _waitingForLocation = true);\n',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: MEDIUM — search_screen Firestoreエラー詳細のUI露出
  // ─────────────────────────────────────────────────────
  group('[MEDIUM] search_screen — SnackBar に Firestoreエラー詳細が露出しない', () {
    test(
      'SnackBar のエラーメッセージが固定文字列のとき '
      'Firestore の PERMISSION_DENIED 等のエラー詳細がユーザーに表示されない',
      () {
        final file = File('lib/screens/search_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/search_screen.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // より確実な検出: $e が文字列補間として使われているパターンを全文検索
        // Dart ソースの $e は実際には $ + e という文字の連続
        final hasRawExceptionInText =
            content.contains("失敗しました: \$e") ||
            content.contains(r"失敗しました: $e") ||
            RegExp(r"Text\('[^']*\$e[^{a-zA-Z_]").hasMatch(content) ||
            RegExp(r'Text\("[^"]*\$e[^{a-zA-Z_]').hasMatch(content);

        expect(
          hasRawExceptionInText,
          isFalse,
          reason:
              '`lib/screens/search_screen.dart` の Text() ウィジェットに\n'
              '例外の実内容 `\$e` が直接埋め込まれています。\n'
              '\n'
              '問題: `\$e` を Text() に渡すと、Firestore の `PERMISSION_DENIED` や\n'
              '      スタックトレースなどの内部エラー情報がユーザーに表示されます。\n'
              '      セキュリティ上の情報漏洩リスクがあります。\n'
              '\n'
              '違反箇所（約 line 1131）:\n'
              "  content: Text('リンクの作成に失敗しました: \$e'),\n"
              '\n'
              '修正（search_screen.dart の catch 節）:\n'
              '  // 修正前:\n'
              "  content: Text('リンクの作成に失敗しました: \$e'),\n"
              '\n'
              '  // 修正後（固定文言）:\n'
              "  content: Text('リンクの作成に失敗しました。もう一度お試しください。'),\n",
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ3: HIGH — voting_security_cycle16_test APIキー実値除去
  // ─────────────────────────────────────────────────────
  group('[HIGH] voting_security_cycle16_test — APIキー実値が除去されている', () {
    test(
      'voting_security_cycle16_test.dart に Foursquare APIキーの実値が含まれないとき '
      'テストファイル自体がキー漏洩の媒体にならない',
      () {
        final file = File('test/security/voting_security_cycle16_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle16_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // cycle16_test.dart は cycle15_test の APIキー除去を確認するテストファイルだが、
        // そのテスト自体が `reason:` や `//` コメント内に実キーを埋め込んでいる。
        // → テストファイルを git にコミットすると実キーが公開される。
        //
        // 違反箇所（合計6箇所）:
        //   Line 208: //     'RB4P...',
        //   Line 216: content.contains('RB4P...')
        //   Line 222: 'Foursquare APIキーの実値 `RB4P...`'
        //   Line 231: "    'RB4P...',"
        //   Line 252: //     'RB4P...',
        //   Line 277: "    'RB4P...',"
        //
        // 修正: 全箇所を `RB4P...` のようなプレースホルダーか
        //       `RegExp(r'[A-Z0-9]{40,}').hasMatch(content)` 形式に置換する。
        final apiKeyPattern = RegExp(r'[A-Z0-9]{40,}');
        final occurrences = apiKeyPattern.allMatches(content).length;

        expect(
          occurrences,
          0,
          reason:
              '`test/security/voting_security_cycle16_test.dart` に\n'
              'Foursquare APIキーの実値が $occurrences 箇所残っています。\n'
              '\n'
              '問題: テストファイルが git にプッシュされると APIキーが公開されます。\n'
              '      セキュリティチェックのためにキーを書いても本末転倒です。\n'
              '\n'
              '修正例（全箇所の実値を置換）:\n'
              '  // コメント内:\n'
              "  //     'RB4P...',           // ← プレースホルダーに置換\n"
              '\n'
              '  // contains() チェック:\n'
              "  // 修正前: content.contains('RB4P...')\n"
              "  // 修正後: RegExp(r'[A-Z0-9]{40,}').hasMatch(content)\n"
              '\n'
              '  // reason: 文字列内:\n'
              "  // 修正前: 'APIキーの実値 `RB4P...`'\n"
              "  // 修正後: 'APIキーの実値 `RB4P...` （40文字以上の英大文字英数字列）'\n",
        );
      },
    );

    test(
      'voting_security_cycle16_test.dart の APIキー検出ロジックが RegExp で実装されているとき '
      '実値を持たずにキー形式を検出できる',
      () {
        final file = File('test/security/voting_security_cycle16_test.dart');
        if (!file.existsSync()) {
          fail('test/security/voting_security_cycle16_test.dart が存在しません。');
        }
        final content = file.readAsStringSync();

        // content.contains('RB4P...') を RegExp パターンに置換したとき、
        // hasHardcodedKey 変数が RegExp で初期化されていることを確認。
        // ※ reason: 文字列内にも RegExp の例が書かれているが、
        //    変数宣言 `final hasHardcodedKey = RegExp` というパターンで
        //    実コードの置換を区別する。
        final hasRegExpAssignment =
            content.contains('final hasHardcodedKey = RegExp');

        expect(
          hasRegExpAssignment,
          isTrue,
          reason:
              '`voting_security_cycle16_test.dart` の APIキー検出ロジックが\n'
              '`RegExp` を使ったパターンマッチに置換されていません。\n'
              '\n'
              '修正例:\n'
              '  // 修正前:\n'
              "  final hasHardcodedKey = content.contains('RB4P...');\n"
              '\n'
              '  // 修正後:\n'
              "  final hasHardcodedKey = RegExp(r'[A-Z0-9]{40,}').hasMatch(content);\n",
        );
      },
    );
  });
}

