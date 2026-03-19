// TDD Red フェーズ
// Cycle 6: SnackBar 生例外露出禁止テスト
//
// 問題:
//   share_preview_screen.dart の catch 節で $e を SnackBar に直接渡している。
//   例外の toString() がユーザー画面にそのまま表示されるため、
//   内部エラー情報（ファイルパス・APIキー等）が漏洩するリスクがある。
//
// 違反箇所:
//   lib/screens/share_preview_screen.dart:64
//     SnackBar(content: Text('投票セッションの作成に失敗しました: $e'))
//   lib/screens/share_preview_screen.dart:113
//     SnackBar(content: Text('シェアに失敗しました: $e'))
//
// 修正方針:
//   $e を含む SnackBar メッセージを固定文言に変更する。
//   例: '投票セッションの作成に失敗しました。もう一度お試しください。'
//       'シェアに失敗しました。もう一度お試しください。'

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SnackBar の content に $e が直接入っている行を返す。
/// ファイルが存在しない場合は fail() する（偽グリーン防止）。
List<String> _findRawExceptionInSnackBar(String filePath) {
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
      .where((entry) =>
          entry.value.contains('SnackBar') &&
          // $e 単体を検出。${e.runtimeType} のような安全な形式は除外。
          RegExp(r'\$e[^{a-zA-Z_]').hasMatch(entry.value))
      .map((e) => '行${e.key + 1}: ${e.value.trim()}')
      .toList();
}

void main() {
  group('セキュリティ — SnackBar 生例外露出禁止', () {
    test(
        'share_preview_screen.dart の SnackBar が生例外 \$e を含まないとき '
        'エラー情報がユーザーに露出しない',
        () {
      final violations = _findRawExceptionInSnackBar(
          'lib/screens/share_preview_screen.dart');

      expect(
        violations,
        isEmpty,
        reason: 'SnackBar に \$e を直接入れないでください。\n'
            '固定文言（例: 「失敗しました。もう一度お試しください。」）に変更してください。\n'
            '対象箇所: _startVoting() catch 節、_shareAsImage() catch 節\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}',
      );
    });
  });
}
