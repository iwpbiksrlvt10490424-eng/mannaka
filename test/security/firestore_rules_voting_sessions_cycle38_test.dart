// TDD Red フェーズ — Cycle 38: voting_sessions branch (b) を TOP3 全候補 × identity 不変 8 条件に拡張
//
// 背景（Cycle 37 Critic CRITICAL × 2 + QA REJECTED の解消）:
//   `firestore.rules` の `voting_sessions` `update` ルール branch (b) は
//     && request.resource.data.candidates[0].votes  >= resource.data.candidates[0].votes
//     && request.resource.data.candidates[0].voters.hasAll(resource.data.candidates[0].voters)
//   の 2 条件しか持たず、`candidates[1]` / `candidates[2]` の votes/voters/identity
//   フィールドは完全に未検証。攻撃者は host が `closeSession` で
//   `status='closed'` を確定する直前に candidates[1].name や candidates[2].imageUrl を
//   別 URL／別店舗に書き換えるなど、完全な投票偽装を成立させられる。
//
// このファイルの責務:
//   `firestore.rules` の voting_sessions update branch (b) が TOP3
//   （`candidates[0]` / `candidates[1]` / `candidates[2]`）すべてに対し、
//   以下 8 条件を含むことを **静的に** 検証する（Firebase Emulator は使わない）:
//
//     1. votes 単調非減少:
//        request.resource.data.candidates[i].votes >= resource.data.candidates[i].votes
//     2. voters 集合継承:
//        request.resource.data.candidates[i].voters.hasAll(resource.data.candidates[i].voters)
//     3. id 不変:        request.resource.data.candidates[i].id == resource.data.candidates[i].id
//     4. name 不変:      request.resource.data.candidates[i].name == resource.data.candidates[i].name
//     5. category 不変:  request.resource.data.candidates[i].category == resource.data.candidates[i].category
//     6. priceStr 不変:  request.resource.data.candidates[i].priceStr == resource.data.candidates[i].priceStr
//     7. address 不変:   request.resource.data.candidates[i].address == resource.data.candidates[i].address
//     8. imageUrl 不変:  request.resource.data.candidates[i].imageUrl == resource.data.candidates[i].imageUrl
//
//   さらに:
//     - voting_sessions セクション以外の他 match ブロック群が Cycle 38 で 1 バイト不変
//       （default deny / users / location_sessions / restaurant_cache /
//        line_share_initiated / station_* / *_logs / 既定 deny の改変禁止）
//     - branch (b) (`hasOnly(['candidates'])` 内) に hostUid トークン不在
//       → Cycle 15 由来の intent（参加者投票は hostUid 不一致でも通る）を保護
//
// 受入条件:
//   [C1] branch (b) に candidates[0] の 8 条件すべてが含まれる
//   [C2] branch (b) に candidates[1] の 8 条件すべてが含まれる
//   [C3] branch (b) に candidates[2] の 8 条件すべてが含まれる
//   [C4] substring count による全インデックス保証
//        — candidates[0]/[1]/[2] の出現回数が 16 回以上、かつ TOP3 で均等
//   [C5] voting_sessions セクション以外が Cycle 38 で 1 バイト不変
//   [C6] branch (b) 内に hostUid 不在（cycle15 intent 保護）

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _kIdentityFields = <String>[
  'id',
  'name',
  'category',
  'priceStr',
  'address',
  'imageUrl',
];

void main() {
  group('Cycle 38: voting_sessions branch (b) TOP3 × identity 不変 8 条件拡張', () {
    String readVotingBlock() {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue,
          reason: 'firestore.rules が見つかりません');
      final content = file.readAsStringSync();
      final block = _extractVotingSessionsBlock(content);
      expect(block, isNotEmpty,
          reason: '`firestore.rules` に `match /voting_sessions/{sessionId} { ... }` が見つかりません');
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
    // [C1〜C3] candidates[0]/[1]/[2] の 8 条件
    // ──────────────────────────────────────────────────────────────────
    for (var i = 0; i < 3; i++) {
      test(
        '[C${i + 1}] branch (b) に candidates[$i] の 8 条件 '
        '(votes >= / voters.hasAll / id/name/category/priceStr/address/imageUrl ==) すべてが含まれる',
        () {
          final branchB = readBranchB();
          final missing = <String>[];

          // 1. votes 単調非減少
          final votesPattern =
              'request.resource.data.candidates[$i].votes >= resource.data.candidates[$i].votes';
          if (!branchB.contains(votesPattern)) missing.add(votesPattern);

          // 2. voters superset
          final votersPattern =
              'request.resource.data.candidates[$i].voters.hasAll(resource.data.candidates[$i].voters)';
          if (!branchB.contains(votersPattern)) missing.add(votersPattern);

          // 3〜8. identity 不変
          for (final field in _kIdentityFields) {
            final pat =
                'request.resource.data.candidates[$i].$field == resource.data.candidates[$i].$field';
            if (!branchB.contains(pat)) missing.add(pat);
          }

          expect(
            missing,
            isEmpty,
            reason: 'branch (b) に candidates[$i] の検証条件が不足しています:\n'
                '${missing.map((m) => '  - $m').join('\n')}\n'
                '\n'
                '期待される構造（一例）:\n'
                "  (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['candidates'])\n"
                '      && request.resource.data.candidates.size() == resource.data.candidates.size()\n'
                '      && request.resource.data.candidates[$i].votes >= resource.data.candidates[$i].votes\n'
                '      && request.resource.data.candidates[$i].voters.hasAll(resource.data.candidates[$i].voters)\n'
                '      && request.resource.data.candidates[$i].id == resource.data.candidates[$i].id\n'
                '      && request.resource.data.candidates[$i].name == resource.data.candidates[$i].name\n'
                '      && request.resource.data.candidates[$i].category == resource.data.candidates[$i].category\n'
                '      && request.resource.data.candidates[$i].priceStr == resource.data.candidates[$i].priceStr\n'
                '      && request.resource.data.candidates[$i].address == resource.data.candidates[$i].address\n'
                '      && request.resource.data.candidates[$i].imageUrl == resource.data.candidates[$i].imageUrl)\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        },
      );
    }

    // ──────────────────────────────────────────────────────────────────
    // [C4] substring count による全インデックス保証
    // ──────────────────────────────────────────────────────────────────
    test(
      '[C4] branch (b) で candidates[0]/[1]/[2] の出現回数が均等で各 16 回以上',
      () {
        final branchB = readBranchB();
        final counts = <int, int>{
          0: _countSubstring(branchB, 'candidates[0]'),
          1: _countSubstring(branchB, 'candidates[1]'),
          2: _countSubstring(branchB, 'candidates[2]'),
        };

        // 8 条件 × 左右 2 side = 16 回以上が必要
        for (var i = 0; i < 3; i++) {
          expect(
            counts[i]!,
            greaterThanOrEqualTo(16),
            reason: 'branch (b) における candidates[$i] の出現回数が ${counts[i]} 回。\n'
                '  votes/voters/id/name/category/priceStr/address/imageUrl の\n'
                '  8 条件 × 左右 2 side = 16 回以上が必要です。\n'
                '\n'
                'インデックス別出現回数: $counts\n'
                '\n'
                '現在の branch (b):\n$branchB',
          );
        }

        // TOP3 で対称な検証 → 出現回数は完全一致するべき
        final values = counts.values.toSet();
        expect(
          values.length,
          equals(1),
          reason: 'candidates[0]/[1]/[2] の出現回数が均等ではありません: $counts\n'
              '\n'
              'TOP3 すべてに同じ 8 条件を対称に適用してください。\n'
              '片方のインデックスだけ条件を増やすと攻撃者が薄い方を狙えます。\n'
              '\n'
              '現在の branch (b):\n$branchB',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [C5] voting_sessions セクション以外が 1 バイト不変
    // ──────────────────────────────────────────────────────────────────
    test(
      '[C5] firestore.rules の voting_sessions セクション以外が Cycle 38 で 1 バイト不変',
      () {
        final file = File('firestore.rules');
        final content = file.readAsStringSync();
        final excised = _exciseVotingSection(content);

        expect(
          excised,
          equals(_kExpectedNonVotingSnapshot),
          reason: 'voting_sessions セクション以外が Cycle 38 で改変されています。\n'
              '\n'
              'Cycle 38 のスコープ:\n'
              '  - voting_sessions ブロックの先頭コメント / branch (b) のみ拡張可\n'
              '  - default deny / users / location_sessions / restaurant_cache /\n'
              '    line_share_initiated / station_* / *_logs は 1 バイト不変厳守\n'
              '\n'
              '差分（actual / expected）を比較して該当ブロックを元に戻してください。',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [C6] branch (b) に hostUid 不在（cycle15 intent 保護）
    // ──────────────────────────────────────────────────────────────────
    test(
      "[C6] branch (b) (hasOnly(['candidates']) ブランチ) 内に hostUid トークン不在",
      () {
        final branchB = readBranchB();
        expect(
          branchB.contains('hostUid'),
          isFalse,
          reason: 'branch (b) に hostUid トークンが含まれています。\n'
              '\n'
              'Cycle 15 の intent: 参加者投票（VotingService.vote）は\n'
              '  request.auth.uid != resource.data.hostUid\n'
              'の状態で tx.update() を実行します。branch (b) は host 以外の参加者用\n'
              'ブランチなので、hostUid 制約を入れると本番で投票機能が完全に\n'
              '動作しなくなります（Cycle 14 当時のリグレッション再現）。\n'
              '\n'
              '現在の branch (b):\n$branchB',
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
  // hasOnly(['candidates']) より前で対応する `(` を探す
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
  // 対応する `)` まで前進
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

/// 部分文字列の出現回数を数える
int _countSubstring(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var idx = 0;
  while (true) {
    final found = haystack.indexOf(needle, idx);
    if (found < 0) break;
    count++;
    idx = found + needle.length;
  }
  return count;
}

/// firestore.rules から voting_sessions セクション
/// （先頭の `//` コメント連続行＋match ブロック）を `<<VOTING_SECTION>>` に置換する
String _exciseVotingSection(String content) {
  final lines = content.split('\n');
  final matchIdx = lines.indexWhere(
    (l) => RegExp(r'match\s*/voting_sessions/').hasMatch(l),
  );
  if (matchIdx < 0) return content;

  // 後方に向かって連続するコメント行 (`//` 開始) を含める
  var startIdx = matchIdx;
  while (startIdx - 1 >= 0 && lines[startIdx - 1].trimLeft().startsWith('//')) {
    startIdx--;
  }

  // ブロック開きの `{` は match 行の最後の `{`（path placeholder と区別）
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

/// Cycle 37 時点の voting_sessions セクション以外の content（snapshot）
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
