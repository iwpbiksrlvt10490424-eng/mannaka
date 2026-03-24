// TDD Red フェーズ
// Cycle 28: share_preview_screen.dart — アバター '?' 禁止文字修正
//
// スコープ:
//   [WARNING] share_preview_screen.dart:298 — name が空のとき Text('?') を表示
//             → CLAUDE.md: UIテキストに「？」（全角・半角問わず）使用禁止
//             → 修正: Text('?') → Icon(Icons.person, size: 10, color: Colors.white)
//
// CLAUDE.md 参照:
//   - UIテキストに「？」（全角・半角問わず）使用禁止
//   - 絵文字をUIアイコンとして使用禁止 — Material Icons のみ

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: アバターに '?' が使われていない
  // ─────────────────────────────────────────────────────
  group(
    'WARNING share_preview_screen アバターの ? 使用禁止',
    () {
      test(
        'name が空のとき半角クエスチョンマークがUIテキストに使われていないとき禁止ルールに違反しない',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          // 半角 '?' を Text() の引数として渡している行を検出
          // パターン: コロンの後に '?' が文字列リテラルとして現れる行
          // 例: : '?', または : "?",
          final violations = <String>[];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // コメント行は除外
            if (line.trimLeft().startsWith('//')) continue;
            // '?' または "?" という文字列リテラルを検出（Text の引数として）
            // 具体的には : '?', や ? '?' のパターン
            final hasSingleQuoteQ = line.contains(": '?'") ||
                line.contains("? '?'") ||
                line.contains(": '?',") ||
                line.contains("'?'");
            if (hasSingleQuoteQ && line.contains("'?'")) {
              violations.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            violations,
            isEmpty,
            reason:
                'lib/screens/share_preview_screen.dart に'
                " Text('?') があります。\n"
                '\n'
                'CLAUDE.md: UIテキストに「？」（全角・半角問わず）使用禁止\n'
                '           疑問形は断言・体言止め・命令形に言い換える\n'
                '\n'
                '修正（share_preview_screen.dart:295-304）:\n'
                '  // 修正前:\n'
                "  child: Text(\n"
                "    name.isNotEmpty\n"
                "        ? name[0].toUpperCase()\n"
                "        : '?',\n"
                "    ...\n"
                "  ),\n"
                '  // 修正後:\n'
                '  child: name.isNotEmpty\n'
                '      ? Text(\n'
                '          name[0].toUpperCase(),\n'
                '          style: const TextStyle(\n'
                '            color: Colors.white,\n'
                '            fontSize: 10,\n'
                '            fontWeight: FontWeight.w700,\n'
                '          ),\n'
                '        )\n'
                '      : const Icon(Icons.person, size: 10, color: Colors.white),\n'
                '\n'
                '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ2: name が空のとき Icon(Icons.person) が使われている
  // ─────────────────────────────────────────────────────
  group(
    'WARNING share_preview_screen name 空時に Icons.person を使う',
    () {
      test(
        'name が空のとき Icons.person が使われているとき Material Icons ルールに準拠している',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final content = file.readAsStringSync();

          // Icons.person がファイル内に存在するか確認（フォーマット非依存）
          expect(
            content.contains('Icons.person'),
            isTrue,
            reason:
                'アバターコンテナ（青丸）に Icons.person が見つかりません。\n'
                '\n'
                'CLAUDE.md: 絵文字をUIアイコンとして使用禁止 — Material Icons のみ\n'
                '\n'
                'name が空のとき、Text("?") の代わりに\n'
                'const Icon(Icons.person, size: 10, color: Colors.white) を\n'
                'アバター（青丸コンテナ内）に配置してください。',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ3: 全角「？」も使われていない（回帰）
  // ─────────────────────────────────────────────────────
  group(
    'REGRESSION share_preview_screen 全角？も使用禁止',
    () {
      test(
        '全角？がUIテキストに含まれていないとき UIテキスト禁止ルールに違反しない',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          final fullWidthQ = '\uFF1F'; // ？ の Unicode
          final violations = <String>[];

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // コメント行は除外
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains(fullWidthQ)) {
              violations.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            violations,
            isEmpty,
            reason:
                'lib/screens/share_preview_screen.dart に'
                ' 全角「？」を含む行があります。\n'
                '\n'
                'CLAUDE.md: UIテキストに「？」（全角・半角問わず）使用禁止\n'
                '\n'
                '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
          );
        },
      );
    },
  );
}
