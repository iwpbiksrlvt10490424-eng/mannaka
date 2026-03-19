// TDD Red フェーズ
// Cycle 7: voting_screen.dart:124 null-safe cast 修正のテスト
//
// 問題:
//   `(data['candidates'] as List)` は data['candidates'] が null のとき
//   TypeError でクラッシュする。Firestore ドキュメントが破損・未完成の場合に発生する。
//
// 違反箇所:
//   lib/screens/voting_screen.dart:124-126
//     final candidates = List<Map<String, dynamic>>.from(
//       (data['candidates'] as List).map((e) => Map<String, dynamic>.from(e as Map))
//     );
//
// 修正方針:
//   `data['candidates'] as List` を
//   `(data['candidates'] as List?) ?? []` に変更して null-safe にする。
//
// テスト戦略:
//   ソースコードを静的に検査し、unsafe cast パターンを検出する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `(data['candidates'] as List)` パターン（null-unsafe cast）を返す。
/// `(data['candidates'] as List?)` は安全なので対象外。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findUnsafeCandidatesCast(String filePath) {
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
      .where((e) {
        final line = e.value;
        // `as List)` で終わる cast（null-unsafe）を検出
        // `as List?)` または `as List<` は null-safe またはジェネリクス指定なので除外
        return line.contains("as List)") &&
            !line.contains("as List?)") &&
            !line.contains("as List<");
      })
      .map((e) => '行${e.key + 1}: ${e.value.trim()}')
      .toList();
}

void main() {
  group('クラッシュ防止 — voting_screen.dart null-safe candidates cast', () {
    test(
        'voting_screen.dart の candidates cast が null-safe なとき '
        'Firestore データ破損時にクラッシュしない',
        () {
      final violations =
          _findUnsafeCandidatesCast('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: '`data["candidates"] as List` は null のとき TypeError でクラッシュします。\n'
            '`(data["candidates"] as List?) ?? []` に変更してください。\n'
            '\n'
            '修正前:\n'
            '  final candidates = List<Map<String, dynamic>>.from(\n'
            '    (data["candidates"] as List).map(...)\n'
            '  );\n'
            '\n'
            '修正後:\n'
            '  final rawList = (data["candidates"] as List?) ?? [];\n'
            '  final candidates = List<Map<String, dynamic>>.from(\n'
            '    rawList.map((e) => Map<String, dynamic>.from(e as Map))\n'
            '  );\n'
            '\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
