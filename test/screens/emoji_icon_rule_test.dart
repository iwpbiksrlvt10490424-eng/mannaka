// TDD Red フェーズ
// Cycle 5: 絵文字 Text ウィジェット残存 (Critic 参考)
// Cycle 6: リテラル絵文字検出の偽グリーン修正
//
// 問題:
//   CLAUDE.md: 「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」
//   以下のファイルで r.emoji を Text ウィジェットに渡してアイコン代わりに使っている。
//
// Cycle 5 違反箇所（修正済）:
//   lib/widgets/restaurant_map.dart:424   child: Text(r.emoji, ...)
//   lib/screens/share_preview_screen.dart:162  Text(r.emoji, ...)
//
// Cycle 6 追加違反箇所（リテラル絵文字）:
//   lib/widgets/restaurant_map.dart:142  Text('📍', ...)  重心マーカー
//   lib/widgets/restaurant_map.dart:236  Text('📍', ...)  凡例
//   lib/widgets/restaurant_map.dart:259  Text('🍴', ...)  凡例
//   lib/widgets/restaurant_map.dart:399-403  '🥇'/'🥈'/'🥉'  順位表示
//
// 修正方針:
//   Text(r.emoji, ...) → Icon(Icons.restaurant_rounded, size: 20)
//   Text('📍', ...)    → Icon(Icons.place_rounded, size: 20)
//   Text('🍴', ...)    → Icon(Icons.restaurant_rounded, size: 20)
//   '🥇'/'🥈'/'🥉'    → 数字テキスト ('1'/'2'/'3') または Icon
//
// 偽グリーン修正:
//   旧検出: Text(r.emoji のみ → リテラル絵文字を見逃していた
//   新検出: Text(r.emoji + Unicode絵文字文字を含むソース行も検出

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ファイル内の "Text(r.emoji" パターンを含む行を返す。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findEmojiTextWidgets(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) fail('$filePath が存在しません');

  return file
      .readAsLinesSync()
      .asMap()
      .entries
      .where((e) =>
          e.value.contains('Text(r.emoji') ||
          e.value.contains('Text( r.emoji'))
      .map((e) => '行${e.key + 1}: ${e.value.trim()}')
      .toList();
}

/// 行にリテラル絵文字 Unicode 文字が含まれるか判定する。
/// コメント行（// で始まる行）は除外する。
/// 検出対象の Unicode ブロック:
///   U+1F000-U+1FAFF  General emoji (symbols, pictographs, medals, etc.)
///   U+2600-U+26FF    Miscellaneous Symbols
bool _hasLiteralEmoji(String line) {
  if (line.trim().startsWith('//')) return false;
  return line.runes.any((r) =>
      (r >= 0x1F000 && r <= 0x1FAFF) ||
      (r >= 0x2600 && r <= 0x26FF));
}

/// ファイル内にリテラル絵文字文字を含むコード行を返す。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findLiteralEmojiLines(String filePath) {
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
      .where((e) => _hasLiteralEmoji(e.value))
      .map((e) => '行${e.key + 1}: ${e.value.trim()}')
      .toList();
}

void main() {
  group('UIデザインルール — 絵文字アイコン禁止 (CLAUDE.md)', () {
    // ── Cycle 5: r.emoji パターン ──────────────────────────────────────────
    test(
        'restaurant_map.dart が Text(r.emoji を含まないとき '
        '絵文字アイコン禁止ルールに準拠する',
        () {
      final violations =
          _findEmojiTextWidgets('lib/widgets/restaurant_map.dart');

      expect(
        violations,
        isEmpty,
        reason: '絵文字を Text ウィジェットでアイコンとして使用しています。\n'
            'Icon(Icons.restaurant_rounded, size: 20) に置き換えてください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'share_preview_screen.dart が Text(r.emoji を含まないとき '
        '絵文字アイコン禁止ルールに準拠する',
        () {
      final violations =
          _findEmojiTextWidgets('lib/screens/share_preview_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: '絵文字を Text ウィジェットでアイコンとして使用しています。\n'
            'Icon(Icons.restaurant_rounded, size: 20) に置き換えてください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    // ── Cycle 6: リテラル絵文字パターン（偽グリーン修正） ──────────────────
    test(
        'restaurant_map.dart がリテラル絵文字文字を含まないとき '
        '絵文字アイコン禁止ルールに準拠する',
        () {
      final violations =
          _findLiteralEmojiLines('lib/widgets/restaurant_map.dart');

      expect(
        violations,
        isEmpty,
        reason: 'ソース内にリテラル絵文字文字が含まれています。Material Icons に置き換えてください。\n'
            '  📍 → Icon(Icons.place_rounded, size: 20)\n'
            '  🍴 → Icon(Icons.restaurant_rounded, size: 20)\n'
            '  🥇/🥈/🥉 → 数字テキスト (\'1\'/\'2\'/\'3\') または Icon(Icons.emoji_events_rounded)\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
