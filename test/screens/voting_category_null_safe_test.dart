// TDD Red フェーズ
// Cycle 11: voting_screen.dart の category/priceStr null-safe 化
//           + build() 内 _postFrameScheduled 直接代入 検出テスト
//
// Critic [HIGH] 指摘 (Cycle 10):
//   voting_screen.dart:254
//     Text('${c['category']}  ·  ${c['priceStr']}', ...
//
//   `category` / `priceStr` の2フィールドが null-safe でない。
//   他フィールドが `(c['x'] as String?) ?? ''` で統一されているのに不整合。
//   Firestore データ欠損時に "null · null" がユーザーに表示される。
//   CLAUDE.md ルール: "JSON パースは必ず null-safe"
//
// Critic [MEDIUM] 指摘 (Cycle 10):
//   voting_screen.dart:142
//     _postFrameScheduled = true;  // build() 内での直接書き換え
//
//   `_findBuildSideEffects` テストが `_selectedForDecision` のみ対象のため
//   `_postFrameScheduled` への直接代入はテストで検出されない盲点がある。
//
// 修正方針:
//   [HIGH]
//     `${c['category']}` → `${(c['category'] as String?) ?? ''}`
//     `${c['priceStr']}` → `${(c['priceStr'] as String?) ?? ''}`
//   [MEDIUM]
//     `_findBuildSideEffects` の検出対象を `_` で始まるすべての
//     インスタンス変数直接代入に拡張する（または専用ヘルパー追加）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// ヘルパー: 文字列補間内の null-unsafe フィールドアクセスを検出
// ---------------------------------------------------------------------------

/// `${c['fieldName']}` パターン（null-unsafe な文字列補間）を返す。
/// 対象フィールド名リストに含まれる場合のみ違反として報告する。
///
/// 安全パターン（除外）:
///   - `${(c['x'] as String?) ?? 'default'}` — 明示的な null-safe 変換
///   - `${c['x'] ?? ''}` — null 合体演算子あり
///   - `$name` — 変数（既に null-safe で取り出し済み想定）
///
/// 違反パターン（検出）:
///   - `${c['category']}` — null のとき "null" が表示される
///   - `${c['priceStr']}` — 同上
List<String> _findUnsafeInterpolatedFields(
  String filePath,
  List<String> fieldNames,
) {
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
    final trimmed = line.trim();

    // コメント行はスキップ
    if (trimmed.startsWith('//')) continue;

    for (final field in fieldNames) {
      // `${c['field']}` パターンを検出
      // 除外: `${c['field'] ?? ...}`, `${(c['field'] as ...?) ?? ...}`
      final unsafePattern = RegExp(r"\$\{c\['" + field + r"'\]\}");
      if (unsafePattern.hasMatch(line)) {
        // null 合体演算子があれば安全
        // 例: `${c['category'] ?? ''}` は OK
        // 簡易判定: 同一補間ブロック内に `??` がなければ違反
        // 補間ブロックを抽出: `${...}` の中身
        final blockPattern = RegExp(r"\$\{([^}]+)\}");
        final matches = blockPattern.allMatches(line);
        bool hasSafeMatch = false;
        for (final m in matches) {
          final inner = m.group(1) ?? '';
          if (inner.contains("'$field'") && inner.contains('??')) {
            hasSafeMatch = true;
            break;
          }
        }
        if (!hasSafeMatch) {
          violations.add('行${i + 1}: $trimmed');
        }
      }
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// ヘルパー: build() 内のインスタンス変数直接書き換えを全フィールド対象で検出
// ---------------------------------------------------------------------------

/// build() メソッド内で `_` で始まるインスタンス変数を setState() なしに
/// 直接代入している箇所を返す。
///
/// `_findBuildSideEffects`（既存テスト）は `_selectedForDecision` のみ対象。
/// このヘルパーは build() 内の全 `_xxx = yyy` パターンを対象にする。
///
/// 除外条件:
///   - 同行に `setState(` がある
///   - 前3行以内に `setState(` がある（setState ブロック内の代入）
///   - 前5行以内に `addPostFrameCallback` がある（コールバック内の代入）
///   - `_xxx ==` は比較なので除外
///   - コメント行はスキップ
///   - build() 範囲外の代入はスキップ
List<String> _findAllBuildSideEffects(String filePath) {
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
    final trimmed = line.trim();

    // コメント行はスキップ
    if (trimmed.startsWith('//')) continue;

    // `_xxx = yyy` パターン（比較 `==` は除外）
    if (!RegExp(r'\b_\w+\s*=[^=]').hasMatch(line)) continue;

    // 同行に setState( がある場合はOK
    if (line.contains('setState(')) continue;

    // 前3行以内に setState( がある場合もOK（setState ブロック内）
    final nearStart = i >= 3 ? i - 3 : 0;
    final near = lines.sublist(nearStart, i);
    if (near.any((l) => l.contains('setState('))) continue;

    // 前5行以内に addPostFrameCallback がある場合もOK（コールバック内）
    // ただしコメント行は除外（コメント内の言及で誤検出しないよう）
    final cbStart = i >= 5 ? i - 5 : 0;
    final cbNear = lines.sublist(cbStart, i);
    if (cbNear.any((l) {
      final t = l.trim();
      return !t.startsWith('//') && l.contains('addPostFrameCallback');
    })) {
      continue;
    }

    // 前70行以内に `Widget build(` が存在するか確認
    final buildStart = i >= 70 ? i - 70 : 0;
    final preceding = lines.sublist(buildStart, i);
    final isInBuild = preceding.any(
      (l) => RegExp(r'Widget\s+build\s*\(').hasMatch(l),
    );
    if (!isInBuild) continue;

    violations.add('行${i + 1}: $trimmed');
  }

  return violations;
}

// ---------------------------------------------------------------------------
// テスト
// ---------------------------------------------------------------------------

void main() {
  const target = 'lib/screens/voting_screen.dart';

  group('UX品質 — voting_screen.dart category/priceStr null-safe 文字列補間', () {
    test(
      'category フィールドが null のとき "null" 文字列がユーザーに表示されない'
      '（\${c["category"]} → \${(c["category"] as String?) ?? ""}）',
      () {
        final violations = _findUnsafeInterpolatedFields(target, ['category']);

        expect(
          violations,
          isEmpty,
          reason: '`\${c["category"]}` は Firestore の category が null のとき\n'
              '"null" という文字列がそのままユーザーに表示されます。\n'
              '\n'
              'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
              'Critic [HIGH] 指摘: 他フィールドは (c["x"] as String?) ?? "" で統一済みなのに不整合\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正例:\n'
              '  修正前: Text(\'\${c["category"]}  ·  \${c["priceStr"]}\', ...)\n'
              '  修正後: Text(\'\${(c["category"] as String?) ?? ""}  ·  '
              '\${(c["priceStr"] as String?) ?? ""}\', ...)\n',
        );
      },
    );

    test(
      'priceStr フィールドが null のとき "null" 文字列がユーザーに表示されない'
      '（\${c["priceStr"]} → \${(c["priceStr"] as String?) ?? ""}）',
      () {
        final violations = _findUnsafeInterpolatedFields(target, ['priceStr']);

        expect(
          violations,
          isEmpty,
          reason: '`\${c["priceStr"]}` は Firestore の priceStr が null のとき\n'
              '"null" という文字列がそのままユーザーに表示されます。\n'
              '\n'
              'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正例:\n'
              '  修正前: \${c["priceStr"]}\n'
              '  修正後: \${(c["priceStr"] as String?) ?? ""}\n',
        );
      },
    );

    test(
      'category が null のとき空文字列フォールバックが機能する'
      '（ロジック検証）',
      () {
        final Map<String, dynamic> candidate = {
          'id': 'r1',
          'name': '焼肉屋',
          'category': null,
          'priceStr': null,
          'votes': 2,
        };

        // 修正後の期待ロジック
        final category = (candidate['category'] as String?) ?? '';
        final priceStr = (candidate['priceStr'] as String?) ?? '';

        expect(category, '', reason: 'category が null のとき空文字列を返すべき');
        expect(priceStr, '', reason: 'priceStr が null のとき空文字列を返すべき');

        // 文字列補間の結果
        final display = '$category  ·  $priceStr';
        expect(display, '  ·  ', reason: '"null · null" ではなく "  ·  " を返すべき');
        expect(display.contains('null'), isFalse,
            reason: '"null" 文字列がユーザーに表示されてはいけない');
      },
    );
  });

  group('Flutter副作用禁止 — voting_screen.dart build() 内 _postFrameScheduled 直接代入', () {
    test(
      'build() メソッド内で _postFrameScheduled を addPostFrameCallback 外で'
      '直接代入していないとき build() 副作用ルール違反がない'
      '（Critic [MEDIUM]: _findBuildSideEffects の盲点を補完）',
      () {
        // このテストは _postFrameScheduled = true が build() 内で
        // addPostFrameCallback の外に置かれていないかを検証する。
        //
        // 現状:
        //   voting_screen.dart:142
        //     _postFrameScheduled = true;  ← build() 内、addPostFrameCallback 前に直接代入
        //
        // 修正方針:
        //   _postFrameScheduled = true をガード条件の if ブロック内に移動するか、
        //   addPostFrameCallback のクロージャ外から完全に除去する。
        //   （現行の _findBuildSideEffects は _selectedForDecision のみ対象のため
        //    このパターンを検出できていない）

        final violations = _findAllBuildSideEffects(target);

        expect(
          violations,
          isEmpty,
          reason: 'build() 内でのインスタンス変数直接代入は Flutter 副作用禁止ルール違反です。\n'
              '`_postFrameScheduled = true` は build() 内で addPostFrameCallback 登録前に\n'
              '直接代入されており、Flutter が build() を複数回呼ぶ場合に状態が\n'
              '意図しないタイミングで変更される可能性があります。\n'
              '\n'
              '既存テスト `_findBuildSideEffects` は `_selectedForDecision` のみ対象のため\n'
              'このパターンは検出されていません（盲点）。\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正方針:\n'
              '  build() 内の if ブロック全体を整理し、_postFrameScheduled = true を\n'
              '  addPostFrameCallback コールバック内部のみに置く、または\n'
              '  initState / didUpdateWidget に移動する。\n',
        );
      },
    );
  });
}
