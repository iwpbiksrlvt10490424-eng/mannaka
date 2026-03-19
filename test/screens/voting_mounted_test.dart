// TDD Red フェーズ
// Cycle 5: voting_screen.dart の catch ブロック内 setState mounted チェック漏れ (Critic ISSUE-1/2)
// Cycle 6: 到達不能な if (mounted) 削除テスト追加
//
// 問題 (Cycle 5 - 修正済):
//   _vote() の catch ブロックで setState(() => _voting = false) が
//   mounted チェックなしに呼ばれていた（クラッシュリスク）。
//
// 問題 (Cycle 6 - 新規):
//   修正後の voting_screen.dart では catch ブロックが以下の構造になっている:
//     if (!mounted) return;    ← line 37: mounted チェック済み
//     setState(() => ...);     ← line 38: ここで既に mounted は true
//     if (mounted) { ... }     ← line 39: 到達不能（常に true）な冗長チェック
//
//   if (!mounted) return; の直後の if (mounted) は到達不能コード。
//   CLAUDE.md の「非同期コールバック内で context 使用前に if (mounted) を確認」に
//   反する冗長コードであり、削除すべき。
//
// 修正方針 (Cycle 6):
//   冗長な if (mounted) { ... } を削除し、中身を直接展開する。

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// catch ブロック内で mounted チェックなしに setState を呼んでいる箇所を返す。
/// 「直前の非空行に mounted が含まれない setState 行」を検出する。
List<String> _findUncheckedSetStateInCatch(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) fail('$filePath が存在しません');

  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // setState( を含み、かつ同行に mounted が含まれない行を対象とする
    if (!line.contains('setState(') || line.contains('mounted')) continue;

    // 直前の非空行を探す
    String prevNonEmpty = '';
    for (int j = i - 1; j >= math.max(0, i - 10); j--) {
      if (lines[j].trim().isNotEmpty) {
        prevNonEmpty = lines[j];
        break;
      }
    }

    // 直前の非空行に mounted チェック（if (!mounted) / if (mounted)）がない
    if (prevNonEmpty.contains('mounted')) continue;

    // 前10行以内に catch キーワードがあるか確認（catch ブロック内の setState を対象とする）
    final context = lines.sublist(math.max(0, i - 10), i);
    final isInCatch = context.any((l) => l.trim().startsWith('} catch'));
    if (!isInCatch) continue;

    violations.add('行${i + 1}: ${line.trim()}');
  }

  return violations;
}

/// `if (!mounted) return` の後に `if (mounted)` が続く（到達不能な冗長チェック）を返す。
/// `if (!mounted) return` が存在すれば、その後の `if (mounted)` は常に true のため不要。
List<String> _findRedundantMountedCheck(String filePath) {
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
    final trimmed = lines[i].trim();

    // `if (mounted)` で始まる行を対象とする（`if (!mounted)` は除外）
    if (!trimmed.startsWith('if (mounted)')) continue;

    // 前10行以内に `if (!mounted) return` があれば冗長チェックと判定
    final start = math.max(0, i - 10);
    final preceding = lines.sublist(start, i);
    if (preceding.any((l) => l.contains('if (!mounted) return'))) {
      violations.add('行${i + 1}: ${lines[i].trim()}');
    }
  }

  return violations;
}

/// _vote() の try 成功パスで、await の後に mounted チェックなしで
/// setState を呼んでいる箇所を返す。
///
/// 検出パターン:
///   try {
///     await SomeService.call(...);
///     setState(() { ... });   ← mounted チェックなし！ ← ここを検出
///   } catch ...
///
/// 修正後の期待パターン:
///   try {
///     await SomeService.call(...);
///     if (!mounted) return;   ← 追加
///     setState(() { ... });
///   } catch ...
List<String> _findUncheckedSetStateInTry(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) fail('$filePath が存在しません');

  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // setState( を含み、同行に mounted が含まれない行を対象とする
    if (!line.contains('setState(') || line.contains('mounted')) continue;

    // 直前の非空行を探す
    String prevNonEmpty = '';
    for (int j = i - 1; j >= math.max(0, i - 10); j--) {
      if (lines[j].trim().isNotEmpty) {
        prevNonEmpty = lines[j];
        break;
      }
    }

    // 直前の非空行に mounted チェックがあれば OK（catch ブロックと try ブロック共通）
    if (prevNonEmpty.contains('mounted')) continue;

    // 前15行以内に await が存在するか確認（非同期コール後の setState か）
    final start = math.max(0, i - 15);
    final preceding = lines.sublist(start, i);
    final hasAwait = preceding.any((l) => l.trimLeft().startsWith('await '));
    if (!hasAwait) continue;

    // catch ブロック内でないことを確認（try 成功パスを対象とする）
    // catch ブロック内は既存テストが担当するため除外
    final isInCatch = preceding.any((l) => l.trim().startsWith('} catch'));
    if (isInCatch) continue;

    // try ブロック内であることを確認（try { が前20行以内に存在）
    final widerStart = math.max(0, i - 20);
    final widerPreceding = lines.sublist(widerStart, i);
    final isInTry = widerPreceding.any(
      (l) => l.trim() == 'try {' || l.trim().endsWith('try {'),
    );
    if (!isInTry) continue;

    violations.add('行${i + 1}: ${line.trim()}');
  }

  return violations;
}

void main() {
  group('クラッシュ防止 — 非同期 catch ブロック内 setState mounted チェック', () {
    test(
        'voting_screen.dart の catch ブロック内の setState が mounted チェック後にあるとき '
        'クラッシュしない',
        () {
      final violations =
          _findUncheckedSetStateInCatch('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'catch ブロック内の setState の前に if (!mounted) return; が必要です。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '修正例:\n'
            '  } catch (e) {\n'
            '    debugPrint(...);\n'
            '    if (!mounted) return;   ← 追加\n'
            '    setState(() => _voting = false);\n'
            '  }',
      );
    });

    test(
        'voting_screen.dart の _vote() try 成功パスで await 後の setState が '
        'mounted チェック後にあるときウィジェット破棄後のクラッシュが防止される',
        () {
      final violations =
          _findUncheckedSetStateInTry('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: '_vote() の try ブロック内で await の後に setState を呼ぶ前に\n'
            '`if (!mounted) return;` が必要です。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            '  try {\n'
            '    await VotingService.vote(...);\n'
            '    if (!mounted) return;   ← 追加\n'
            '    setState(() {\n'
            '      _votedFor = restaurantId;\n'
            '      _voting = false;\n'
            '    });\n'
            '  } catch (e) { ... }',
      );
    });

    test(
        'voting_screen.dart に到達不能な if (mounted) が含まれないとき '
        'コードが冗長でない',
        () {
      final violations =
          _findRedundantMountedCheck('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: '`if (!mounted) return` の直後の `if (mounted)` は到達不能コードです。\n'
            'この時点で mounted は必ず true であるため、if ガードを削除してください。\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '修正前:\n'
            '  if (!mounted) return;\n'
            '  setState(() => _voting = false);\n'
            '  if (mounted) {   ← 削除\n'
            '    ScaffoldMessenger...showSnackBar(...);\n'
            '  }               ← 削除\n'
            '修正後:\n'
            '  if (!mounted) return;\n'
            '  setState(() => _voting = false);\n'
            '  ScaffoldMessenger.of(context).showSnackBar(...);',
      );
    });
  });
}
