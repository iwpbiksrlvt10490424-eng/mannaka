// TDD Red フェーズ
// Cycle 21: _PhotoCarousel latent ColoredBox 修正 & settings_screen async gap 修正
//
// スコープ:
//   [🟡 LATENT] restaurant_detail_screen.dart — _PhotoCarousel placeholder が
//               Container(color:) を使用 → Flutter が内部で ColoredBox に変換
//               → design_rules_test が写真あり時に突然 Red になるリスク
//   [🟡 MEDIUM] settings_screen.dart — 「友達に教える」onTap で
//               MediaQuery.of(context) が await Share.share() の引数内で使用
//               → use_build_context_synchronously 潜在警告

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────
  // グループ1: _PhotoCarousel placeholder が Container(color:) を使わない
  // ─────────────────────────────────────────────────────
  group('[LATENT] _PhotoCarousel — placeholder に Container(color:) が含まれない', () {
    test(
      '_PhotoCarousel の placeholder で Container(color:) を使わないとき '
      'Flutter が内部 ColoredBox を生成せず design_rules_test が偽陽性にならない',
      () {
        final file = File('lib/screens/restaurant_detail_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/restaurant_detail_screen.dart が存在しません。');
        }
        final lines = file.readAsLinesSync();
        final violations = <String>[];

        // _PhotoCarouselState クラス内の Container(color: パターンを検出
        // （Container(color:) は Flutter が内部で ColoredBox に変換する）
        bool inCarousel = false;
        int depth = 0;

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('class _PhotoCarouselState')) {
            inCarousel = true;
          }
          if (!inCarousel) continue;

          depth += '{'.allMatches(line).length;
          depth -= '}'.allMatches(line).length;

          // Container(color: は Flutter 内部で ColoredBox に変換されるため禁止
          if (RegExp(r'Container\s*\(\s*color\s*:').hasMatch(line)) {
            violations.add('行${i + 1}: ${line.trim()}');
          }

          // クラスを抜けたら終了（depth が 0 以下 かつ 開始行より後）
          if (depth <= 0 && i > 0) break;
        }

        expect(
          violations,
          isEmpty,
          reason:
              '`_PhotoCarouselState` 内に `Container(color:)` があります。\n'
              '\n'
              '問題: Flutter は `Container(color: x)` を内部で `ColoredBox(color: x)` に\n'
              '      変換します。`design_rules_test` は ColoredBox の数を数えるため、\n'
              '      写真がある状態でテストを実行すると偽陽性（誤検知）が発生します。\n'
              '\n'
              '修正（restaurant_detail_screen.dart:514）:\n'
              '  // 修正前:\n'
              '  placeholder: (context, url) => Container(color: Colors.grey.shade100),\n'
              '  // 修正後（BoxDecoration 経由にすると ColoredBox に変換されない）:\n'
              '  placeholder: (context, url) => Container(\n'
              '    decoration: BoxDecoration(color: Colors.grey.shade100),\n'
              '  ),\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────
  // グループ2: settings_screen 「友達に教える」MediaQuery async gap 修正
  // ─────────────────────────────────────────────────────
  group(
      '[MEDIUM] settings_screen — 「友達に教える」MediaQuery が await 前に取得される',
      () {
    test(
      'settings_screen.dart の Share.share() 引数内に MediaQuery.of(context) がないとき '
      'use_build_context_synchronously 警告が出ない',
      () {
        final file = File('lib/screens/settings_screen.dart');
        if (!file.existsSync()) {
          fail('lib/screens/settings_screen.dart が存在しません。');
        }
        final lines = file.readAsLinesSync();
        final violations = <String>[];

        // await Share.share( の呼び出しブロックを収集し、
        // 引数内に MediaQuery.of(context) が含まれているか検出する
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains('await Share.share(')) continue;

          final buffer = StringBuffer();
          var depth = 0;
          var started = false;

          for (var j = i; j < lines.length && j < i + 30; j++) {
            final ln = lines[j];
            buffer.writeln(ln);
            for (var k = 0; k < ln.length; k++) {
              if (ln[k] == '(') {
                depth++;
                started = true;
              } else if (ln[k] == ')' && started) {
                depth--;
              }
            }
            if (started && depth <= 0) break;
          }

          if (buffer.toString().contains('MediaQuery.of(context)')) {
            violations.add('行${i + 1}: ${lines[i].trim()}');
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              '`lib/screens/settings_screen.dart` の `await Share.share()` 引数内に\n'
              '`MediaQuery.of(context)` が直接使われています。\n'
              '\n'
              '問題: `await` 式の引数リスト内に `context` アクセスがあると\n'
              '      `use_build_context_synchronously` 警告の対象になります。\n'
              '      ウィジェットが dispose された後に context にアクセスするリスクがあります。\n'
              '      CLAUDE.md: 非同期後の context 使用前に `if (mounted)` を確認\n'
              '\n'
              '修正（settings_screen.dart 「友達に教える」onTap）:\n'
              '  // 修正前:\n'
              '  onTap: () async {\n'
              "    await Share.share(\n"
              "      'text',\n"
              '      sharePositionOrigin: Rect.fromCenter(\n'
              '        center: Offset(\n'
              '          MediaQuery.of(context).size.width / 2,  // ← 違反\n'
              '          MediaQuery.of(context).size.height / 2, // ← 違反\n'
              '        ),\n'
              '      ),\n'
              '    );\n'
              '  },\n'
              '  // 修正後（await 前に size を取得）:\n'
              '  onTap: () async {\n'
              '    final size = MediaQuery.of(context).size;  // ← await より前\n'
              "    await Share.share(\n"
              "      'text',\n"
              '      sharePositionOrigin: Rect.fromCenter(\n'
              '        center: Offset(\n'
              '          size.width / 2,\n'
              '          size.height / 2,\n'
              '        ),\n'
              '      ),\n'
              '    );\n'
              '  },\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
        );
      },
    );
  });
}
