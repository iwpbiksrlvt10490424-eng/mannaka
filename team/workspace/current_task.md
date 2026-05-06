Cycle 43 を本日のタスクとして確定。`current_task.md` 更新済み・バックログは Cycle 42 → `[✅]` / Cycle 43 → `[🚧]` に反映。

## 選定: Cycle 43 — `classifyDoc` の per-doc TypeError 漏出を `manualReview` に倒す

### 選定理由（最優先 = backfill 運用 release blocker）
- Cycle 42 で CLI shell + W-1 carry-over は終止（test 632 pass / analyze 0 / Security PASS）
- ただし Critic **ISSUE-R1 (MED)**: `lib/tools/voting_sessions_backfill_logic.dart:76` `as Map<String, dynamic>` と `:96` `cast<String>()` lazy が runner を素通し → 1 件型不正で CLI shell が exit 1 全停止
- 同 root cause で Cycle 41 Critic **ISSUE-T1**（型不正 Red 未契約）も carry-over → 同 commit で潰す
- Critic ISSUE-R2 (LOW: 空 docs warning) / ISSUE-R3 (LOW: stdout LF) はスコープ外（次 cycle 以降）

### 受け入れ条件（C19〜C25）
候補非 Map / voters 非 List / voters 要素非 String / votes double / candidates キー欠損 / 混合 doc E2E / hard cast 残存構造ガード — 新規 `test/tools/backfill_voting_sessions_logic_cycle43_test.dart` に集約。公開 API（`classifyDoc` / `runBackfillCli`）不変・CLI shell 無変更・`pubspec.yaml` 差分ゼロ厳守。

次は TDD Tester に C19〜C25 の Red を起こさせる。
