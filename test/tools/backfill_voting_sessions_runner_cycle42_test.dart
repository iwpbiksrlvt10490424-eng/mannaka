// TDD Red フェーズ — Cycle 42:
//   voting_sessions backfill CLI shell 本体（`tools/backfill_voting_sessions.dart`）
//   と、その中核となる JSON I/O ランナー関数 `runBackfillCli` の受け入れ条件
//   C12〜C17 を Red で固定する。
//
// 背景（current_task.md / 2026-05-01）:
//   Cycle 41 は logic 層（`classifyDoc`/`applyDocPlan`/`summarize`）の Red→Green
//   までで止まっており、CLI shell 本体が無い。よって運用者は backfill を
//   走らせる手段が無く、firestore.rules deploy ブロッカーは実質未解消。
//
//   PM 判断: 依存追加ゼロ（`dart:io` + `dart:convert` のみ）の JSON I/O 方式。
//   gcloud firestore export → JSON 変換 → CLI dry-run → manualReview 人手 →
//   CLI --apply → gcloud firestore import → rules deploy の 5 段運用。
//
// このファイルが固定する契約:
//   - `runBackfillCli({inputJson, args})` を `voting_sessions_backfill_logic.dart`
//     に export させる。Firestore I/O ではなく純粋な JSON 文字列入出力にする
//     ことで、CLI 本体は `dart:io` で stdin/stdout/file をつなぐだけの薄い
//     shell に保てる（テスト容易性 + 依存追加ゼロ）。
//   - dry-run 既定で `outputJson` は null（書き込み JSON を生成しない）。
//   - `--apply` 時のみ `outputJson` に正規化済み JSON を返す。
//     truncate は voters[0:votes] に切り詰め、manualReview と healthy 候補は
//     1 バイト不変で素通す（current_task.md C3 の「偽票方向の改竄禁止」を維持）。
//   - 入力 JSON 構造不正（パース失敗 / `docs` 欠損）は exitCode != 0 で
//     stderr に理由を返す。例外で潰さない。
//   - `tools/backfill_voting_sessions.dart` の import は `dart:io` /
//     `dart:convert` および `package:mannaka/tools/voting_sessions_backfill_logic.dart`
//     のみとする（依存追加ゼロを構造担保）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/tools/voting_sessions_backfill_logic.dart';

void main() {
  Map<String, dynamic> mkCandidate({
    required String id,
    required List<String> voters,
    required int votes,
  }) {
    return <String, dynamic>{
      'id': id,
      'name': 'Restaurant $id',
      'category': 'cafe',
      'priceStr': '~¥1000',
      'address': 'Tokyo',
      'imageUrl': '',
      'voters': List<String>.from(voters),
      'votes': votes,
    };
  }

  String mkInput(List<Map<String, dynamic>> docs) {
    return jsonEncode(<String, dynamic>{
      'docs': [
        for (var i = 0; i < docs.length; i++)
          {
            'id': 'd${i + 1}',
            'data': docs[i],
          },
      ],
    });
  }

  group('runBackfillCli (Cycle 42 / C12, C14, C15)', () {
    test('[C12-1] 健全 doc のみの入力 — exitCode=0 / summary 正確 / dry-run 既定で outputJson は null', () {
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>[]);

      expect(res.exitCode, 0);
      expect(res.summary, isNotNull);
      expect(res.summary!.totalDocs, 1);
      expect(res.summary!.healthyDocs, 1);
      expect(res.summary!.truncateDocs, 0);
      expect(res.summary!.manualReviewDocs, 0);
      expect(res.summary!.healthyDocIds, ['d1']);
      // dry-run 既定 — 書き込み JSON は生成しない
      expect(res.outputJson, isNull);
    });

    test('[C14] truncate 候補があっても 引数なし(dry-run) のとき outputJson は null（書き込み禁止契約）', () {
      // Critic ISSUE-C1 の根因「dry-run のはずが書き込む事故」を runner 層でも閉じる。
      // parseBackfillCliFlags が正しくても runner が outputJson を返してしまえば
      // 呼び出し側が誤って書き戻す事故が起きるため、runner 層で null 担保する。
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1', 'u2', 'u3'], votes: 2)],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>[]);

      expect(res.exitCode, 0);
      expect(res.summary!.truncateDocs, 1);
      expect(res.summary!.truncateDocIds, ['d1']);
      expect(res.outputJson, isNull, reason: 'dry-run では書き込み JSON を生成してはならない');
    });

    test('[C15-1] `--apply` 指定 — truncate doc は voters[0:votes] に切り詰めた JSON が outputJson に出る', () {
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1', 'u2', 'u3'], votes: 2)],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>['--apply']);

      expect(res.exitCode, 0);
      expect(res.outputJson, isNotNull);

      final out = jsonDecode(res.outputJson!) as Map<String, dynamic>;
      final outDocs = out['docs'] as List;
      expect(outDocs.length, 1);
      final outDoc0 = outDocs.first as Map<String, dynamic>;
      expect(outDoc0['id'], 'd1');
      final outData0 = outDoc0['data'] as Map<String, dynamic>;
      final outCand0 = (outData0['candidates'] as List).first as Map<String, dynamic>;
      // voters は votes 個に切り詰め
      expect(outCand0['voters'], ['u1', 'u2']);
      // votes は信頼ソースなので不変
      expect(outCand0['votes'], 2);
    });

    test('[C15-2] `--apply` 指定 — manualReview doc は 1 バイト不変で outputJson に出る（偽票方向の改竄禁止）', () {
      // current_task.md C3:「voters.size() < votes は機械的に votes を下げない」
      // この契約は --apply モードでも維持されることを runner で固定する。
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 5)],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>['--apply']);

      expect(res.exitCode, 0);
      expect(res.summary!.manualReviewDocs, 1);
      expect(res.summary!.manualReviewDocIds, ['d1']);
      expect(res.outputJson, isNotNull);

      final out = jsonDecode(res.outputJson!) as Map<String, dynamic>;
      final outDoc0 = (out['docs'] as List).first as Map<String, dynamic>;
      final outData0 = outDoc0['data'] as Map<String, dynamic>;
      final outCand0 = (outData0['candidates'] as List).first as Map<String, dynamic>;
      // 元の voters / votes が完全保存される
      expect(outCand0['voters'], ['u1']);
      expect(outCand0['votes'], 5);
    });

    test('[C15-3] `--apply` 指定 — healthy / truncate / manualReview 混在ファイルでも各 doc の方針通り出力される', () {
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'B', voters: ['u2', 'u3', 'u4'], votes: 2)],
        },
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'C', voters: ['u5'], votes: 9)],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>['--apply']);

      expect(res.exitCode, 0);
      expect(res.summary!.healthyDocs, 1);
      expect(res.summary!.truncateDocs, 1);
      expect(res.summary!.manualReviewDocs, 1);

      final out = jsonDecode(res.outputJson!) as Map<String, dynamic>;
      final outDocs = out['docs'] as List;
      expect(outDocs.length, 3);

      // d1: healthy → 不変
      final cand0 = (((outDocs[0] as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0['voters'], ['u1']);
      expect(cand0['votes'], 1);

      // d2: truncate → ['u2', 'u3'] に切り詰め
      final cand1 = (((outDocs[1] as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['candidates'] as List).first as Map<String, dynamic>;
      expect(cand1['voters'], ['u2', 'u3']);
      expect(cand1['votes'], 2);

      // d3: manualReview → 不変
      final cand2 = (((outDocs[2] as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['candidates'] as List).first as Map<String, dynamic>;
      expect(cand2['voters'], ['u5']);
      expect(cand2['votes'], 9);
    });

    test('[C12-2] 不正 JSON 入力 — exitCode != 0 / 例外は外に漏らさず stderr に理由を載せる', () {
      final res = runBackfillCli(inputJson: 'this is not json', args: const <String>[]);

      expect(res.exitCode, isNot(0));
      expect(res.outputJson, isNull);
      expect(res.stderr, isNotEmpty);
    });

    test('[C12-3] `docs` キー欠損 — exitCode != 0 で停止（黙って空サマリーを返さない）', () {
      // 欠損したまま空サマリー (totalDocs=0) を返すと、運用者は「対象ゼロだから安全」
      // と誤解して rules を deploy する。明示的に失敗させる。
      final res = runBackfillCli(
        inputJson: jsonEncode(<String, dynamic>{'foo': 'bar'}),
        args: const <String>[],
      );

      expect(res.exitCode, isNot(0));
      expect(res.stderr, isNotEmpty);
    });

    test('[C12-4] `--apply` と `--dry-run` 同時指定 — exitCode != 0 で stderr に ArgumentError 理由', () {
      // parseBackfillCliFlags が ArgumentError を投げる前提を runner レイヤーで
      // 「外部に漏らさず exitCode 化」する契約を固定。CLI 利用者は exit code で判定する。
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
      ]);

      final res = runBackfillCli(
        inputJson: input,
        args: const <String>['--apply', '--dry-run'],
      );

      expect(res.exitCode, isNot(0));
      expect(res.stderr, isNotEmpty);
    });

    test('[C12-5] BackfillCliResult は exitCode / summary / outputJson / stderr を public で公開する', () {
      // 構造ガード: rename / private 化 / 型変更を契約違反として検出する。
      final input = mkInput([
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
      ]);
      final res = runBackfillCli(inputJson: input, args: const <String>[]);

      expect(res, isA<BackfillCliResult>());
      expect(res.exitCode, isA<int>());
      expect(res.summary, isA<BackfillSummary?>());
      expect(res.outputJson, isA<String?>());
      expect(res.stderr, isA<String>());
    });
  });

  group('CLI shell file structure (Cycle 42 / C13, C17)', () {
    test('[C13] tools/backfill_voting_sessions.dart は依存追加ゼロ（dart:io / dart:convert / 内部 logic のみ import）', () {
      // CLAUDE.md「依存追加禁止」整合を構造担保する。
      // 将来うっかり package:firebase_admin など外部 dep を引き込んだら fail する。
      final f = File('tools/backfill_voting_sessions.dart');
      expect(
        f.existsSync(),
        isTrue,
        reason: 'tools/backfill_voting_sessions.dart が未作成 — Cycle 42 deploy ブロッカー',
      );

      final src = f.readAsStringSync();
      final imports = RegExp(r"^\s*import\s+'([^']+)';", multiLine: true)
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();

      const allowedExact = <String>{'dart:io', 'dart:convert'};
      const allowedPrefix = <String>['package:mannaka/tools/'];

      final disallowed = <String>[];
      for (final imp in imports) {
        if (allowedExact.contains(imp)) continue;
        if (allowedPrefix.any(imp.startsWith)) continue;
        disallowed.add(imp);
      }

      expect(
        disallowed,
        isEmpty,
        reason:
            'tools/backfill_voting_sessions.dart は dart:io / dart:convert / package:mannaka/tools/* のみ import 可。\n'
            '違反 import:\n${disallowed.map((i) => '  $i').join('\n')}',
      );
    });

    test('[C17] tools/backfill_voting_sessions.dart は `void main(List<String> args)` を持つ実行可能エントリポイント', () {
      // smoke: ファイルがあるだけでなく `dart run tools/backfill_voting_sessions.dart`
      // が成立する形（main シグネチャ）になっていることを確認。
      final f = File('tools/backfill_voting_sessions.dart');
      expect(f.existsSync(), isTrue);

      final src = f.readAsStringSync();
      // `Future<void> main(List<String> args)` も許容する。
      final hasMain = RegExp(
        r'(?:Future<void>|void)\s+main\s*\(\s*List<String>\s+\w+\s*\)',
      ).hasMatch(src);

      expect(
        hasMain,
        isTrue,
        reason:
            'tools/backfill_voting_sessions.dart に `void main(List<String> args)` または '
            '`Future<void> main(List<String> args)` が必要（CLI 実行エントリ）',
      );
    });

    test('[C17] CLI shell は runBackfillCli を呼び出して結果を stdout に出すだけの薄い層であること（直接 classifyDoc を再実装していない）', () {
      // 再実装による分岐ロジック分散を構造的に防ぐ。
      // Cycle 41 で確立した classifyDoc / applyDocPlan / summarize / parseBackfillCliFlags は
      // shell 側で再実装されてはならない（テスト不能領域に分類ロジックが流出するため）。
      final f = File('tools/backfill_voting_sessions.dart');
      expect(f.existsSync(), isTrue);

      final src = f.readAsStringSync();
      expect(
        src.contains('runBackfillCli'),
        isTrue,
        reason: 'CLI shell は runBackfillCli を経由して logic にアクセスすること',
      );

      // 分類ロジックのキーワードが shell 内で再宣言されていないことを軽く確認
      expect(
        RegExp(r'\bBackfillAction\s*\.\s*truncate\b').hasMatch(src),
        isFalse,
        reason:
            'CLI shell が BackfillAction.truncate を直接参照している。'
            '分類は logic 層に集約し、shell は runBackfillCli の結果のみを扱うこと。',
      );
    });
  });
}
