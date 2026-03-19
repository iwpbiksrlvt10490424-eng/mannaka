// TDD Red フェーズ
// Cycle 9: voting_screen.dart の votes null-unsafe cast + build() 副作用
//
// 問題 1: votes null-unsafe キャスト（HIGH）
//   voting_screen.dart の build() 内:
//     行136: (c['votes'] as int) > m ? (c['votes'] as int) : m
//     行140: (c['votes'] as int) == maxVotes
//     行181: c['votes'] as int
//     行185: s + (cv['votes'] as int)
//
//   Firestore の `votes` フィールドが欠損・null のとき TypeError でクラッシュ。
//   CLAUDE.md ルール: "JSON パースは必ず null-safe"
//
// 問題 2: build() 内でインスタンス変数直接書き換え（MEDIUM）
//   voting_screen.dart の build() 内:
//     行141: _selectedForDecision = topCandidate['id'] as String;
//
//   build() は副作用禁止。setState() を使わない直接代入は
//   「Flutter の build メソッド内での副作用禁止」ルール違反。
//   また、ホットリロード・再ビルド時に意図しないリセットが発生する UX バグ。
//
// 修正方針:
//   1. `c['votes'] as int` → `(c['votes'] as int?) ?? 0` に4箇所修正
//   2. `_selectedForDecision = ...` を build() から取り出し
//      `WidgetsBinding.instance.addPostFrameCallback()` 内で `setState()` を使う、
//      または `didUpdateWidget()` / `initState()` で初期化する

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// ヘルパー: votes の null-unsafe int キャストを検出
// ---------------------------------------------------------------------------

/// `as int)` や `as int;` のような null-unsafe な int キャストを返す。
/// `as int?)` や `as int? ` は安全なので除外する。
/// コメント行はスキップする。
List<String> _findUnsafeIntCasts(String filePath) {
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

    // `as int` の後に `?` が続かないパターンを検出
    // 例: `as int)`, `as int;`, `as int `, `as int,`
    // 除外: `as int?`, `as int<`（型引数）
    if (RegExp(r'as int[^?<\w]').hasMatch(line)) {
      violations.add('行${i + 1}: $trimmed');
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// ヘルパー: build() 内のインスタンス変数直接書き換えを検出
// ---------------------------------------------------------------------------

/// build() メソッド内で `_selectedForDecision =` を setState() なしで
/// 直接代入している箇所を返す。
///
/// 検出条件:
///   - `_selectedForDecision =` を含む行
///   - 同行に `setState` が含まれない（setState 内の代入は OK）
///   - 前30行以内で build() メソッド宣言が存在する
///   - 前3行以内に `setState(` が存在しない
List<String> _findBuildSideEffects(String filePath) {
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

    // `_selectedForDecision =` の直接代入を検出
    // ただし `_selectedForDecision ==` (比較) は除外
    if (!RegExp(r'_selectedForDecision\s*=[^=]').hasMatch(line)) continue;

    // 同行に setState が含まれる場合は OK（setState 内の代入）
    if (line.contains('setState(')) continue;

    // 前3行以内に setState( がある場合も OK（setState ブロック内）
    final nearStart = i >= 3 ? i - 3 : 0;
    final nearPreceding = lines.sublist(nearStart, i);
    if (nearPreceding.any((l) => l.contains('setState('))) continue;

    // 前60行以内に `Widget build(` が存在するか確認
    // （build() 開始から代入箇所まで最大で ~40行程度あるため余裕を持たせる）
    final buildStart = i >= 60 ? i - 60 : 0;
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
// ヘルパー: Map の null-unsafe キャストを検出（whereType<Map>() 推奨）
// ---------------------------------------------------------------------------

/// `as Map)` のような null-unsafe な Map キャストを返す。
/// `as Map?)` や `as Map<`（ジェネリクス）は安全なので除外する。
/// コメント行はスキップする。
List<String> _findUnsafeMapCasts(String filePath) {
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

    // `as Map` の後に `?`・`<`・単語文字が続かないパターンを検出
    // 例: `as Map)`, `as Map,`, `as Map `, `as Map;`
    // 除外: `as Map?`, `as Map<`（ジェネリクス）
    if (RegExp(r'as Map[^?<\w]').hasMatch(line)) {
      violations.add('行${i + 1}: $trimmed');
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// ヘルパー: addPostFrameCallback 重複登録ガードの欠如を検出
// ---------------------------------------------------------------------------

/// `addPostFrameCallback` の呼び出し登録が guard フラグなしに build() 内で行われる
/// 箇所を返す。guard フラグとは `_postFrameScheduled`（またはそれに準ずる）bool 変数。
///
/// 検出条件:
///   - ファイルに `addPostFrameCallback` が存在する
///   - かつ `_postFrameScheduled` のような guard 変数の宣言が存在しない
List<String> _findUnguardedPostFrameCallback(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    fail(
      '$filePath が存在しません。\n'
      'ファイルパスが正しいか確認してください。\n'
      '（ファイル非存在のまま PASS させると偽グリーンになります）',
    );
  }

  final content = file.readAsStringSync();

  // addPostFrameCallback が存在しない場合は対象外
  if (!content.contains('addPostFrameCallback')) return [];

  // guard フラグが宣言されているか確認（bool 型の _...Scheduled または _...Guard）
  final hasGuard = RegExp(r'bool\s+_\w*([Ss]cheduled|[Gg]uard|[Pp]ending)\w*\s*=').hasMatch(content);

  if (!hasGuard) {
    return [
      'addPostFrameCallback が重複登録ガードなしで使用されています。\n'
      '  build() が複数回呼ばれると同一フレームで複数の callback が登録され、\n'
      '  setState() が重複して呼ばれる UX バグが発生します。\n'
      '  `bool _postFrameScheduled = false;` などのガードフラグを追加してください。',
    ];
  }

  return [];
}

// ---------------------------------------------------------------------------
// ヘルパー: String の null-unsafe キャストを検出
// ---------------------------------------------------------------------------

/// `as String)`, `as String;`, `as String ` などの null-unsafe な String キャストを返す。
/// `as String?` や `as String<`（型引数）は安全なので除外する。
/// コメント行はスキップする。
List<String> _findUnsafeStringCasts(String filePath) {
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

    // `as String` の後に `?` が続かないパターンを検出
    // 除外: `as String?`, `as String<`（型引数）
    if (RegExp(r'as String[^?<\w]').hasMatch(line)) {
      violations.add('行${i + 1}: $trimmed');
    }
  }

  return violations;
}

// ---------------------------------------------------------------------------
// テスト
// ---------------------------------------------------------------------------

void main() {
  const target = 'lib/screens/voting_screen.dart';

  group('クラッシュ防止 — voting_screen.dart votes null-safe キャスト', () {
    test(
      'votes フィールドが null のとき TypeError が発生しない'
      '（as int → (as int?) ?? 0）',
      () {
        final violations = _findUnsafeIntCasts(target);

        expect(
          violations,
          isEmpty,
          reason: '`votes` フィールドが Firestore から欠損・null で返った場合、\n'
              '`as int` キャストは TypeError でクラッシュします。\n'
              '\n'
              'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正例（4箇所）:\n'
              '  修正前: (c["votes"] as int) > m\n'
              '  修正後: ((c["votes"] as int?) ?? 0) > m\n'
              '\n'
              '  修正前: (c["votes"] as int) == maxVotes\n'
              '  修正後: ((c["votes"] as int?) ?? 0) == maxVotes\n'
              '\n'
              '  修正前: final votes = c["votes"] as int;\n'
              '  修正後: final votes = (c["votes"] as int?) ?? 0;\n'
              '\n'
              '  修正前: s + (cv["votes"] as int)\n'
              '  修正後: s + ((cv["votes"] as int?) ?? 0)\n',
        );
      },
    );

    test(
      'votes が 0 のとき maxVotes 計算が正しく 0 を返す'
      '（ロジック検証）',
      () {
        // `(x as int?) ?? 0` パターンで votes=null を 0 として扱うロジックの検証
        final List<Map<String, dynamic>> candidates = [
          {'id': 'r1', 'votes': null},
          {'id': 'r2', 'votes': null},
        ];

        // 修正後の期待ロジック: null → 0 として計算
        final maxVotes = candidates.fold<int>(
          0,
          (m, c) => ((c['votes'] as int?) ?? 0) > m
              ? ((c['votes'] as int?) ?? 0)
              : m,
        );
        expect(maxVotes, 0, reason: 'votes が全て null のとき maxVotes は 0 になるべき');

        // votes が 0 の場合も同様
        final candidates2 = [
          {'id': 'r1', 'votes': 0},
          {'id': 'r2', 'votes': 3},
        ];
        final maxVotes2 = candidates2.fold<int>(
          0,
          (m, c) => ((c['votes'] as int?) ?? 0) > m
              ? ((c['votes'] as int?) ?? 0)
              : m,
        );
        expect(maxVotes2, 3);
      },
    );

    test(
      'totalVotes 計算で votes が null のとき 0 として集計される',
      () {
        final List<Map<String, dynamic>> candidates = [
          {'id': 'r1', 'votes': 2},
          {'id': 'r2', 'votes': null},
          {'id': 'r3', 'votes': 1},
        ];

        // 修正後の期待ロジック
        final totalVotes = candidates.fold<int>(
          0,
          (s, cv) => s + ((cv['votes'] as int?) ?? 0),
        );
        expect(totalVotes, 3, reason: 'null は 0 として扱われるべき');
      },
    );
  });

  group('クラッシュ防止 — voting_screen.dart id/name null-safe String キャスト', () {
    test(
      'id/name フィールドが null のとき TypeError が発生しない'
      '（as String → (as String?) ?? \'\'）',
      () {
        final violations = _findUnsafeStringCasts(target);

        expect(
          violations,
          isEmpty,
          reason: '`id` / `name` フィールドが Firestore から欠損・null で返った場合、\n'
              '`as String` キャストは TypeError でクラッシュします。\n'
              '\n'
              'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正例（2箇所）:\n'
              '  修正前: final id = c[\'id\'] as String;\n'
              '  修正後: final id = (c[\'id\'] as String?) ?? \'\';\n'
              '\n'
              '  修正前: final name = c[\'name\'] as String;\n'
              '  修正後: final name = (c[\'name\'] as String?) ?? \'\';\n',
        );
      },
    );

    test(
      'id/name が null のとき空文字列フォールバックが機能する'
      '（ロジック検証）',
      () {
        final Map<String, dynamic> candidate = {'id': null, 'name': null};

        final id = (candidate['id'] as String?) ?? '';
        final name = (candidate['name'] as String?) ?? '';

        expect(id, '', reason: 'id が null のとき空文字列を返すべき');
        expect(name, '', reason: 'name が null のとき空文字列を返すべき');
      },
    );
  });

  group('クラッシュ防止 — voting_screen.dart e as Map 安全フィルタ', () {
    test(
      'candidates リスト要素が Map 型でないとき TypeError が発生しない'
      '（e as Map → whereType<Map>() で安全フィルタ）',
      () {
        final violations = _findUnsafeMapCasts(target);

        expect(
          violations,
          isEmpty,
          reason: '`e as Map` は要素が null・非 Map のとき TypeError でクラッシュします。\n'
              '\n'
              'CLAUDE.md ルール: "JSON パースは必ず null-safe"\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正例:\n'
              '  修正前:\n'
              '    final candidates = List<Map<String, dynamic>>.from(\n'
              '      rawList.map((e) => Map<String, dynamic>.from(e as Map))\n'
              '    );\n'
              '\n'
              '  修正後:\n'
              '    final candidates = rawList\n'
              '        .whereType<Map>()\n'
              '        .map((e) => Map<String, dynamic>.from(e))\n'
              '        .toList();\n',
        );
      },
    );

    test(
      'whereType<Map>() で非 Map 要素を除外したとき正しいリストが返る'
      '（ロジック検証）',
      () {
        // Firestore が壊れた場合に null や String が混在することがある
        final rawList = [
          {'id': 'r1', 'name': '焼肉屋', 'votes': 2},
          null,
          'invalid_string',
          {'id': 'r2', 'name': '寿司屋', 'votes': 1},
        ];

        // whereType<Map>() で安全フィルタ
        final candidates = rawList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        expect(candidates.length, 2, reason: 'null と String は除外されるべき');
        expect(candidates[0]['id'], 'r1');
        expect(candidates[1]['id'], 'r2');
      },
    );
  });

  group('UXバグ防止 — voting_screen.dart addPostFrameCallback 重複登録ガード', () {
    test(
      'addPostFrameCallback が build() 内で重複登録されないよう'
      'ガードフラグが存在するとき重複 setState が発生しない',
      () {
        final violations = _findUnguardedPostFrameCallback(target);

        expect(
          violations,
          isEmpty,
          reason: 'build() が複数回呼ばれると（Stream 更新・ホットリロード等）\n'
              '_selectedForDecision == null の間に addPostFrameCallback が\n'
              '重複登録され、setState() が複数回実行される UX バグがあります。\n'
              '\n'
              '違反内容:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '修正方針 — `_postFrameScheduled` フラグを追加する:\n'
              '\n'
              '  // State クラスのフィールド:\n'
              '  bool _postFrameScheduled = false;\n'
              '\n'
              '  // build() 内の登録条件:\n'
              '  if (isHost && _selectedForDecision == null &&\n'
              '      maxVotes > 0 && !_postFrameScheduled) {\n'
              '    _postFrameScheduled = true;\n'
              '    WidgetsBinding.instance.addPostFrameCallback((_) {\n'
              '      _postFrameScheduled = false;\n'
              '      if (mounted) {\n'
              '        setState(() {\n'
              '          _selectedForDecision = topCandidate[\'id\'] as String?;\n'
              '        });\n'
              '      }\n'
              '    });\n'
              '  }\n',
        );
      },
    );
  });

  group('Flutter副作用禁止 — voting_screen.dart build() 内インスタンス変数書き換え', () {
    test(
      'build() メソッド内で _selectedForDecision を setState() なしに'
      '直接書き換えていないとき Flutter副作用禁止ルール違反がない',
      () {
        final violations = _findBuildSideEffects(target);

        expect(
          violations,
          isEmpty,
          reason: '`build()` は副作用禁止です。\n'
              'インスタンス変数への直接代入は setState() 内で行う必要があります。\n'
              '\n'
              '違反箇所:\n${violations.map((l) => '  $l').join('\n')}\n'
              '\n'
              '問題: build() が呼ばれるたびに _selectedForDecision がリセットされる UX バグ。\n'
              'ホットリロード時や親ウィジェットの再ビルド時に意図しない状態変化が発生する。\n'
              '\n'
              '修正方針:\n'
              '  build() 内の直接代入を削除し、以下のいずれかに移動する:\n'
              '\n'
              '  選択肢A — WidgetsBinding.addPostFrameCallback():\n'
              '    if (isHost && _selectedForDecision == null && maxVotes > 0) {\n'
              '      WidgetsBinding.instance.addPostFrameCallback((_) {\n'
              '        if (mounted) {\n'
              '          setState(() {\n'
              '            _selectedForDecision = topCandidate["id"] as String?;\n'
              '          });\n'
              '        }\n'
              '      });\n'
              '    }\n'
              '\n'
              '  選択肢B — StreamBuilder の snapshot 変化を検知:\n'
              '    build() 内の if ブロックを削除し、\n'
              '    StreamBuilder の builder で _selectedForDecision が未設定のとき\n'
              '    addPostFrameCallback で setState() する\n',
        );
      },
    );
  });
}
