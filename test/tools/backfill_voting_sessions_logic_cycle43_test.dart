// TDD Red フェーズ — Cycle 43:
//   `classifyDoc` の per-doc TypeError 漏出を `manualReview` に倒す契約 (C19〜C25)
//   を Red で固定する。
//
// 背景（current_task.md / 2026-05-01）:
//   Cycle 42 Critic ISSUE-R1 (MED): `lib/tools/voting_sessions_backfill_logic.dart`
//     L76 `candidates[i] as Map<String, dynamic>` (hard cast)
//     L96 `(cand['voters'] as List).cast<String>()` (lazy cast)
//   が runner を素通しで CLI shell まで TypeError を漏出させる。
//   1 件型不正で `dart run tools/backfill_voting_sessions.dart` が exit 1 全停止し、
//   backfill 運用が release blocker のまま残る。
//   同 root cause で Cycle 41 Critic ISSUE-T1（型不正 Red 未契約）も carry-over。
//
// このファイルが固定する契約:
//   C19 候補非 Map         → manualReview 分類 / TypeError 漏出禁止 / applyDocPlan 1 byte 不変
//   C20 voters 非 List      → manualReview 分類 / TypeError 漏出禁止 / applyDocPlan 1 byte 不変
//   C21 voters 要素非 String → manualReview 分類 / TypeError 漏出禁止 / applyDocPlan 1 byte 不変
//   C22 votes double        → manualReview 分類 / TypeError 漏出禁止 / applyDocPlan 1 byte 不変
//   C23 candidates キー欠損 → manualReview 分類 / 例外なく素通し
//   C24 混合 doc E2E        → runBackfillCli が exit 0 で完走 / 不正 doc は manualReview 計上
//   C25 hard cast 残存構造ガード → logic 層 src に `as Map<String, dynamic>` /
//                                  `cast<String>` が残っていないこと（再発防止）
//
//   公開 API (`classifyDoc` / `applyDocPlan` / `runBackfillCli`) のシグネチャは不変。
//   CLI shell (`tools/backfill_voting_sessions.dart`) も無変更が前提。

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

  group('classifyDoc per-doc 型不正の manualReview 倒し (Cycle 43 / C19〜C23)', () {
    test('[C19] candidates 要素が Map でない (String 混入) — TypeError 漏出禁止 / manualReview 分類', () {
      // 現状 L76 `candidates[i] as Map<String, dynamic>` が hard cast のため
      // 'broken' は TypeError を投げて runner を素通しで CLI shell まで漏出する。
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          'broken', // String 混入: そもそも候補オブジェクトですらない
        ],
      };

      // 例外を投げず DocBackfillPlan を返すこと
      final plan = classifyDoc('docC19', doc);

      expect(plan.docId, 'docC19');
      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.length, 1);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.candidateIndex, 0);
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      // applyDocPlan は 1 byte 不変で素通す
      final applied = applyDocPlan(doc, plan);
      expect((applied['candidates'] as List).first, 'broken');
    });

    test('[C19-2] candidates 要素が Map<dynamic, dynamic> (Map<String, dynamic> ではない) — manualReview に固定', () {
      // Cycle 44 ISSUE-Q1: 旧 Red は `anyOf(healthy, truncate, manualReview)` で
      // 何でも合格させていたため、誤って healthy 側に倒す変更が入っても検出できなかった。
      // Firestore 由来の Map<dynamic, dynamic> は型情報が落ちているため、
      // 値の意味的健全性を判定できない（key/value の型保証がない）。
      // 安全側に倒して manualReview 固定にし、運用者に明示的に拾わせる契約に締める。
      final dynMap = <dynamic, dynamic>{
        'id': 'A',
        'voters': <String>['u1'],
        'votes': 1,
      };
      final doc = <String, dynamic>{
        'candidates': <dynamic>[dynMap],
      };

      // ここで TypeError が漏れたら fail
      final plan = classifyDoc('docC19-2', doc);

      expect(plan.docId, 'docC19-2');
      // 例外を投げない + manualReview 固定（healthy / truncate は契約違反）
      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.length, 1);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.candidateIndex, 0);
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      // applyDocPlan は 1 byte 不変で素通す（Map<dynamic, dynamic> の identity を壊さない）
      final applied = applyDocPlan(doc, plan);
      expect((applied['candidates'] as List).first, same(dynMap));
    });

    test('[C20] voters が List でない (String 値) — TypeError 漏出禁止 / manualReview 分類', () {
      // 現状 L96 `cand['voters'] as List` が hard cast のため、
      // voters が String の場合 TypeError を投げる。
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': 'u1', // 文字列 — List ではない
            'votes': 1,
          },
        ],
      };

      final plan = classifyDoc('docC20', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      final applied = applyDocPlan(doc, plan);
      final cand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0['voters'], 'u1'); // 1 byte 不変
      expect(cand0['votes'], 1);
    });

    test('[C20-2] voters が Map (List ではない) — TypeError 漏出禁止 / manualReview 分類', () {
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': <String, dynamic>{'0': 'u1'}, // Map — List ではない
            'votes': 1,
          },
        ],
      };

      final plan = classifyDoc('docC20-2', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.truncatedVoters, isNull);
    });

    test('[C21] voters 要素に非 String (int) が混入 — TypeError 漏出禁止 / manualReview 分類', () {
      // 現状 L96 `(cand['voters'] as List).cast<String>()` は lazy cast のため、
      // List<dynamic> = ['u1', 42] の `.cast<String>()` 自体は通るが、
      // L107 `voters.any((v) => v.isEmpty)` の iteration で TypeError が漏出する。
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': <dynamic>['u1', 42], // int 混入
            'votes': 2,
          },
        ],
      };

      final plan = classifyDoc('docC21', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      // 機械的に「非 String voter を削って整合させる」のは禁止
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      final applied = applyDocPlan(doc, plan);
      final cand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0['voters'], <dynamic>['u1', 42]); // 1 byte 不変
      expect(cand0['votes'], 2);
    });

    test('[C21-2] voters 要素に null が混入 — TypeError 漏出禁止 / manualReview 分類', () {
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': <dynamic>['u1', null], // null 混入
            'votes': 2,
          },
        ],
      };

      final plan = classifyDoc('docC21-2', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.truncatedVoters, isNull);
    });

    test('[C22] votes が double (2.0) — manualReview 分類 / 1 byte 不変', () {
      // C9 では String 型 votes を扱うが double は別軸（int でない数値型）。
      // 現状の `votesRaw is! int` 判定で manualReview に落ちるが、契約として
      // 明示的に固定しないと後で int を許容する誤った緩和が入った時に検出できない。
      final doc = <String, dynamic>{
        'candidates': <dynamic>[
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': <String>['u1', 'u2'],
            'votes': 2.0, // double — int ではない
          },
        ],
      };

      final plan = classifyDoc('docC22', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      final applied = applyDocPlan(doc, plan);
      final cand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0['voters'], <String>['u1', 'u2']);
      expect(cand0['votes'], 2.0); // 1 byte 不変
    });

    test('[C23] `candidates` キー自体が欠損 — 例外なく manualReview 分類', () {
      // 現状 L72 `(doc['candidates'] as List?) ?? const <dynamic>[]` で
      // 空配列扱いになり healthy 判定される。これは「対象ゼロだから安全」
      // という誤った安心感を与える（C5 の `candidates: []` とは異なり、
      // キー自体の欠損はスキーマ崩壊の兆候であり手動レビュー対象）。
      final doc = <String, dynamic>{
        // 'candidates' キーなし
        'createdAt': '2026-05-01T00:00:00Z',
      };

      final plan = classifyDoc('docC23', doc);

      // キー欠損は手動レビュー対象（運用者に明示的に拾わせる）
      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate, isEmpty);

      // applyDocPlan は doc を 1 byte 不変で素通す
      final applied = applyDocPlan(doc, plan);
      expect(applied.containsKey('candidates'), isFalse);
      expect(applied['createdAt'], '2026-05-01T00:00:00Z');
    });
  });

  group('runBackfillCli E2E with mixed broken docs (Cycle 43 / C24)', () {
    String mkInput(List<Map<String, dynamic>> docs) {
      return jsonEncode(<String, dynamic>{
        'docs': [
          for (var i = 0; i < docs.length; i++)
            {'id': 'd${i + 1}', 'data': docs[i]},
          ],
      });
    }

    test('[C24] 健全 / truncate / manualReview / 型不正 が混在しても CLI が exit 0 で完走し、不正 doc は manualReview 計上', () {
      // ISSUE-R1 の本丸契約: 1 件型不正で全停止せず、不正 doc は manualReview に
      // 倒して残りを処理しきる。これで運用者は dry-run summary を信頼できる。
      final input = mkInput([
        // d1: healthy
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
        // d2: truncate
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'B', voters: ['u2', 'u3', 'u4'], votes: 2)],
        },
        // d3: manualReview (voters.size() < votes)
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'C', voters: ['u5'], votes: 9)],
        },
        // d4: 候補が String — 型不正
        <String, dynamic>{
          'candidates': <dynamic>['broken'],
        },
        // d5: voters が String — 型不正
        <String, dynamic>{
          'candidates': <dynamic>[
            <String, dynamic>{
              'id': 'E',
              'name': 'Restaurant E',
              'category': 'cafe',
              'priceStr': '~¥1000',
              'address': 'Tokyo',
              'imageUrl': '',
              'voters': 'u1',
              'votes': 1,
            },
          ],
        },
        // d6: voters 要素に int 混入 — 型不正
        <String, dynamic>{
          'candidates': <dynamic>[
            <String, dynamic>{
              'id': 'F',
              'name': 'Restaurant F',
              'category': 'cafe',
              'priceStr': '~¥1000',
              'address': 'Tokyo',
              'imageUrl': '',
              'voters': <dynamic>['u1', 42],
              'votes': 2,
            },
          ],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>[]);

      expect(res.exitCode, 0, reason: '型不正 doc が混在しても CLI は exit 0 で完走する');
      expect(res.summary, isNotNull);
      expect(res.summary!.totalDocs, 6);
      expect(res.summary!.healthyDocs, 1);
      expect(res.summary!.truncateDocs, 1);
      // manualReview: d3 (過小 voters) + d4/d5/d6 (型不正) = 4 件
      expect(res.summary!.manualReviewDocs, 4);
      expect(res.summary!.healthyDocIds, ['d1']);
      expect(res.summary!.truncateDocIds, ['d2']);
      expect(res.summary!.manualReviewDocIds, ['d3', 'd4', 'd5', 'd6']);
      // dry-run 既定 — 書き込み JSON は生成しない
      expect(res.outputJson, isNull);
    });

    test('[C24-2] `--apply` 指定時も型不正 doc は 1 byte 不変で素通し、healthy/truncate のみ正規化される', () {
      final input = mkInput([
        // d1: truncate
        <String, dynamic>{
          'candidates': [mkCandidate(id: 'A', voters: ['u1', 'u2', 'u3'], votes: 2)],
        },
        // d2: voters が String — 型不正
        <String, dynamic>{
          'candidates': <dynamic>[
            <String, dynamic>{
              'id': 'B',
              'name': 'Restaurant B',
              'category': 'cafe',
              'priceStr': '~¥1000',
              'address': 'Tokyo',
              'imageUrl': '',
              'voters': 'u1',
              'votes': 1,
            },
          ],
        },
      ]);

      final res = runBackfillCli(inputJson: input, args: const <String>['--apply']);

      expect(res.exitCode, 0);
      expect(res.outputJson, isNotNull);

      final out = jsonDecode(res.outputJson!) as Map<String, dynamic>;
      final outDocs = out['docs'] as List;
      expect(outDocs.length, 2);

      // d1: truncate → ['u1', 'u2'] に切り詰め
      final cand0 = (((outDocs[0] as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0['voters'], ['u1', 'u2']);
      expect(cand0['votes'], 2);

      // d2: 型不正 → manualReview として 1 byte 不変
      final cand1 = (((outDocs[1] as Map<String, dynamic>)['data']
          as Map<String, dynamic>)['candidates'] as List).first as Map<String, dynamic>;
      expect(cand1['voters'], 'u1'); // 不変
      expect(cand1['votes'], 1);
    });
  });

  group('hard cast 残存構造ガード (Cycle 43 / C25)', () {
    test('[C25] lib/tools/voting_sessions_backfill_logic.dart に `as Map<String, dynamic>` の hard cast が残っていない (classifyDoc 経路)', () {
      // 再発防止: ISSUE-R1 の root cause は L76 `candidates[i] as Map<String, dynamic>`。
      // applyDocPlan は事前に classifyDoc 通過済み doc にのみ適用されるため
      // hard cast が残っていても安全だが、classifyDoc / _classifyCandidate 経路の
      // hard cast は今後も禁止する。ここでは「ファイル全体での発生回数」で
      // ゆるく構造ガードする（applyDocPlan の cast 1〜2 箇所までは許容）。
      final f = File('lib/tools/voting_sessions_backfill_logic.dart');
      expect(f.existsSync(), isTrue);

      final src = f.readAsStringSync();
      final hardCastCount = RegExp(r'as\s+Map<String,\s*dynamic>')
          .allMatches(src)
          .length;

      // applyDocPlan 内の `Map<String, dynamic>.from(... as Map<String, dynamic>)` 1 箇所のみ
      // 許容する（applyDocPlan は classifyDoc 通過済み doc にのみ呼ばれるため安全）。
      // 2 箇所以上なら classifyDoc / _classifyCandidate 経路に hard cast が残っている。
      expect(
        hardCastCount,
        lessThanOrEqualTo(1),
        reason:
            '`as Map<String, dynamic>` が $hardCastCount 箇所残っている。\n'
            'classifyDoc / _classifyCandidate 内の hard cast は TypeError 漏出の根因。\n'
            'is チェック → manualReview に倒す形へ書き換えること。\n'
            '（applyDocPlan の Map<String, dynamic>.from cast 1 箇所のみ許容）',
      );
    });

    test('[C25-2] lib/tools/voting_sessions_backfill_logic.dart に `.cast<String>()` の lazy cast が残っていない', () {
      // 再発防止: L96 `(cand['voters'] as List).cast<String>()` は lazy cast。
      // 後段 iteration で TypeError が出る。voters 要素検査は明示的な型ガードに置き換える。
      final f = File('lib/tools/voting_sessions_backfill_logic.dart');
      expect(f.existsSync(), isTrue);

      final src = f.readAsStringSync();
      final lazyCast = RegExp(r"\.cast<\s*String\s*>\s*\(\s*\)").hasMatch(src);

      expect(
        lazyCast,
        isFalse,
        reason:
            '`.cast<String>()` (lazy cast) が残っている。\n'
            '後段 iteration で TypeError が漏出する根因のため、\n'
            '`voters.every((v) => v is String)` の事前ガードに置き換えること。',
      );
    });

    test('[C25-3] lib/tools/voting_sessions_backfill_logic.dart に `as List` / `as List<...>` の hard cast が classifyDoc 経路に残っていない', () {
      // L96 `cand['voters'] as List` も voters 非 List 時に TypeError を投げる。
      // applyDocPlan 内の `doc['candidates'] as List` (L162) は classifyDoc 通過済み
      // doc にのみ適用されるため 1 箇所のみ許容。それ以上は classifyDoc 経路の
      // hard cast 残存とみなす。
      //
      // Cycle 44 WARNING-Q4: 旧 regex `as\s+List(?!\?)(?!<)` は generic 付きを
      // 取りこぼし、`as List<dynamic>` への退化（hard cast 再混入）を検出できなかった。
      // generic 形式も hard cast である事実は変わらないため、同列に扱う。
      // ただし nullable 形式 (`as List?` / `as List<X>?`) は安全なので除外する。
      final f = File('lib/tools/voting_sessions_backfill_logic.dart');
      expect(f.existsSync(), isTrue);

      final src = f.readAsStringSync();
      // `as List` または `as List<...>` で末尾に `?` が付かないものを数える。
      // 二択構造で書く理由: 単純な `as\s+List(?:<[^>]*>)?(?!\?)` は
      // `as List<X>?` で optional group をバックトラック放棄して `as List` 部分にマッチしてしまう
      // （nullable なのに hard cast と誤検出される）。
      // 「generic 付きで非 nullable」/「bare で非 nullable かつ generic 開始でない」の
      // 二択を明示することでバックトラック誤検出を排除する。
      final hardListCastRe = RegExp(
        r'as\s+List(?:<[^>]*>(?!\?)|(?![<\?]))',
      );
      final hardListCast = hardListCastRe.allMatches(src).length;

      expect(
        hardListCast,
        lessThanOrEqualTo(1),
        reason:
            '`as List` / `as List<...>` (non-nullable hard cast) が $hardListCast 箇所残っている。\n'
            'classifyDoc / _classifyCandidate 経路では `is List` ガード経由に書き換えること。\n'
            '（applyDocPlan の `doc[\'candidates\'] as List` 1 箇所のみ許容）',
      );
    });

    test('[C25-3-mutation] hard cast regex 自体の判定能力検証 (誤検出 / 取りこぼし耐性)', () {
      // Cycle 44 WARNING-Q4 の根因: regex 自体の信頼性を契約として固定しないと、
      // 「regex を緩めれば検出を回避できる」抜け穴が残る。ここでは regex を
      // 既知の合成文字列に当て、検出/非検出の境界を明示する。
      final hardListCastRe = RegExp(
        r'as\s+List(?:<[^>]*>(?!\?)|(?![<\?]))',
      );

      // 検出されるべき（hard cast = 危険）
      const shouldMatch = <String>[
        r'final x = doc as List;',
        r'final x = doc as List<dynamic>;',
        r'final x = doc as List<String>;',
        r'final x = doc as List<Map<String, dynamic>>;',
        r'final x = doc  as   List ;', // 空白許容
      ];
      for (final s in shouldMatch) {
        expect(
          hardListCastRe.hasMatch(s),
          isTrue,
          reason: 'regex は hard cast「$s」を検出すべき',
        );
      }

      // 検出されないべき（nullable cast = 安全 / 無関係文字列）
      const shouldNotMatch = <String>[
        r'final x = doc as List?;',
        r'final x = doc as List<dynamic>?;',
        r'final x = doc as List<String>?;',
        r'final x = doc is List ? a : b;', // `is List` は別構文
        r'final x = passList(doc);', // 単に List という単語が現れるだけ
      ];
      for (final s in shouldNotMatch) {
        expect(
          hardListCastRe.hasMatch(s),
          isFalse,
          reason: 'regex は安全な「$s」を hard cast と誤検出してはならない',
        );
      }
    });
  });
}
