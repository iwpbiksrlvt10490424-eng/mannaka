// TDD Red フェーズ — Cycle 41: voting_sessions deploy 前 backfill ロジックの
// 純粋関数層 `lib/tools/voting_sessions_backfill_logic.dart` を契約として固定する。
//
// 背景（Cycle 40 Critic HIGH — release blocker）:
//   firestore.rules branch (b) が deploy された瞬間、
//   `voters.size() != votes` のレガシー doc は update 永久 deny に陥り、
//   投票機能がサイレント停止する。deploy 前に既存 doc を正規化する必要がある。
//
//   PM 規約ベース判断（current_task.md / 2026-05-01）:
//     Q1 = A（Dart 純粋関数 + CLI 分離）
//     Q2 = X（voters を [0:votes] に切り詰め、votes は信頼ソース）
//     Q3 = dry-run 既定 / `--apply` で実行
//     Q4 = deploy gate は実装後の運用判断（Red 設計の前提条件ではない）
//
//   ※ Q2 = X は本番投票履歴に直接影響するため、Green 着手前に
//     ユーザー明示承認が必要（current_task.md L19-20 に明記）。
//     本ファイルは「承認が降りたときに通すべき契約」を Red で先に固定する。
//
// このファイルの責務:
//   - C1〜C7 の境界値で `classifyDoc` / `applyDocPlan` / `summarize` の
//     振る舞いを実行時に固定する（Red 時点では production 未実装のため
//     全テストがコンパイル不能 or NoSuchMethodError で fail する）。
//   - 「C3 は自動修正せず手動レビュー対象として分類のみ」を機械担保する
//     （current_task.md L15-16）。`applyDocPlan` が manualReview を含む doc
//     を 1 バイト不変で素通すことを assert する。

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

  group('voting_sessions_backfill_logic', () {
    test('[C1] 健全 doc — 全候補で voters.size() == votes のとき BackfillAction.healthy になる', () {
      final doc = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1', 'u2'], votes: 2),
          mkCandidate(id: 'B', voters: ['u3'], votes: 1),
          mkCandidate(id: 'C', voters: const <String>[], votes: 0),
        ],
      };

      final plan = classifyDoc('doc1', doc);

      expect(plan.docId, 'doc1');
      expect(plan.action, BackfillAction.healthy);
      expect(plan.perCandidate.length, 3);
      expect(
        plan.perCandidate.map((c) => c.action).toList(),
        [BackfillAction.healthy, BackfillAction.healthy, BackfillAction.healthy],
      );

      // applyDocPlan は健全 doc を 1 バイト不変で返す
      final applied = applyDocPlan(doc, plan);
      expect(applied, equals(doc));
    });

    test('[C2] 過剰 voters — voters.size() > votes のとき truncate 分類で voters[0:votes] に切り詰められる', () {
      final doc = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1', 'u2', 'u3'], votes: 2),
        ],
      };

      final plan = classifyDoc('doc2', doc);

      expect(plan.action, BackfillAction.truncate);
      expect(plan.perCandidate.first.action, BackfillAction.truncate);
      expect(plan.perCandidate.first.candidateIndex, 0);
      expect(plan.perCandidate.first.originalVotersSize, 3);
      expect(plan.perCandidate.first.targetVotes, 2);
      expect(plan.perCandidate.first.truncatedVoters, ['u1', 'u2']);

      final applied = applyDocPlan(doc, plan);
      final appliedCand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      expect(appliedCand0['voters'], ['u1', 'u2']);
      expect(appliedCand0['votes'], 2);

      // 入力 doc は破壊されない（純粋関数）
      final origCand0 = (doc['candidates'] as List).first as Map<String, dynamic>;
      expect(origCand0['voters'], ['u1', 'u2', 'u3']);
      expect(origCand0['votes'], 2);
    });

    test('[C3] 過小 voters — voters.size() < votes は manualReview 分類のみ。applyDocPlan しても 1 バイト不変', () {
      final doc = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1'], votes: 5),
        ],
      };

      final plan = classifyDoc('doc3', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      // 機械的に votes を voters.size() に下げる「偽票方向の正規化」を禁ずる
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      final applied = applyDocPlan(doc, plan);
      final appliedCand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      expect(appliedCand0['voters'], ['u1']); // 元のまま
      expect(appliedCand0['votes'], 5); // 元のまま
    });

    test('[C4] 候補単位の混在 — truncate のみの doc は違反候補のみ切り詰め、健全候補は不変', () {
      final doc = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1', 'u2'], votes: 2), // healthy
          mkCandidate(id: 'B', voters: ['u3', 'u4', 'u5'], votes: 1), // truncate
          mkCandidate(id: 'C', voters: ['u6'], votes: 0), // truncate (over by 1)
        ],
      };

      final plan = classifyDoc('doc4', doc);

      expect(plan.action, BackfillAction.truncate); // doc 全体 worst-case
      expect(plan.perCandidate[0].action, BackfillAction.healthy);
      expect(plan.perCandidate[1].action, BackfillAction.truncate);
      expect(plan.perCandidate[1].truncatedVoters, ['u3']);
      expect(plan.perCandidate[2].action, BackfillAction.truncate);
      expect(plan.perCandidate[2].truncatedVoters, const <String>[]);

      final applied = applyDocPlan(doc, plan);
      final cands = applied['candidates'] as List;
      expect((cands[0] as Map)['voters'], ['u1', 'u2']); // 健全候補不変
      expect((cands[0] as Map)['votes'], 2);
      expect((cands[1] as Map)['voters'], ['u3']);
      expect((cands[1] as Map)['votes'], 1);
      expect((cands[2] as Map)['voters'], const <String>[]);
      expect((cands[2] as Map)['votes'], 0);
    });

    test('[C5] candidates が空 — `candidates: []` の doc は BackfillAction.healthy で perCandidate も空', () {
      final doc = <String, dynamic>{'candidates': const <Map<String, dynamic>>[]};

      final plan = classifyDoc('doc5', doc);

      expect(plan.action, BackfillAction.healthy);
      expect(plan.perCandidate, isEmpty);

      final applied = applyDocPlan(doc, plan);
      expect(applied, equals(doc));
    });

    test('[C6] manualReview 混在 doc — 同 doc 内に truncate と manualReview があるとき doc 全体は manualReview 扱いで applyDocPlan は 1 バイト不変', () {
      final doc = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1', 'u2', 'u3'], votes: 2), // truncate 単独なら自動修正候補
          mkCandidate(id: 'B', voters: ['u4'], votes: 5), // manualReview
        ],
      };

      final plan = classifyDoc('doc6', doc);

      // doc 内に 1 つでも manualReview 候補があれば doc 全体は手動レビューに昇格する
      // （current_task.md 受け入れ条件 C3:「機械的に偽票方向の改竄を許可しない」を
      //   doc 単位でも厳守する。truncate 候補だけ部分修正すると、同 doc の整合性が
      //   検証されないまま rules 側 update が通る恐れがあり危険）
      expect(plan.action, BackfillAction.manualReview);

      // perCandidate 自体は実態を保持する（CLI が手動レビュー時のリストを出すため）
      expect(plan.perCandidate[0].action, BackfillAction.truncate);
      expect(plan.perCandidate[1].action, BackfillAction.manualReview);

      // applyDocPlan は doc 全体が manualReview のとき何も変えない
      final applied = applyDocPlan(doc, plan);
      final cands = applied['candidates'] as List;
      expect((cands[0] as Map)['voters'], ['u1', 'u2', 'u3']);
      expect((cands[0] as Map)['votes'], 2);
      expect((cands[1] as Map)['voters'], ['u4']);
      expect((cands[1] as Map)['votes'], 5);
    });

    test('[C7] summarize — DocBackfillResult のリストから件数 + 各分類 docId リストを返す', () {
      // Critic ISSUE-T4: 件数だけでは「どの doc を CLI が手動レビューに回すか」を
      // 機械担保できない。docId リストも返すことを契約に固定する。
      final docs = <Map<String, dynamic>>[
        {
          'candidates': [mkCandidate(id: 'A', voters: ['u1'], votes: 1)],
        },
        {
          'candidates': [mkCandidate(id: 'B', voters: const <String>[], votes: 0)],
        },
        {
          'candidates': [mkCandidate(id: 'C', voters: ['u2', 'u3'], votes: 1)],
        },
        {
          'candidates': [mkCandidate(id: 'D', voters: ['u4'], votes: 9)],
        },
      ];
      final results = [
        for (var i = 0; i < docs.length; i++) classifyDoc('d${i + 1}', docs[i]),
      ];

      final s = summarize(results);

      expect(s.totalDocs, 4);
      expect(s.healthyDocs, 2);
      expect(s.truncateDocs, 1);
      expect(s.manualReviewDocs, 1);

      // docId リスト：分類ごとに対象 doc が一意に並ぶ
      expect(s.healthyDocIds, ['d1', 'd2']);
      expect(s.truncateDocIds, ['d3']);
      expect(s.manualReviewDocIds, ['d4']);
    });

    test('[C8] 旧スキーマ — `voters` キー欠損は manualReview 分類で applyDocPlan は 1 バイト不変', () {
      // Critic ISSUE-T1: 古い doc には `voters` フィールドがない可能性がある。
      // 機械的に votes と整合させようがないため manualReview に倒し、CLI は
      // 1 バイト不変で素通す（手動運用に委ねる）契約を Red で固定する。
      final doc = <String, dynamic>{
        'candidates': [
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            // 'voters' キー自体が欠落
            'votes': 3,
          },
        ],
      };

      final plan = classifyDoc('docC8', doc);

      expect(plan.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.action, BackfillAction.manualReview);
      expect(plan.perCandidate.first.truncatedVoters, isNull);

      final applied = applyDocPlan(doc, plan);
      final cand0 = (applied['candidates'] as List).first as Map<String, dynamic>;
      // `voters` キーは導入されない（勝手に空配列を作って整合扱いするのは禁止）
      expect(cand0.containsKey('voters'), isFalse);
      expect(cand0['votes'], 3);
    });

    test('[C9] 旧スキーマ — `votes` が null / 異常型 (String) のとき manualReview で applyDocPlan は 1 バイト不変', () {
      // Critic ISSUE-T1/T3: votes が null や非 int のとき NoSuchMethodError や
      // TypeError でクラッシュさせない契約を Red で固定する。
      final docNull = <String, dynamic>{
        'candidates': [
          <String, dynamic>{
            'id': 'A',
            'name': 'Restaurant A',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': const <String>['u1'],
            'votes': null,
          },
        ],
      };

      final planNull = classifyDoc('docC9-null', docNull);
      expect(planNull.action, BackfillAction.manualReview);
      expect(planNull.perCandidate.first.action, BackfillAction.manualReview);
      expect(planNull.perCandidate.first.truncatedVoters, isNull);

      final appliedNull = applyDocPlan(docNull, planNull);
      final cand0Null = (appliedNull['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0Null['voters'], const <String>['u1']);
      expect(cand0Null['votes'], isNull);

      final docStr = <String, dynamic>{
        'candidates': [
          <String, dynamic>{
            'id': 'B',
            'name': 'Restaurant B',
            'category': 'cafe',
            'priceStr': '~¥1000',
            'address': 'Tokyo',
            'imageUrl': '',
            'voters': const <String>['u1', 'u2'],
            'votes': '2', // String 型混入
          },
        ],
      };

      final planStr = classifyDoc('docC9-str', docStr);
      expect(planStr.action, BackfillAction.manualReview);
      expect(planStr.perCandidate.first.action, BackfillAction.manualReview);
      expect(planStr.perCandidate.first.truncatedVoters, isNull);

      final appliedStr = applyDocPlan(docStr, planStr);
      final cand0Str = (appliedStr['candidates'] as List).first as Map<String, dynamic>;
      expect(cand0Str['voters'], const <String>['u1', 'u2']);
      expect(cand0Str['votes'], '2'); // 1 バイト不変
    });

    test('[C10] 重複 voter / 空文字 voter / votes < 0 は manualReview 分類で applyDocPlan 1 バイト不変', () {
      // Critic ISSUE-T2: 重複や空文字を CLI が黙って除去すると、
      // どのユーザーが何票投じたかの監査痕跡が壊れる。
      // 「除去するかしないか」は人間判断（運用ポリシー）に委ねるため manualReview。
      final docDup = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'A', voters: ['u1', 'u1', 'u2'], votes: 3),
        ],
      };
      final planDup = classifyDoc('docC10-dup', docDup);
      expect(planDup.action, BackfillAction.manualReview);
      expect(planDup.perCandidate.first.action, BackfillAction.manualReview);
      expect(planDup.perCandidate.first.truncatedVoters, isNull);

      final appliedDup = applyDocPlan(docDup, planDup);
      final candDup = (appliedDup['candidates'] as List).first as Map<String, dynamic>;
      expect(candDup['voters'], ['u1', 'u1', 'u2']);
      expect(candDup['votes'], 3);

      final docEmpty = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'B', voters: ['', 'u2'], votes: 2),
        ],
      };
      final planEmpty = classifyDoc('docC10-empty', docEmpty);
      expect(planEmpty.action, BackfillAction.manualReview);
      expect(planEmpty.perCandidate.first.truncatedVoters, isNull);
      final appliedEmpty = applyDocPlan(docEmpty, planEmpty);
      final candEmpty = (appliedEmpty['candidates'] as List).first as Map<String, dynamic>;
      expect(candEmpty['voters'], ['', 'u2']);
      expect(candEmpty['votes'], 2);

      final docNeg = <String, dynamic>{
        'candidates': [
          mkCandidate(id: 'C', voters: ['u1'], votes: -1),
        ],
      };
      final planNeg = classifyDoc('docC10-neg', docNeg);
      expect(planNeg.action, BackfillAction.manualReview);
      expect(planNeg.perCandidate.first.truncatedVoters, isNull);
      final appliedNeg = applyDocPlan(docNeg, planNeg);
      final candNeg = (appliedNeg['candidates'] as List).first as Map<String, dynamic>;
      expect(candNeg['voters'], ['u1']);
      expect(candNeg['votes'], -1);
    });
  });
}
