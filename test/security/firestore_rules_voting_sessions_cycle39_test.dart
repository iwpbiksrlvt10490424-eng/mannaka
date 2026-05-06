// TDD Red フェーズ — Cycle 39: voting_sessions branch (b) に
// `voters.size() == votes` + `voters.size() <= 原+1` 追加 +
// `candidates[1]` / `candidates[2]` を `candidates.size() <= N || (...)` で短絡評価
//
// 背景（Cycle 38 Critic CRITICAL × 1 + HIGH × 1 の解消）:
//   `firestore.rules` の `voting_sessions` `update` ルール branch (b) は
//   Cycle 38 で TOP3 × 8 条件（votes 単調 / voters superset / identity 不変 6 件）
//   まで強化されたが、依然として
//
//     CRITICAL: voters.size() と votes の整合性検証が無く、
//               `voters: [...原, fake1, fake2, ..., fakeN]` を 1 リクエストで
//               送れば全条件 (`hasAll` / `votes >=`) を通過させたまま
//               任意票数を加算可能（投票数インフレ攻撃）。
//
//     HIGH:     `candidates[1]` / `candidates[2]` をハードコード参照しているため、
//               候補 1〜2 件のセッション（`share_preview_screen.dart:55` の
//               `take(3)` は 1〜2 件もあり得る）では範囲外参照で update が
//               全 deny → 投票機能がサイレントに死ぬ。
//
//   が残存している。
//
// このファイルの責務:
//   `firestore.rules` の voting_sessions update branch (b) が以下 4 条件を
//   満たすことを **静的に** 検証する（Firebase Emulator は使わない）。
//
//     [C1] 各候補 i ∈ {0,1,2} に
//          `request.resource.data.candidates[i].voters.size() == `
//          `request.resource.data.candidates[i].votes`
//          が含まれる（インフレ阻止: voters の個数 = votes 数 で同期）
//     [C2] 各候補 i ∈ {0,1,2} に
//          `request.resource.data.candidates[i].voters.size() <= `
//          `resource.data.candidates[i].voters.size() + 1`
//          が含まれる（1 リクエスト 1 票上限）
//     [C3] `candidates[1]` ブロックは `candidates.size() <= 1 || (...)` で短絡評価、
//          `candidates[2]` ブロックは `candidates.size() <= 2 || (...)` で短絡評価
//          （候補 1〜2 件のセッションでも update が範囲外参照で deny されない）
//     [C4] voting_sessions セクション以外（default deny / users /
//          location_sessions / restaurant_cache / line_share_initiated /
//          station_* / *_logs 等）が Cycle 39 で 1 バイト不変厳守

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle 39: voting_sessions branch (b) インフレ攻撃 + 候補<3 件機能停止 一括解消', () {
    String readVotingBlock() {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue,
          reason: 'firestore.rules が見つかりません');
      final content = file.readAsStringSync();
      final block = _extractVotingSessionsBlock(content);
      expect(block, isNotEmpty,
          reason:
              '`firestore.rules` に `match /voting_sessions/{sessionId} { ... }` が見つかりません');
      return block;
    }

    String readBranchB() {
      final block = readVotingBlock();
      final branchB = _extractBranchB(block);
      expect(branchB, isNotEmpty,
          reason: 'voting_sessions update に '
              "hasOnly(['candidates']) を含む branch (b) が見つかりません");
      return branchB;
    }

    // ──────────────────────────────────────────────────────────────────
    // [C1] voters.size() == votes（インフレ阻止）
    // ──────────────────────────────────────────────────────────────────
    for (var i = 0; i < 3; i++) {
      test(
        '[C1] branch (b) に candidates[$i] の voters.size() == votes 検証が含まれる',
        () {
          final branchB = readBranchB();
          final pattern =
              'request.resource.data.candidates[$i].voters.size() == '
              'request.resource.data.candidates[$i].votes';
          expect(
            branchB.contains(pattern),
            isTrue,
            reason: 'branch (b) に candidates[$i] のインフレ阻止条件が不足:\n'
                '  $pattern\n'
                '\n'
                'Cycle 38 までの `voters.hasAll` + `votes >=` だけでは\n'
                '  voters: [...原, fake1, fake2, ..., fakeN]\n'
                'を 1 リクエストで送るとすべての条件を通過させたまま任意票数を加算できる。\n'
                'voters の個数と votes 数を一致させることで、加算量を voters 増加分と\n'
                'バインドする必要がある。\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        },
      );
    }

    // ──────────────────────────────────────────────────────────────────
    // [C2] voters.size() <= 原+1（1 リクエスト 1 票上限）
    // ──────────────────────────────────────────────────────────────────
    for (var i = 0; i < 3; i++) {
      test(
        '[C2] branch (b) に candidates[$i] の voters.size() <= 原.voters.size() + 1 が含まれる',
        () {
          final branchB = readBranchB();
          final pattern =
              'request.resource.data.candidates[$i].voters.size() <= '
              'resource.data.candidates[$i].voters.size() + 1';
          expect(
            branchB.contains(pattern),
            isTrue,
            reason: 'branch (b) に candidates[$i] の 1 リクエスト 1 票上限が不足:\n'
                '  $pattern\n'
                '\n'
                '1 リクエストで voters を最大 1 件しか増やせない制約が無いと、\n'
                'C1 (`voters.size() == votes`) と組み合わせても 1 トランザクションで\n'
                '複数票（voters: [...原, fake1, fake2]）を加算できてしまう。\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        },
      );
    }

    // ──────────────────────────────────────────────────────────────────
    // [C3] candidates[1] / candidates[2] の短絡評価
    // ──────────────────────────────────────────────────────────────────
    test(
      '[C3-1] candidates[1] アクセスが `candidates.size() <= 1 || (...)` で短絡保護されている',
      () {
        final branchB = readBranchB();
        // `candidates.size() <= 1 ||` の出現を検証
        final hasGuard = branchB.contains('candidates.size() <= 1 ||');
        expect(
          hasGuard,
          isTrue,
          reason: 'branch (b) に candidates[1] アクセスを保護する短絡評価が不足:\n'
              '  期待: `candidates.size() <= 1 || (...candidates[1]...)`\n'
              '\n'
              '`share_preview_screen.dart:55` の `.take(3)` は 1〜2 件もあり得る。\n'
              'candidates[1] をハードコード参照すると候補 1 件のセッションで\n'
              '範囲外参照となり update 全 deny → 投票機能がサイレントに死ぬ。\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );

        // candidates[1] 群が `candidates.size() <= 1 ||` の後に位置することの確認
        final guardIdx = branchB.indexOf('candidates.size() <= 1 ||');
        final firstC1Idx = branchB.indexOf('candidates[1]');
        expect(
          guardIdx >= 0 && firstC1Idx >= 0 && guardIdx < firstC1Idx,
          isTrue,
          reason: 'short-circuit guard `candidates.size() <= 1 ||` は\n'
              'candidates[1] への最初の参照より前に位置する必要があります。\n'
              '\n'
              'guard index = $guardIdx, first candidates[1] index = $firstC1Idx\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    test(
      '[C3-2] candidates[2] アクセスが `candidates.size() <= 2 || (...)` で短絡保護されている',
      () {
        final branchB = readBranchB();
        final hasGuard = branchB.contains('candidates.size() <= 2 ||');
        expect(
          hasGuard,
          isTrue,
          reason: 'branch (b) に candidates[2] アクセスを保護する短絡評価が不足:\n'
              '  期待: `candidates.size() <= 2 || (...candidates[2]...)`\n'
              '\n'
              '`take(3)` は 1〜2 件もあり得る。candidates[2] をハードコード参照すると\n'
              '候補 2 件のセッションで範囲外参照となり update 全 deny。\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );

        final guardIdx = branchB.indexOf('candidates.size() <= 2 ||');
        final firstC2Idx = branchB.indexOf('candidates[2]');
        expect(
          guardIdx >= 0 && firstC2Idx >= 0 && guardIdx < firstC2Idx,
          isTrue,
          reason: 'short-circuit guard `candidates.size() <= 2 ||` は\n'
              'candidates[2] への最初の参照より前に位置する必要があります。\n'
              '\n'
              'guard index = $guardIdx, first candidates[2] index = $firstC2Idx\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [M] mutation killing meta-tests（Cycle 40 Critic MEDIUM 解消）
    //   `branch.contains('...')` の静的 string match のみだと
    //   `&&` を `||` に変えても検出できないため、各候補 i ∈ {0,1,2} の
    //   インフレ阻止条件 (C1) と 1 票上限条件 (C2) が **`&&` 連結子の直後**
    //   に置かれていることを検証する。
    // ──────────────────────────────────────────────────────────────────
    for (var i = 0; i < 3; i++) {
      test(
        '[M-C1-$i] candidates[$i] の voters.size() == votes 条件が `&&` で AND-connected '
        '（`&&`→`||` mutation を検出）',
        () {
          final branchB = readBranchB();
          final pattern = '&& request.resource.data.candidates[$i].voters.size() == '
              'request.resource.data.candidates[$i].votes';
          expect(
            branchB.contains(pattern),
            isTrue,
            reason:
                'candidates[$i] の C1 条件（インフレ阻止）が `&&` で AND-connected されていません。\n'
                '\n'
                '期待: `... && request.resource.data.candidates[$i].voters.size() == ... .votes`\n'
                '\n'
                'Critic MEDIUM 指摘: 静的 string match のみで `&&`→`||` 改竄に脆弱。\n'
                'C1 が OR 連結子で接続されると、他条件のいずれかを満たすだけで C1 が無効化\n'
                'できてしまう（Cycle 39 のインフレ阻止が破綻）。\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        },
      );
    }

    test(
      '[M-C2] 各候補の voters.size() <= 原+1 条件が `&&` で AND-connected '
      '（`&&`→`||` mutation を検出）',
      () {
        final branchB = readBranchB();
        for (var i = 0; i < 3; i++) {
          final pattern = '&& request.resource.data.candidates[$i].voters.size() <= '
              'resource.data.candidates[$i].voters.size() + 1';
          expect(
            branchB.contains(pattern),
            isTrue,
            reason:
                'candidates[$i] の C2 条件（1 リクエスト 1 票上限）が `&&` で\n'
                'AND-connected されていません。\n'
                '\n'
                '期待: `... && request.resource.data.candidates[$i].voters.size() <= '
                'resource.data.candidates[$i].voters.size() + 1`\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        }
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [C4] voting_sessions セクション以外が 1 バイト不変
    // ──────────────────────────────────────────────────────────────────
    test(
      '[C4] firestore.rules の voting_sessions セクション以外が Cycle 39 で 1 バイト不変',
      () {
        final file = File('firestore.rules');
        final content = file.readAsStringSync();
        final excised = _exciseVotingSection(content);

        expect(
          excised,
          equals(_kExpectedNonVotingSnapshot),
          reason: 'voting_sessions セクション以外が Cycle 39 で改変されています。\n'
              '\n'
              'Cycle 39 のスコープ:\n'
              '  - voting_sessions ブロック branch (b) のみ拡張可\n'
              '  - default deny / users / location_sessions / restaurant_cache /\n'
              '    line_share_initiated / station_* / *_logs は 1 バイト不変厳守\n'
              '\n'
              '差分（actual / expected）を比較して該当ブロックを元に戻してください。',
        );
      },
    );
  });
}

// ─── ヘルパー ─────────────────────────────────────────────────────────

/// `match /voting_sessions/{sessionId} { ... }` ブロック全体を抽出する
String _extractVotingSessionsBlock(String content) {
  final marker = RegExp(r'match\s*/voting_sessions/\{[^}]*\}\s*\{');
  final m = marker.firstMatch(content);
  if (m == null) return '';
  var depth = 1;
  var i = m.end;
  while (i < content.length && depth > 0) {
    final ch = content[i];
    if (ch == '{') depth++;
    if (ch == '}') depth--;
    i++;
  }
  if (depth != 0) return '';
  return content.substring(m.start, i);
}

/// voting_sessions ブロック内から branch (b) (`hasOnly(['candidates'])` を含む
/// 括弧グループ) を切り出す
String _extractBranchB(String votingBlock) {
  final candIdx = votingBlock.indexOf("hasOnly(['candidates'])");
  if (candIdx < 0) return '';
  var start = candIdx;
  var depth = 0;
  while (start > 0) {
    final ch = votingBlock[start];
    if (ch == ')') {
      depth++;
    } else if (ch == '(') {
      if (depth == 0) break;
      depth--;
    }
    start--;
  }
  if (votingBlock[start] != '(') return '';
  var end = start + 1;
  depth = 1;
  while (end < votingBlock.length && depth > 0) {
    final ch = votingBlock[end];
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    end++;
  }
  if (depth != 0) return '';
  return votingBlock.substring(start, end);
}

/// firestore.rules から voting_sessions セクション
/// （先頭の `//` コメント連続行＋match ブロック）を `<<VOTING_SECTION>>` に置換する
String _exciseVotingSection(String content) {
  final lines = content.split('\n');
  final matchIdx = lines.indexWhere(
    (l) => RegExp(r'match\s*/voting_sessions/').hasMatch(l),
  );
  if (matchIdx < 0) return content;

  var startIdx = matchIdx;
  while (startIdx - 1 >= 0 && lines[startIdx - 1].trimLeft().startsWith('//')) {
    startIdx--;
  }

  final matchLine = lines[matchIdx];
  final blockOpenCol = matchLine.lastIndexOf('{');
  if (blockOpenCol < 0) return content;

  var depth = 1;
  var endIdx = matchIdx;
  var done = false;
  for (var i = matchIdx; i < lines.length && !done; i++) {
    final line = lines[i];
    final startCol = (i == matchIdx) ? blockOpenCol + 1 : 0;
    for (var j = startCol; j < line.length; j++) {
      final ch = line[j];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          endIdx = i;
          done = true;
          break;
        }
      }
    }
  }

  final excised = <String>[
    ...lines.sublist(0, startIdx),
    '<<VOTING_SECTION>>',
    ...lines.sublist(endIdx + 1),
  ];
  return excised.join('\n');
}

/// Cycle 38 時点の voting_sessions セクション以外の content（snapshot）。
/// Cycle 39 では voting_sessions のみ変更されるべきで、本 snapshot は変わらない。
const String _kExpectedNonVotingSnapshot = r'''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // デフォルト deny — 明示的に許可されていないパスは全て拒否
    match /{document=**} {
      allow read, write: if false;
    }
    // ユーザーデータ: 本人のみ読み書き可能
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
          && request.auth.uid == userId;
    }
<<VOTING_SECTION>>
    // 位置情報セッション:
    // - create は本人（host）のみ
    // - update（位置情報の送信）は **招待された相手** のみ可
    //   （owner 本人が自分のセッションに送れないよう明示的に弾く）
    // - delete は host のみ
    match /location_sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
          && request.auth.uid == request.resource.data.ownerUid;
      allow update: if request.auth != null
          && request.auth.uid != resource.data.ownerUid;
      allow delete: if request.auth != null
          && request.auth.uid == resource.data.ownerUid;
    }
    // 飲食店検索結果のキャッシュ（公開情報）
    match /restaurant_cache/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    // LINE 共有開始ログ（分析用、書き込みのみ・読み取り無し）
    match /line_share_initiated/{docId} {
      allow create: if true;
      allow read: if false;
      allow update: if false;
      allow delete: if false;
    }
    // 集計データ（まんなか指数ランキング・時間帯需要等）
    // 読み取りは公開（ランキング表示用）、書き込みは認証済みユーザー
    match /station_counts/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /station_demand/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /category_demand/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /reservation_leads/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /decided_restaurants/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    // 個別行動ログ（書き込みのみ、読みは Admin SDK 経由）
    // create のみ許可、read/update/delete はクライアントからは不可
    match /search_logs/{document=**} {
      allow create: if request.auth != null;
    }
    match /restaurant_clicks/{document=**} {
      allow create: if request.auth != null;
    }
    match /reservation_logs/{document=**} {
      allow create: if request.auth != null;
    }
    match /share_logs/{document=**} {
      allow create: if request.auth != null;
    }
    match /filter_logs/{document=**} {
      allow create: if request.auth != null;
    }
    match /sort_logs/{document=**} {
      allow create: if request.auth != null;
    }
    match /decision_logs/{document=**} {
      allow create: if request.auth != null;
    }
  }
}
''';
