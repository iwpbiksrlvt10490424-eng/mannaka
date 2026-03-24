// TDD Red フェーズ
// Cycle 29: share_preview_screen.dart — テスト設計修正（フォーマット非依存化）
//
// スコープ:
//   [ISSUE] share_preview_screen_cycle28_test.dart Group 2
//           regex `r'0xFF3B82F6[\s\S]{0,400}Icons\.person'` が
//           dart format 実行後に 400 字制限を超えてテスト破壊される
//           → Icons.person 単独チェックに書き直す
//   [IMPROVEMENT] share_preview_screen.dart:295
//           1行圧縮コードを dart format スタイルに展開する
//
// CLAUDE.md 参照:
//   - UIテキストに「？」（全角・半角問わず）使用禁止
//   - 絵文字をUIアイコンとして使用禁止 — Material Icons のみ

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: アバターに '?' が使われていない（Cycle 28 回帰）
  // ─────────────────────────────────────────────────────
  group(
    'REGRESSION share_preview_screen アバターの ? 使用禁止',
    () {
      test(
        'name が空のとき Text に半角クエスチョンマークが使われていないとき禁止ルールに違反しない',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          final violations = <String>[];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains("'?'")) {
              violations.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            violations,
            isEmpty,
            reason: 'lib/screens/share_preview_screen.dart に'
                " Text('?') があります。\n"
                '\n'
                'CLAUDE.md: UIテキストに「？」（全角・半角問わず）使用禁止\n'
                '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ2: Icons.person が存在する（フォーマット非依存チェック）
  // Cycle 28 Group 2 の 400 字距離 regex を廃止してシンプルな存在確認に置き換え
  // ─────────────────────────────────────────────────────
  group(
    'WARNING share_preview_screen name 空時に Icons.person を使う（フォーマット非依存）',
    () {
      test(
        'Icons.person がファイル内に存在するとき Material Icons ルールに準拠している',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final content = file.readAsStringSync();

          expect(
            content.contains('Icons.person'),
            isTrue,
            reason: 'アバターコンテナに Icons.person が見つかりません。\n'
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
  // グループ3: dart format スタイル準拠（1行圧縮禁止）
  // Red: 現在の実装は name.isNotEmpty と Icons.person が同一行に圧縮されているため失敗する
  // Green: dart format で展開すると別行になりテストが通る
  // ─────────────────────────────────────────────────────
  group(
    'IMPROVEMENT share_preview_screen アバター child が dart format スタイルに準拠',
    () {
      test(
        'name.isNotEmpty の三項演算子と Icons.person が同一行に存在しないとき dart format スタイルに準拠している',
        () {
          final file = File('lib/screens/share_preview_screen.dart');
          if (!file.existsSync()) {
            fail('lib/screens/share_preview_screen.dart が存在しません。');
          }
          final lines = file.readAsLinesSync();

          // 1行に name.isNotEmpty と Icons.person が両方含まれる行を検出する
          // このパターンは dart format 未適用の圧縮コードを示す
          final compressedLines = <String>[];
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains('name.isNotEmpty') &&
                line.contains('Icons.person')) {
              compressedLines.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            compressedLines,
            isEmpty,
            reason: 'アバターの child が1行に圧縮されています。dart format スタイルに展開してください。\n'
                '\n'
                '修正前（圧縮 — このパターンが検出されています）:\n'
                '  child: name.isNotEmpty ? Text(name[0].toUpperCase(), style: const TextStyle(...)) : const Icon(Icons.person, ...),\n'
                '\n'
                '修正後（dart format スタイル）:\n'
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
                '圧縮されている行:\n${compressedLines.map((l) => '  $l').join('\n')}',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ4a: cycle28 テストファイルの fragile regex が修正済み（Red）
  // Red: cycle28_test.dart にまだ {0,400} 距離制約が残っているため失敗する
  // Green: Engineer が {0,400} を除去すると通る
  // ─────────────────────────────────────────────────────
  group(
    'CYCLE29 cycle28テストの距離制約 regex が除去されている',
    () {
      test(
        'cycle28テストに {0,400} 距離制約が含まれていないとき dart format 実行後も壊れない',
        () {
          final file = File(
            'test/screens/share_preview_screen_cycle28_test.dart',
          );
          if (!file.existsSync()) {
            // cycle28 テストが存在しない場合はスキップ（削除済みも可）
            return;
          }
          final content = file.readAsStringSync();

          // {0,400} という文字距離制約が残っていないことを確認
          expect(
            content.contains('{0,400}'),
            isFalse,
            reason:
                'test/screens/share_preview_screen_cycle28_test.dart に\n'
                '文字距離制約 {0,400} が残っています。\n'
                '\n'
                '修正前:\n'
                "  final avatarWithPersonIcon = RegExp(\n"
                "    r'0xFF3B82F6[\\s\\S]{0,400}Icons\\.person',\n"
                "    dotAll: true,\n"
                "  );\n"
                '\n'
                '修正後:\n'
                "  expect(\n"
                "    content.contains('Icons.person'),\n"
                "    isTrue,\n"
                "  );\n"
                '\n'
                'dart format 実行で実装コードの行数が変わると\n'
                '400 字制限を超えてテストが即壊れます。',
          );
        },
      );
    },
  );

  // ─────────────────────────────────────────────────────
  // グループ4: 全角「？」も使われていない（回帰）
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
            if (line.trimLeft().startsWith('//')) continue;
            if (line.contains(fullWidthQ)) {
              violations.add('行${i + 1}: ${line.trim()}');
            }
          }

          expect(
            violations,
            isEmpty,
            reason: 'lib/screens/share_preview_screen.dart に'
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
