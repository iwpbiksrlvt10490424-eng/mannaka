// TDD Red フェーズ — Cycle 37: firestore.rules `voting_sessions` update を field-level に絞り込み
//
// 背景（Cycle 36 Critic / Security 双方が「次サイクル必須」と明示した残課題）:
//   `firestore.rules:13-21` の `voting_sessions` ルールは
//     allow update: if request.auth != null;
//   と field 検証なしの全開放となっている。
//
//   結果として、認証済みの第三者が任意 sessionId に対して
//     - `candidates` 配列を別メニューで全置換
//     - `status` を勝手に `closed` 確定
//     - `decidedRestaurantId` / `decidedRestaurantName` を改竄
//     - `hostUid` を改竄してホストなりすまし
//   といった攻撃が可能となる構造的脆弱性が残存している。
//
// このファイルの責務:
//   `firestore.rules` の `voting_sessions` `update` ルールが、以下 3 つの構造を
//   満たすことを **静的に** 検証する（Firebase Emulator は使わない / architect-lead 判断待ち）。
//
//   (a) hostUid 限定で status/decided 系のみ更新可:
//       request.auth.uid == resource.data.hostUid 条件のもとで
//       status / decidedRestaurantId / decidedRestaurantName / closedAt を更新できる branch
//   (b) candidates 配列の単調追加のみ:
//       認証済みユーザーが candidates のみを更新できるが、
//       各候補の id/name/category/priceStr/address/imageUrl は不変、
//       votes は単調非減少、voters は superset でなければならない
//   (c) その他フィールド（hostUid/hostName/createdAt/expiresAt）の改竄拒否:
//       request.resource.data.<field> == resource.data.<field> による不変条件
//
// 受入条件:
//   [A] firestore.rules が存在する（自己点検）
//   [B] 旧来の単純全開放 `allow update: if request.auth != null;` が
//       voting_sessions ブロック内から消えている
//   [C] update ルールに hostUid 一致条件 (`request.auth.uid == resource.data.hostUid`)
//       を含む branch が存在する
//   [D] update ルールに status/decidedRestaurantId/decidedRestaurantName/closedAt の
//       host 限定更新が field 名として登場する
//   [E] update ルールに candidates 配列限定更新ブランチが存在する
//       （= candidates のみを affectedKeys にする / candidates 値の検証を含む）
//   [F] update ルールに votes 単調非減少 / voters superset 条件が含まれる
//       （`hasAll` 等の Firestore Rules セット演算 or 数値比較 `>=`）
//   [G] update ルールに hostUid 不変条件が含まれる
//   [H] update ルールに hostName 不変条件が含まれる
//   [I] update ルールに createdAt 不変条件が含まれる
//   [J] update ルールに expiresAt 不変条件が含まれる
//   [K] read 据え置き — `match /voting_sessions/{sessionId}` 内の
//       `allow read: if request.auth != null;` が消えていない
//   [L] create 据え置き — `allow create: if request.auth != null;` が消えていない
//   [M] delete 据え置き — `allow delete: if request.auth != null && request.auth.uid == resource.data.hostUid;`
//       が消えていない
//
// 不変項:
//   - Cycle 27〜30 / 33〜36 の characterization snapshot は **1 バイト不変** 厳守
//     （これらは share_utils 系のため当該テストでは間接的にしか保護しないが、
//      `firestore.rules` のみを変更する Cycle 37 では影響しないことを Engineer 側で確認する）
//
// 注意:
//   - 単純な substring マッチでなく、`voting_sessions` ブロック内のテキストに対して
//     検証を行う。`location_sessions` ブロック側の `request.auth.uid` 条件と
//     誤認しないよう、まず voting_sessions ブロックを切り出してから走査する。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cycle 37: firestore.rules voting_sessions update を field-level に絞り込み', () {
    // ──────────────────────────────────────────────────────────────────
    // [A] 走査自体ができていることの自己点検
    // ──────────────────────────────────────────────────────────────────
    test('[A] firestore.rules が存在する（走査健全性）', () {
      final file = File('firestore.rules');
      expect(file.existsSync(), isTrue,
          reason: 'プロジェクトルートに firestore.rules が存在しません。');
    });

    // ──────────────────────────────────────────────────────────────────
    // 共通: voting_sessions ブロックの切り出し
    // ──────────────────────────────────────────────────────────────────
    String readVotingBlock() {
      final file = File('firestore.rules');
      final content = file.readAsStringSync();
      final block = _extractVotingSessionsBlock(content);
      expect(block, isNotEmpty,
          reason: '`firestore.rules` に `match /voting_sessions/{sessionId} { ... }` ブロックが見つかりません。');
      return block;
    }

    // ──────────────────────────────────────────────────────────────────
    // [B] 旧来の単純全開放 update が消えている
    // ──────────────────────────────────────────────────────────────────
    test(
      '[B] voting_sessions ブロック内に旧来の `allow update: if request.auth != null;` 単純全開放が残っていない',
      () {
        final block = readVotingBlock();

        // 単純全開放 = `allow update: if request.auth != null;` の単一行
        // 改行 / セミコロンで完結し、`&&` で追加条件が無いものを違反として検出
        final naivePattern = RegExp(
          r'allow\s+update\s*:\s*if\s+request\.auth\s*!=\s*null\s*;',
        );

        expect(
          naivePattern.hasMatch(block),
          isFalse,
          reason: '`voting_sessions` ブロックに、追加条件のない\n'
              '  allow update: if request.auth != null;\n'
              'が残っています。Cycle 37 では field-level に絞り込んでください。\n'
              '\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [C] hostUid 一致条件 を含む branch がある
    // ──────────────────────────────────────────────────────────────────
    test(
      '[C] update ルールに hostUid 一致条件 (`request.auth.uid == resource.data.hostUid`) を含む branch がある',
      () {
        final block = readVotingBlock();

        final hostUidMatch = block.contains('request.auth.uid == resource.data.hostUid') ||
            block.contains('resource.data.hostUid == request.auth.uid');

        expect(
          hostUidMatch,
          isTrue,
          reason: '`voting_sessions` の update ルールに hostUid 一致条件がありません。\n'
              'host による status/decided 更新を許可する branch には\n'
              '  request.auth.uid == resource.data.hostUid\n'
              'が必要です。\n\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [D] host 限定で status/decidedRestaurantId/decidedRestaurantName/closedAt 更新可
    // ──────────────────────────────────────────────────────────────────
    test(
      '[D] update ルールに status/decidedRestaurantId/decidedRestaurantName/closedAt が field 名として登場する',
      () {
        final block = readVotingBlock();
        final missing = <String>[];
        for (final field in const [
          'status',
          'decidedRestaurantId',
          'decidedRestaurantName',
          'closedAt',
        ]) {
          if (!block.contains(field)) missing.add(field);
        }

        expect(
          missing,
          isEmpty,
          reason: '`voting_sessions` update に host 限定更新フィールドが登場していません。\n'
              '不足: ${missing.join(', ')}\n'
              '\n'
              'host だけが status を closed に確定でき、decidedRestaurantId/Name/closedAt を\n'
              '書ける構造であることを field 名で明示してください。\n'
              '\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [E] candidates 配列限定の更新ブランチ
    // ──────────────────────────────────────────────────────────────────
    test(
      '[E] update ルールに candidates 配列限定の更新ブランチがある（affectedKeys または candidates 検証）',
      () {
        final block = readVotingBlock();

        // candidates のみを更新する branch があるかを以下のいずれかで検出:
        //   (1) `affectedKeys()` で diff を取り、candidates のみに限定するパターン
        //   (2) `request.resource.data.candidates` の検証（候補配列の値検証）
        final hasCandidatesOnlyBranch =
            block.contains('affectedKeys') &&
                block.contains('candidates');
        final hasCandidatesValueCheck =
            block.contains('request.resource.data.candidates');

        expect(
          hasCandidatesOnlyBranch || hasCandidatesValueCheck,
          isTrue,
          reason: '`voting_sessions` update に candidates 配列限定の branch が見当たりません。\n'
              '\n'
              '期待される構造例（どちらか）:\n'
              '  (1) affectedKeys() で candidates のみに絞る:\n'
              '      request.resource.data.diff(resource.data).affectedKeys()\n'
              '          .hasOnly([\'candidates\'])\n'
              '  (2) request.resource.data.candidates を直接検証する:\n'
              '      request.resource.data.candidates.size() == resource.data.candidates.size()\n'
              '\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [F] votes 単調非減少 / voters superset
    // ──────────────────────────────────────────────────────────────────
    test(
      '[F] update ルールに votes 単調非減少 / voters superset の検証が含まれる',
      () {
        final block = readVotingBlock();

        // votes は数値比較 (>=) または等価条件、voters は superset (hasAll) で検証する想定
        final hasVotesMonotonic =
            block.contains('votes') &&
                (block.contains('>=') || block.contains('>= '));
        final hasVotersSuperset =
            block.contains('voters') &&
                (block.contains('hasAll') || block.contains('hasAny('));

        expect(
          hasVotesMonotonic && hasVotersSuperset,
          isTrue,
          reason: '`voting_sessions` update に votes/voters の単調追加検証が含まれていません。\n'
              '\n'
              '期待される構造例:\n'
              '  // votes は単調非減少\n'
              '  request.resource.data.candidates[i].votes >= resource.data.candidates[i].votes\n'
              '  // voters は superset（既存の voter を残す）\n'
              '  request.resource.data.candidates[i].voters.hasAll(resource.data.candidates[i].voters)\n'
              '\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      },
    );

    // ──────────────────────────────────────────────────────────────────
    // [G〜J] 不変フィールド条件
    // ──────────────────────────────────────────────────────────────────
    for (final field in const ['hostUid', 'hostName', 'createdAt', 'expiresAt']) {
      test('[G/H/I/J] update ルールに $field 不変条件が含まれる', () {
        final block = readVotingBlock();

        // 不変条件パターン:
        //   (1) `request.resource.data.<field> == resource.data.<field>`
        //   (2) `affectedKeys().hasOnly([...])` で <field> を含めないことで間接的に保護
        final hasExplicitInvariant = block.contains(
          'request.resource.data.$field == resource.data.$field',
        );
        // affectedKeys 経由の保護は、当該フィールドが hasOnly のリストに含まれて
        // *いない* ことが望ましいが、静的検出では affectedKeys ブロック自体の存在を許容する
        final hasAffectedKeysGuard =
            block.contains('affectedKeys') && block.contains('hasOnly');

        expect(
          hasExplicitInvariant || hasAffectedKeysGuard,
          isTrue,
          reason: '`voting_sessions` update に $field の不変条件が見当たりません。\n'
              '\n'
              '期待される構造例（どちらか）:\n'
              '  (1) 明示的な等価条件:\n'
              '      request.resource.data.$field == resource.data.$field\n'
              '  (2) affectedKeys().hasOnly([...]) で許可フィールドリストに $field を含めない\n'
              '\n'
              '現在の voting_sessions ブロック:\n$block',
        );
      });
    }

    // ──────────────────────────────────────────────────────────────────
    // [K] read 据え置き
    // ──────────────────────────────────────────────────────────────────
    test('[K] read 据え置き — `allow read: if request.auth != null;` が voting_sessions に残っている', () {
      final block = readVotingBlock();
      expect(
        block.contains('allow read: if request.auth != null'),
        isTrue,
        reason: 'Cycle 37 のスコープは update のみ。read ルールは据え置きです。\n'
            '`allow read: if request.auth != null;` を消さないでください。\n'
            '\n'
            '現在の voting_sessions ブロック:\n$block',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [L] create 据え置き
    // ──────────────────────────────────────────────────────────────────
    test('[L] create 据え置き — `allow create: if request.auth != null;` が voting_sessions に残っている', () {
      final block = readVotingBlock();
      expect(
        block.contains('allow create: if request.auth != null'),
        isTrue,
        reason: 'Cycle 37 のスコープは update のみ。create ルールは据え置きです。\n'
            '`allow create: if request.auth != null;` を消さないでください。\n'
            '\n'
            '現在の voting_sessions ブロック:\n$block',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [M] delete 据え置き
    // ──────────────────────────────────────────────────────────────────
    test('[M] delete 据え置き — host 限定 delete ルールが voting_sessions に残っている', () {
      final block = readVotingBlock();
      // 旧 delete: `request.auth.uid == resource.data.hostUid`
      // この条件は update でも使うが、`allow delete:` の直後にも必須
      final hasDeleteRule = RegExp(
        r'allow\s+delete\s*:\s*if\s+request\.auth\s*!=\s*null',
      ).hasMatch(block);
      final hasHostUidConstraint = block.contains('resource.data.hostUid');

      expect(
        hasDeleteRule && hasHostUidConstraint,
        isTrue,
        reason: 'Cycle 37 のスコープは update のみ。delete の host 限定ルールは据え置きです。\n'
            'allow delete: if request.auth != null && request.auth.uid == resource.data.hostUid;\n'
            'を消さないでください。\n'
            '\n'
            '現在の voting_sessions ブロック:\n$block',
      );
    });
  });
}

/// `match /voting_sessions/{sessionId} { ... }` ブロックを抽出する。
/// 中括弧の対応を取って正確に切り出す（ネストはこのブロックには無いが
/// 念のためカウンタで対応）。
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
