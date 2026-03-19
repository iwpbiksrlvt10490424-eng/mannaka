// TDD Red フェーズ
// Cycle 6: 疑似Divider (SizedBox height:1 + ColoredBox) 禁止テスト
// Cycle 7: voting_screen.dart を検査対象に追加（偽グリーン解消）
//
// CLAUDE.md: 「Divider 禁止 — SizedBox 8-10px で区切る」
//
// 違反箇所:
//   lib/widgets/restaurant_map.dart:364
//     const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
//   lib/screens/share_preview_screen.dart:228
//     const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
//   lib/screens/voting_screen.dart:110-111 (Cycle 7 追加)
//     const SizedBox(height: 1, child: ColoredBox(color: Color(0xFFEEEEEE))),
//
// 修正方針:
//   上記3箇所の SizedBox(height: 1, child: ColoredBox(...)) を
//   SizedBox(height: 8) または SizedBox(height: 10) に置き換える。
//
// 注意: restaurant_detail_screen.dart の疑似Divider は
//   design_rules_test.dart のウィジェットテストでカバー済み。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `SizedBox(height: 1` かつ `ColoredBox` を含む行（疑似Divider）を返す。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findPseudoDividerLines(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail(
      '$filePath が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }
  return file
      .readAsLinesSync()
      .asMap()
      .entries
      .where((e) =>
          e.value.contains('height: 1') && e.value.contains('ColoredBox'))
      .map((e) => '行${e.key + 1}: ${e.value.trim()}')
      .toList();
}

void main() {
  group('デザインルール — 疑似Divider禁止 ソース検査 (CLAUDE.md)', () {
    test(
        'voting_screen.dart が SizedBox(height:1)+ColoredBox を含まないとき '
        'Divider禁止ルールに準拠する',
        () {
      final violations =
          _findPseudoDividerLines('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'SizedBox(height: 1, child: ColoredBox(...)) は疑似Dividerです。\n'
            'SizedBox(height: 8) 以上の余白に置き換えてください。\n'
            '対象箇所: AppBar の bottom: PreferredSize 内 (voting_screen.dart:110-111)\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'restaurant_map.dart が SizedBox(height:1)+ColoredBox を含まないとき '
        'Divider禁止ルールに準拠する',
        () {
      final violations =
          _findPseudoDividerLines('lib/widgets/restaurant_map.dart');

      expect(
        violations,
        isEmpty,
        reason: 'SizedBox(height: 1, child: ColoredBox(...)) は疑似Dividerです。\n'
            'SizedBox(height: 8) 以上の余白に置き換えてください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'share_preview_screen.dart が SizedBox(height:1)+ColoredBox を含まないとき '
        'Divider禁止ルールに準拠する',
        () {
      final violations =
          _findPseudoDividerLines('lib/screens/share_preview_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'SizedBox(height: 1, child: ColoredBox(...)) は疑似Dividerです。\n'
            'SizedBox(height: 8) 以上の余白に置き換えてください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
