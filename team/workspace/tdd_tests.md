Cycle 43 Red 完了。

## Summary
- 新規 Red 13 ケース作成（C19〜C25）— `test/tools/backfill_voting_sessions_logic_cycle43_test.dart`
- 12 件 Red（9 件は実 TypeError 漏出を再現、3 件は hard cast 構造ガード）/ 1 件 Green（C22 votes double — 既存実装が偶発通過、回帰契約として保持）
- ISSUE-R1 (MED) と ISSUE-T1 (Cycle 41 carry-over) を同 commit で潰せる契約セットが揃った

## 主要な失敗
- C19/C19-2: `lib/tools/voting_sessions_backfill_logic.dart:76` `as Map<String, dynamic>` で TypeError
- C20/C20-2: 同 L96 `cand['voters'] as List` で TypeError
- C21/C21-2: 同 L96 `.cast<String>()` lazy cast → L107 iteration で TypeError
- C23: `candidates` キー欠損が healthy 判定される契約違反
- C24/C24-2: `runBackfillCli` E2E で 1 件型不正が全停止させる ISSUE-R1 本丸を再現
- C25-1/2/3: hard cast / lazy cast 残存の構造ガード（再発防止）

詳細・修正方針は `team/workspace/tdd_tests.md` に記載。次は feature-implementer が `classifyDoc` の hard cast 3 箇所を `is` ガード経由に書き換えれば全 Green。
