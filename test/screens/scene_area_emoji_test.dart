// TDD Red フェーズ
// scene_area_screen.dart 絵文字UIアイコン違反修正
//
// 問題:
//   CLAUDE.md:
//     1.「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」
//     2.「リストアイテムの leading に絵文字・アイコン禁止 — テキストのみ」
//
// 違反箇所:
//   lib/screens/scene_area_screen.dart L467-472
//     Text(
//       area.emoji,
//       style: const TextStyle(fontSize: 20),
//     ),
//     const SizedBox(width: 6),
//
//   _AreaCard.emoji フィールドはシェアテキスト（L411）でも使用されるため
//   フィールド自体は残し、build() 内の Text(area.emoji) 表示のみ削除する。
//
// 修正方針:
//   L467-472 の Text(area.emoji, ...) + SizedBox(width: 6) を削除
//   _AreaCard.emoji フィールドは Share.share() 用途で残す

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ファイル内の "Text(area.emoji" / "Text(\n...area.emoji" パターンを含む行を返す。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findEmojiTextWidgets(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail(
      '$filePath が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }

  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // パターン1: 同一行に Text(area.emoji がある
    if (line.contains('Text(area.emoji') || line.contains('Text( area.emoji')) {
      violations.add('行${i + 1}: ${line.trim()}');
      continue;
    }
    // パターン2: Text( の次の行に area.emoji がある（改行済みパターン）
    if (line.trim() == 'Text(' || line.trimRight().endsWith('Text(')) {
      if (i + 1 < lines.length && lines[i + 1].trim().startsWith('area.emoji')) {
        violations.add('行${i + 1}-${i + 2}: ${line.trim()} ${lines[i + 1].trim()}');
      }
    }
  }
  return violations;
}

/// build() メソッド内で area.emoji を参照している行を検出する。
/// Share.share() 内の参照は除外する（シェアテキスト用途は許容）。
List<String> _findEmojiUsageInBuild(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail('$filePath が存在しません');
  }

  final lines = file.readAsLinesSync();
  final violations = <String>[];
  var inBuild = false;
  var inShareMethod = false;
  var braceDepth = 0;
  var shareBraceStart = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // _share メソッドの開始を検出
    if (line.contains('_share(') && line.contains('async')) {
      inShareMethod = true;
      shareBraceStart = braceDepth;
    }

    // build メソッドの開始を検出
    if (RegExp(r'Widget\s+build\s*\(').hasMatch(line)) {
      inBuild = true;
    }

    // ブレース深度を追跡
    braceDepth += '{'.allMatches(line).length;
    braceDepth -= '}'.allMatches(line).length;

    // share メソッドの終了を検出
    if (inShareMethod && braceDepth <= shareBraceStart) {
      inShareMethod = false;
    }

    // build 内かつ share 外で area.emoji を参照している行を検出
    if (inBuild && !inShareMethod && !line.trim().startsWith('//')) {
      if (line.contains('area.emoji')) {
        violations.add('行${i + 1}: ${line.trim()}');
      }
    }
  }

  return violations;
}

void main() {
  const target = 'lib/screens/scene_area_screen.dart';

  group('UIデザインルール — scene_area_screen 絵文字アイコン禁止 (CLAUDE.md)', () {
    // ── テスト1: Text(area.emoji) パターン検出 ──
    test(
        'scene_area_screen.dart が Text(area.emoji を含まないとき '
        '絵文字UIアイコン禁止ルールに準拠する', () {
      final violations = _findEmojiTextWidgets(target);

      expect(
        violations,
        isEmpty,
        reason: 'CLAUDE.md:「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」\n'
            'Text(area.emoji, ...) を削除してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    // ── テスト2: build() 内での area.emoji 参照（share 除外）──
    test(
        'scene_area_screen.dart の build() 内で area.emoji をUI表示に使わないとき '
        'リストleading絵文字禁止ルールに準拠する', () {
      final violations = _findEmojiUsageInBuild(target);

      expect(
        violations,
        isEmpty,
        reason: 'CLAUDE.md:「リストアイテムの leading に絵文字・アイコン禁止 — テキストのみ」\n'
            'build() 内で area.emoji を参照しています（Share.share() 内は除外済み）。\n'
            'area.emoji の Text ウィジェット表示を削除してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    // ── テスト3: コメントの「絵文字 +」表記も削除確認 ──
    test(
        'scene_area_screen.dart のコード内コメントに絵文字表示の意図が残っていないとき '
        '修正が完了している', () {
      final file = File(target);
      if (!file.existsSync()) fail('$target が存在しません');

      final lines = file.readAsLinesSync();
      final violations = lines
          .asMap()
          .entries
          .where((e) =>
              e.value.trim().startsWith('//') &&
              e.value.contains('絵文字') &&
              (e.value.contains('エリア名') || e.value.contains('アイコン')))
          .map((e) => '行${e.key + 1}: ${e.value.trim()}')
          .toList();

      expect(
        violations,
        isEmpty,
        reason: '絵文字表示に関するコメントが残っています。\n'
            '「// 絵文字 + エリア名」などのコメントも削除してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
