// TDD Red フェーズ
// meeting_point_card.dart 絵文字UIアイコン違反修正
//
// 問題:
//   CLAUDE.md:
//     1.「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」
//
// 違反箇所:
//   lib/widgets/meeting_point_card.dart L72
//     ExcludeSemantics(child: Text(point.stationEmoji, style: const TextStyle(fontSize: 26)))
//
// 修正方針:
//   L72 の Text(point.stationEmoji, ...) を Icon(Icons.train_rounded, ...) に置換
//   stationEmoji フィールドはモデルに残す（他で使用される可能性）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// meeting_point_card.dart 内で Text(point.stationEmoji パターンを検出する。
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
    // パターン1: 同一行に Text(point.stationEmoji がある
    if (line.contains('Text(point.stationEmoji') ||
        line.contains('Text( point.stationEmoji')) {
      violations.add('行${i + 1}: ${line.trim()}');
      continue;
    }
    // パターン2: Text( の次の行に point.stationEmoji がある
    if (line.trim() == 'Text(' || line.trimRight().endsWith('Text(')) {
      if (i + 1 < lines.length &&
          lines[i + 1].trim().startsWith('point.stationEmoji')) {
        violations.add(
            '行${i + 1}-${i + 2}: ${line.trim()} ${lines[i + 1].trim()}');
      }
    }
  }
  return violations;
}

/// build() メソッド内で point.stationEmoji を参照している行を検出する。
List<String> _findStationEmojiInBuild(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail('$filePath が存在しません');
  }

  final lines = file.readAsLinesSync();
  final violations = <String>[];
  var inBuild = false;
  var braceDepth = 0;
  var buildBraceStart = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // build メソッドの開始を検出
    if (RegExp(r'Widget\s+build\s*\(').hasMatch(line)) {
      inBuild = true;
      buildBraceStart = braceDepth;
    }

    // ブレース深度を追跡
    braceDepth += '{'.allMatches(line).length;
    braceDepth -= '}'.allMatches(line).length;

    // build メソッドの終了を検出
    if (inBuild && braceDepth <= buildBraceStart && i > 0) {
      // build の次の } でリセット（最初の行は除く）
      if (line.trim() == '}') {
        inBuild = false;
      }
    }

    // build 内でコメント行を除外して stationEmoji の参照を検出
    if (inBuild && !line.trim().startsWith('//')) {
      if (line.contains('point.stationEmoji') ||
          line.contains('.stationEmoji')) {
        violations.add('行${i + 1}: ${line.trim()}');
      }
    }
  }

  return violations;
}

void main() {
  const target = 'lib/widgets/meeting_point_card.dart';

  group('UIデザインルール — meeting_point_card 絵文字アイコン禁止 (CLAUDE.md)', () {
    // ── テスト1: Text(point.stationEmoji) パターン検出 ──
    test(
        'meeting_point_card.dart が Text(point.stationEmoji を含まないとき '
        '絵文字UIアイコン禁止ルールに準拠する', () {
      final violations = _findEmojiTextWidgets(target);

      expect(
        violations,
        isEmpty,
        reason:
            'CLAUDE.md:「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」\n'
            'Text(point.stationEmoji, ...) を Icon(Icons.train_rounded) 等に置換してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    // ── テスト2: build() 内での stationEmoji 参照 ──
    test(
        'meeting_point_card.dart の build() 内で stationEmoji をUI表示に使わないとき '
        '絵文字アイコン禁止ルールに準拠する', () {
      final violations = _findStationEmojiInBuild(target);

      expect(
        violations,
        isEmpty,
        reason:
            'CLAUDE.md:「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」\n'
            'build() 内で stationEmoji を参照しています。\n'
            '絵文字テキスト表示を Material Icon に置換してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    // ── テスト3: Material Icon が使われていることを確認 ──
    test(
        'meeting_point_card.dart の駅アイコン部分に Icon ウィジェットが使われているとき '
        'Material Icons ルールに準拠する', () {
      final file = File(target);
      if (!file.existsSync()) fail('$target が存在しません');

      final content = file.readAsStringSync();

      // Rank badge の隣（SizedBox(width: 10) の後）に Icon ウィジェットが存在すること
      // 現状は Text(point.stationEmoji) なので、このテストは失敗する
      final hasTrainIcon = content.contains('Icons.train') ||
          content.contains('Icons.directions_train') ||
          content.contains('Icons.subway') ||
          content.contains('Icons.commute');

      expect(
        hasTrainIcon,
        isTrue,
        reason:
            'CLAUDE.md:「絵文字をUIアイコンとして使用禁止 — Material Icons のみ」\n'
            '駅を示すアイコンとして Material Icons（Icons.train_rounded 等）を使用してください。\n'
            '現在は Text(point.stationEmoji) が使われています。',
      );
    });
  });
}
