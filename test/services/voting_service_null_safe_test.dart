// TDD Red フェーズ
// Cycle 8: voting_service.dart の unsafe cast テスト (HIGH ISSUE)
//
// 問題:
//   voting_service.dart の vote() メソッド内:
//     final candidates = List<Map<String, dynamic>>.from(
//       (data['candidates'] as List).map(...)  ← data['candidates'] が null のとき TypeError
//     );
//
//   `data['candidates'] as List` は null の場合に TypeError を throw する。
//   Firestore ドキュメントの `candidates` フィールドが欠損していた場合（
//   不正なドキュメント、マイグレーション後の古いデータ、etc.）にクラッシュする。
//
// 修正方針:
//   CLAUDE.md の「JSON パースは必ず null-safe」ルールに従い:
//     (data['candidates'] as List? ?? []).map(...)
//   のように null-safe cast に変更する。
//
// テスト戦略:
//   静的解析でソースファイルを読み込み、unsafe な `as List)` パターン
//   （null チェックなし）が残っていないことを確認する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `as List)` のような null-unsafe な cast パターンを返す。
/// `as List?` や `as List? ??` は安全なので除外する。
List<String> _findUnsafeListCasts(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) fail('$filePath が存在しません');

  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // `as List)` または `as List,` のパターンを検出（`as List?` は除外）
    // 正規表現: `as List` の後に `?` が続かない場合
    final hasUnsafeCast = RegExp(r'as List[^?]').hasMatch(line) &&
        !line.trim().startsWith('//');
    if (hasUnsafeCast) {
      violations.add('行${i + 1}: ${line.trim()}');
    }
  }

  return violations;
}

/// `as Map)` のような null-unsafe な cast パターンを返す。
/// map() の引数内で `e as Map` のように使われる箇所を検出する。
List<String> _findUnsafeMapCasts(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) fail('$filePath が存在しません');

  final lines = file.readAsLinesSync();
  final violations = <String>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // `e as Map)` や `e as Map,` のように、`as Map` の後に `?` がないパターン
    // ただし `Map<` （型引数）はここでは問題ないため除外
    final hasUnsafeCast = RegExp(r'\bas Map\b[^<\?]').hasMatch(line) &&
        !line.trim().startsWith('//');
    if (hasUnsafeCast) {
      violations.add('行${i + 1}: ${line.trim()}');
    }
  }

  return violations;
}

void main() {
  group('クラッシュ防止 — VotingService null-safe cast', () {
    test(
        'voting_service.dart の vote() で candidates フィールドが null のとき '
        'TypeError が発生しない（null-safe cast）',
        () {
      final violations = _findUnsafeListCasts('lib/services/voting_service.dart');

      expect(
        violations,
        isEmpty,
        reason: '`voting_service.dart` に null-unsafe な `as List` キャストがあります。\n'
            'Firestore の `candidates` フィールドが null/欠損のとき TypeError が発生します。\n'
            '\n'
            'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
            '\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            '  修正前: (data[\'candidates\'] as List).map(...)\n'
            '  修正後: (data[\'candidates\'] as List? ?? []).map(...)\n',
      );
    });

    test(
        'voting_service.dart の vote() でマップ要素が null のとき '
        'TypeError が発生しない（null-safe cast）',
        () {
      final violations = _findUnsafeMapCasts('lib/services/voting_service.dart');

      expect(
        violations,
        isEmpty,
        reason: '`voting_service.dart` に null-unsafe な `as Map` キャストがあります。\n'
            'Firestore のリスト要素が Map でない場合や null の場合に TypeError が発生します。\n'
            '\n'
            '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
            '\n'
            '修正例:\n'
            '  修正前: .map((e) => Map<String, dynamic>.from(e as Map))\n'
            '  修正後: .map((e) => Map<String, dynamic>.from((e as Map?) ?? {}))\n'
            '  または: .whereType<Map>().map((e) => Map<String, dynamic>.from(e))\n',
      );
    });
  });
}
