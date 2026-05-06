// TDD Red フェーズ — Cycle 40: voting_sessions branch (b) に
// ペアワイズ growth 排他制約を追加し「3 候補同時加算による 3 票偽装」を解消
//
// 背景（Cycle 39 Critic CRITICAL × 1 + HIGH × 1 + MEDIUM × 2 の解消）:
//
//   Cycle 39 で各候補に
//     [C1] voters.size() == votes      （インフレ阻止）
//     [C2] voters.size() <= 原+1       （1 候補あたり 1 リクエスト 1 票上限）
//   が入ったが、リクエスト全体での voter 増加合計を縛っていない。
//
//   CRITICAL: 1 リクエストで `voterName='X'` を candidates[0]/[1]/[2] の
//             voters に同時に追加し、各候補の votes も +1 すれば、各候補で
//             [C1]/[C2] を満たしたまま **3 票同時加算** が成立する
//             （Cycle 37/38 で塞いだ「完全な投票偽装」と等価被害が再成立）。
//
//   HIGH:     deploy 前から `votes != voters.size()` の既存ドキュメントが
//             残っていれば、新ルール下で update が永久 deny になり
//             サイレント機能停止する
//             （対応: deploy 前 backfill 手順 — implementation_notes.md 参照）。
//
//   MEDIUM:   Cycle 39 テストが `branch.contains('...')` の静的 string match のみで
//             `&&`→`||` 改竄に対して脆弱
//             （対応: cycle39_test.dart の mutation killing meta-test 追加）。
//
// このファイルの責務（CRITICAL の修正検証）:
//   `firestore.rules` の voting_sessions update branch (b) が以下 6 条件を
//   満たすことを **静的に** 検証する（Firebase Emulator は使わない）。
//
//     [P-01]〜[P-03] ペアワイズ growth 排他: 任意の 2 候補 (i,j) ∈
//                    {(0,1), (0,2), (1,2)} について
//                    「i と j が両方とも voters.size() を増やすことは無い」が
//                    branch (b) 内に含まれる。
//                    受理する書き方（De Morgan で 2 形式どちらでも可）:
//                      Form A:
//                        request.resource.data.candidates[i].voters.size()
//                          == resource.data.candidates[i].voters.size()
//                        || request.resource.data.candidates[j].voters.size()
//                          == resource.data.candidates[j].voters.size()
//                      Form B:
//                        !(request.resource.data.candidates[i].voters.size()
//                            > resource.data.candidates[i].voters.size()
//                          && request.resource.data.candidates[j].voters.size()
//                            > resource.data.candidates[j].voters.size())
//
//     [G-04]〜[G-06] ペアワイズ条件の短絡 wrap: 候補 1〜2 件のセッションで
//                    範囲外参照によるサイレント機能停止を防ぐため、各ペア
//                    (i,j) のペアワイズ条件は `candidates.size() <= max(j,1) ||`
//                    で wrap される。
//                       (0,1) → `candidates.size() <= 1 ||`
//                       (0,2) → `candidates.size() <= 2 ||`
//                       (1,2) → `candidates.size() <= 2 ||`
//
//     [AND-07]       ペアワイズ条件は branch (b) の AND チェーンに含まれる
//                    （`||` 連結や独立 OR 分岐ではなく、必須条件として扱われる）。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle 40: voting_sessions branch (b) ペアワイズ growth 排他で 3 票偽装阻止', () {
    String readBranchB() {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue,
          reason: 'firestore.rules が見つかりません');
      final content = file.readAsStringSync();
      final block = _extractVotingSessionsBlock(content);
      expect(block, isNotEmpty,
          reason:
              '`firestore.rules` に `match /voting_sessions/{sessionId} { ... }` が見つかりません');
      final branchB = _extractBranchB(block);
      expect(branchB, isNotEmpty,
          reason: 'voting_sessions update に '
              "hasOnly(['candidates']) を含む branch (b) が見つかりません");
      return branchB;
    }

    // ──────────────────────────────────────────────────────────────────
    // [P-01]〜[P-03] ペアワイズ growth 排他
    // ──────────────────────────────────────────────────────────────────
    final pairs = <List<int>>[
      [0, 1],
      [0, 2],
      [1, 2],
    ];

    for (final pair in pairs) {
      final i = pair[0];
      final j = pair[1];
      test(
        '[P-${pair.join('')}] branch (b) に candidates[$i]/[$j] の'
        ' growth 排他制約（2 候補同時加算阻止）が含まれる',
        () {
          final branchB = readBranchB();
          final hasFormA = _hasFormA(branchB, i, j);
          final hasFormB = _hasFormB(branchB, i, j);
          expect(
            hasFormA || hasFormB,
            isTrue,
            reason:
                'branch (b) に candidates[$i] と candidates[$j] が同時に\n'
                'voters.size() を増やすことを禁ずる制約が見つかりません。\n'
                '\n'
                '攻撃シナリオ:\n'
                '  1 リクエストで `voterName="X"` を candidates[$i] と candidates[$j] の\n'
                '  voters に同時に追加 + 各候補の votes も +1 すれば、各候補で\n'
                '  Cycle 39 の voters.size()==votes / voters.size()<=原+1 を\n'
                '  満たしたまま **2 票同時加算** が成立する。\n'
                '  candidates[0]/[1]/[2] の 3 ペアすべてに同制約を入れることで\n'
                '  「1 リクエストで growth するのは最大 1 候補のみ」が保証される。\n'
                '\n'
                '受理する書き方（どちらか 1 形式）:\n'
                '\n'
                '  Form A (De Morgan, == の OR):\n'
                '    request.resource.data.candidates[$i].voters.size()\n'
                '      == resource.data.candidates[$i].voters.size()\n'
                '    || request.resource.data.candidates[$j].voters.size()\n'
                '      == resource.data.candidates[$j].voters.size()\n'
                '\n'
                '  Form B (否定の AND):\n'
                '    !(request.resource.data.candidates[$i].voters.size()\n'
                '        > resource.data.candidates[$i].voters.size()\n'
                '      && request.resource.data.candidates[$j].voters.size()\n'
                '        > resource.data.candidates[$j].voters.size())\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        },
      );
    }

    // ──────────────────────────────────────────────────────────────────
    // [G-04]〜[G-06] ペアワイズ条件の短絡 wrap
    // ──────────────────────────────────────────────────────────────────
    test(
      '[G-01] (0,1) ペアワイズ条件が `candidates.size() <= 1 ||` で短絡保護されている '
      '（候補 1 件のセッションで範囲外参照→update 全 deny を防ぐ）',
      () {
        final branchB = readBranchB();
        final guardCount = _countOccurrences(
            branchB, 'request.resource.data.candidates.size() <= 1 ||');
        expect(
          guardCount,
          greaterThanOrEqualTo(2),
          reason: '`candidates.size() <= 1 ||` の出現回数が $guardCount で、\n'
              'Cycle 40 で期待される 2 件以上 (candidates[1] block 1 件 + (0,1) ペア 1 件) を満たしません。\n'
              '\n'
              'Cycle 39 では `candidates.size() <= 1 ||` は candidates[1] block 用の\n'
              '1 件のみ。Cycle 40 では (0,1) ペアワイズ制約用に追加で 1 件必要。\n'
              '\n'
              '修正例:\n'
              '  && (request.resource.data.candidates.size() <= 1 || (\n'
              '       request.resource.data.candidates[0].voters.size()\n'
              '         == resource.data.candidates[0].voters.size()\n'
              '       || request.resource.data.candidates[1].voters.size()\n'
              '         == resource.data.candidates[1].voters.size()))\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    test(
      '[G-02] (0,2)/(1,2) ペアワイズ条件が `candidates.size() <= 2 ||` で短絡保護されている '
      '（候補 2 件のセッションで範囲外参照→update 全 deny を防ぐ）',
      () {
        final branchB = readBranchB();
        final guardCount = _countOccurrences(
            branchB, 'request.resource.data.candidates.size() <= 2 ||');
        expect(
          guardCount,
          greaterThanOrEqualTo(3),
          reason: '`candidates.size() <= 2 ||` の出現回数が $guardCount で、\n'
              'Cycle 40 で期待される 3 件以上 (candidates[2] block 1 件 + (0,2)/(1,2) ペア 2 件) を満たしません。\n'
              '\n'
              'Cycle 39 では `candidates.size() <= 2 ||` は candidates[2] block 用の\n'
              '1 件のみ。Cycle 40 では (0,2) と (1,2) のペアワイズ制約用に追加で 2 件必要。\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [AND-07] ペアワイズ条件は AND チェーンに含まれる
    // ──────────────────────────────────────────────────────────────────
    test(
      '[AND-07] ペアワイズ条件 3 件すべてが branch (b) の AND チェーンに必須条件として含まれる '
      '（独立 OR 分岐や `||` 連結ではなく `&&` で AND-connected）',
      () {
        final branchB = readBranchB();

        // ペアワイズ条件は「`&& (` の直後に `candidates.size() <= N || (`」が来る形で
        // AND チェーンに組み込まれている必要がある（Cycle 39 の candidates[1]/[2] blocks
        // と同じパターン）。
        //
        // 必要件数:
        //   Cycle 39 既存: && (candidates.size() <= 1 || ...   [for c[1] block]    × 1
        //                  && (candidates.size() <= 2 || ...   [for c[2] block]    × 1
        //   Cycle 40 追加: && (candidates.size() <= 1 || ...   [for (0,1) pair]    × 1
        //                  && (candidates.size() <= 2 || ...   [for (0,2) pair]    × 1
        //                  && (candidates.size() <= 2 || ...   [for (1,2) pair]    × 1
        //   合計: && ( ... candidates.size() <= 1|2 || ...) パターン × 5 件
        final andGuardPattern = RegExp(
          r'&&\s*\(\s*request\.resource\.data\.candidates\.size\(\)\s*<=\s*[12]\s*\|\|',
        );
        final andGuardCount = andGuardPattern.allMatches(branchB).length;

        expect(
          andGuardCount,
          greaterThanOrEqualTo(5),
          reason:
              '`&& (candidates.size() <= 1|2 || ...)` パターンの出現が $andGuardCount で、\n'
              'Cycle 40 で期待される 5 件以上を満たしません。\n'
              '\n'
              'ペアワイズ growth 排他 3 件は branch (b) の AND チェーンに `&&` で\n'
              '組み込まれている必要があります。`||` 連結や独立 OR 分岐に置くと\n'
              '攻撃ベクトル（Form A の 1 つを通して他をスキップ）が再成立します。\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [INV] voting_sessions セクション以外が Cycle 40 で 1 バイト不変
    // ──────────────────────────────────────────────────────────────────
    test(
      '[INV] firestore.rules の voting_sessions セクション以外が Cycle 40 で 1 バイト不変',
      () {
        final file = File('firestore.rules');
        final content = file.readAsStringSync();
        final excised = _exciseVotingSection(content);

        expect(
          excised,
          equals(_kExpectedNonVotingSnapshot),
          reason: 'voting_sessions セクション以外が Cycle 40 で改変されています。\n'
              '\n'
              'Cycle 40 のスコープ:\n'
              '  - voting_sessions ブロック branch (b) のみ拡張可\n'
              '    （ペアワイズ growth 排他 3 件 + 短絡 wrap 追加）\n'
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

/// Form A: De Morgan で `==` を `||` で繋いだ書き方
bool _hasFormA(String branchB, int i, int j) {
  final patternA1 =
      'request.resource.data.candidates[$i].voters.size() == resource.data.candidates[$i].voters.size()';
  final patternA2 =
      'request.resource.data.candidates[$j].voters.size() == resource.data.candidates[$j].voters.size()';
  if (!branchB.contains(patternA1) || !branchB.contains(patternA2)) return false;

  // 両方の `==` clause が同じ `||` 連結内に出現する必要がある。
  // 簡易検出: A1 と A2 のいずれかの直後に `\s*||\s*` を挟んで他方が出現する箇所がある。
  final ab = RegExp(
    RegExp.escape(patternA1) + r'\s*\|\|\s*' + RegExp.escape(patternA2),
  );
  final ba = RegExp(
    RegExp.escape(patternA2) + r'\s*\|\|\s*' + RegExp.escape(patternA1),
  );
  return ab.hasMatch(branchB) || ba.hasMatch(branchB);
}

/// Form B: 否定の AND `!(growth_i && growth_j)` 書き方
bool _hasFormB(String branchB, int i, int j) {
  final patternG1 =
      'request.resource.data.candidates[$i].voters.size() > resource.data.candidates[$i].voters.size()';
  final patternG2 =
      'request.resource.data.candidates[$j].voters.size() > resource.data.candidates[$j].voters.size()';
  if (!branchB.contains(patternG1) || !branchB.contains(patternG2)) return false;
  final ab = RegExp(
    r'!\s*\(\s*' +
        RegExp.escape(patternG1) +
        r'\s*&&\s*' +
        RegExp.escape(patternG2) +
        r'\s*\)',
  );
  final ba = RegExp(
    r'!\s*\(\s*' +
        RegExp.escape(patternG2) +
        r'\s*&&\s*' +
        RegExp.escape(patternG1) +
        r'\s*\)',
  );
  return ab.hasMatch(branchB) || ba.hasMatch(branchB);
}

int _countOccurrences(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var idx = 0;
  while (true) {
    final next = haystack.indexOf(needle, idx);
    if (next < 0) break;
    count++;
    idx = next + needle.length;
  }
  return count;
}

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

/// Cycle 39 時点の voting_sessions セクション以外の content（snapshot）。
/// Cycle 40 では voting_sessions のみ変更されるべきで、本 snapshot は変わらない。
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
