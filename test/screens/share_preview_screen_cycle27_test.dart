// TDD Red フェーズ
// Cycle 27: share_preview_screen.dart — Share.share() に await を追加
//
// スコープ:
//   [🔴 WARNING] share_preview_screen.dart:394 — onPressed が async でない
//               → Share.share() の完了を待たずウィジェットが破棄される恐れがある
//   [🔴 WARNING] share_preview_screen.dart:401 — Share.share() に await がない
//               → iOS でシェアシートが完了前に呼び出し元が解放されクラッシュリスク
//
// CLAUDE.md 参照:
//   - 非同期後の context 使用前に `if (mounted)` を確認
//   - `Share.share()` on iOS は `sharePositionOrigin` 必須（既存で対応済み）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: シェアボタンの onPressed が async である
  // ─────────────────────────────────────────────────────
  group(
    '[WARNING] share_preview_screen — シェアボタン onPressed が async である',
    () {
      test(
        'onPressed が `() async {` のとき Share.share() が await できる',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          // onPressed: () { または onPressed: () async { を探す
          // Share.share を含むボタンコンテキストを見つける
          int shareShareLine = -1;
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('Share.share(')) {
              shareShareLine = i;
              break;
            }
          }

          expect(
            shareShareLine,
            greaterThan(-1),
            reason: 'Share.share() の呼び出しが見つかりません。',
          );

          // Share.share() より前の 20 行以内に onPressed を探す
          int onPressedLine = -1;
          for (var i = shareShareLine - 1;
              i >= 0 && i >= shareShareLine - 20;
              i--) {
            if (lines[i].contains('onPressed')) {
              onPressedLine = i;
              break;
            }
          }

          expect(
            onPressedLine,
            greaterThan(-1),
            reason: 'Share.share() の前に onPressed が見つかりません。',
          );

          final onPressedText = lines[onPressedLine];
          expect(
            onPressedText,
            contains('async'),
            reason:
                '`share_preview_screen.dart` の `onPressed` が `async` ではありません。\n'
                '\n'
                '問題: `Share.share()` は Future を返します。`async` なしの `onPressed` では\n'
                '      シェアシートの完了を待てず、iOS でウィジェットが破棄された後に\n'
                '      内部コールバックが実行されクラッシュする恐れがあります。\n'
                '\n'
                '修正（share_preview_screen.dart:394）:\n'
                '  // 修正前:\n'
                '  onPressed: () {\n'
                '  // 修正後:\n'
                '  onPressed: () async {\n'
                '\n'
                '違反箇所: 行${onPressedLine + 1}: ${onPressedText.trim()}',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ2: Share.share() が await されている
  // ─────────────────────────────────────────────────────
  group(
    '[WARNING] share_preview_screen — Share.share() が await されている',
    () {
      test(
        'Share.share() の呼び出し行に await があるとき iOS クラッシュリスクがない',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          final violations = <String>[];

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Share.share( を含む行で await がない場合を検出
            // コメント行は除外
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains('Share.share(') &&
                !line.contains('await Share.share(')) {
              violations.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            violations,
            isEmpty,
            reason:
                '`lib/screens/share_preview_screen.dart` に `await` なしの '
                '`Share.share()` 呼び出しがあります。\n'
                '\n'
                '問題: `await` なしだとシェアシートが完了する前に後続処理が走り、\n'
                '      iOS でウィジェットが破棄されたタイミングでコールバックが来て\n'
                '      クラッシュする恐れがあります。\n'
                '\n'
                '修正（share_preview_screen.dart:401）:\n'
                '  // 修正前:\n'
                '  Share.share(_buildShareText(state),\n'
                '      sharePositionOrigin: origin);\n'
                '  // 修正後:\n'
                '  await Share.share(_buildShareText(state),\n'
                '      sharePositionOrigin: origin);\n'
                '\n'
                '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ3: sharePositionOrigin が Share.share() に渡されている（回帰）
  // CLAUDE.md: Share.share() on iOS は sharePositionOrigin 必須
  // ─────────────────────────────────────────────────────
  group(
    '[REGRESSION] share_preview_screen — sharePositionOrigin が渡されている',
    () {
      test(
        'Share.share() 呼び出しブロックに sharePositionOrigin が含まれるとき iOS で IPad クラッシュしない',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final content = file.readAsStringSync();

          // Share.share( の呼び出し部分に sharePositionOrigin が存在するか
          // 正規表現: Share.share( から次の ) まで（複数行対応）
          final callPattern = RegExp(
            r'Share\.share\([^;]+sharePositionOrigin',
            dotAll: true,
          );

          expect(
            callPattern.hasMatch(content),
            isTrue,
            reason:
                '`Share.share()` の呼び出しに `sharePositionOrigin` が渡されていません。\n'
                'CLAUDE.md: `Share.share()` on iOS は `sharePositionOrigin` 必須\n'
                '\n'
                '修正後も sharePositionOrigin が維持されていることを確認してください。',
          );
        },
      );
    },
  );
}
