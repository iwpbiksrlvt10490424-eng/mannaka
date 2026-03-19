// TDD Red フェーズ
// Cycle 4: debugPrint 生例外ログ禁止のテスト (Security ISSUE-1)
// Cycle 5: 偽グリーン修正 + analytics_service.dart 検証追加
// Cycle 6: ranking_screen.dart 追加
//
// 問題:
//   debugPrint('... - $e') は Exception.toString() を丸ごとログに出力する。
//   スタックトレースや内部情報が漏洩する恐れがある。
//
// 修正方針:
//   $e → ${e.runtimeType}  （型名のみ。スタックトレース非公開）
//
// 違反箇所（Cycle 5 時点）:
//   lib/services/analytics_service.dart — 8 箇所（全メソッドの catch 節）
//
// 違反箇所（Cycle 6 追加）:
//   lib/screens/ranking_screen.dart:413
//     debugPrint('ShareCard error: $e')
//
// 偽グリーン修正:
//   旧実装: if (!file.existsSync()) return [];  ← ファイル非存在でも PASS（偽グリーン）
//   新実装: if (!file.existsSync()) fail(...)   ← ファイル非存在は即 FAIL

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `debugPrint(...)` の行に `$e` が含まれる行を返す。
/// `${e.runtimeType}` のように `$e` の直後が識別子文字または `{` の場合は対象外。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findRawExceptionLogs(String filePath) {
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
      .where((line) =>
          line.contains('debugPrint') &&
          // '$e' 単体（変数名 e を直接展開）を検出。
          // '${e.runtimeType}' は '$' の直後が '{' なので除外される。
          RegExp(r'\$e[^{a-zA-Z_]').hasMatch(line))
      .toList();
}

void main() {
  group('セキュリティ — debugPrint 生例外ログ禁止', () {
    test(
        'voting_screen.dart の debugPrint が生例外 \$e を含まないとき 例外情報が漏洩しない',
        () {
      final violations =
          _findRawExceptionLogs('lib/screens/voting_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'debugPrint に \$e を直接入れないでください。\n'
            '\${e.runtimeType} を使用してください。\n'
            '違反行:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'history_provider.dart の debugPrint が生例外 \$e を含まないとき 例外情報が漏洩しない',
        () {
      final violations =
          _findRawExceptionLogs('lib/providers/history_provider.dart');

      expect(
        violations,
        isEmpty,
        reason: 'debugPrint に \$e を直接入れないでください。\n'
            '\${e.runtimeType} を使用してください。\n'
            '違反行:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'analytics_service.dart の debugPrint が生例外 \$e を含まないとき 例外情報が漏洩しない',
        () {
      final violations =
          _findRawExceptionLogs('lib/services/analytics_service.dart');

      expect(
        violations,
        isEmpty,
        reason: 'debugPrint に \$e を直接入れないでください。\n'
            '\${e.runtimeType} を使用してください。\n'
            '対象メソッド: logSearch / logRestaurantClick / logReservationTap /\n'
            '             logShare / logFilterUsed / logSortChanged /\n'
            '             logRestaurantDecided / fetchRanking（8箇所）\n'
            '違反行:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });

    test(
        'ranking_screen.dart の debugPrint が生例外 \$e を含まないとき 例外情報が漏洩しない',
        () {
      final violations =
          _findRawExceptionLogs('lib/screens/ranking_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'debugPrint に \$e を直接入れないでください。\n'
            '\${e.runtimeType} を使用してください。\n'
            '対象箇所: _shareRanking() catch 節（ranking_screen.dart:413）\n'
            '違反行:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
