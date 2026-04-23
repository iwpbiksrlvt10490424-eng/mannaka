タスク選定完了。

**選定タスク: Cycle 16 — `saved_share_drafts_provider` 要素単位 try/catch + `saved_drafts_screen` エラーUI分離**

## サマリ
- Cycle 15（`AsyncNotifier` 化レース修正）は QA APPROVED + Security PASS 済 → `backlog.md` で `[✅]` に確定
- Cycle 15 Critic が指摘した **ISSUE 2（既存バグ）= `build()` の try/catch が配列全体を包むため 1 件破損で全件消失** をリリースブロッカー級 UX バグとして選定（候補保存データの全消失は LINE 共有前のユーザー操作を無効化するため）
- 同じファイル群を触る Critic **ISSUE 1（エラー UI と空状態が同一）** も同サイクルでまとめて解消
- スコープ外: ISSUE 3（`add`/`remove` 並行レース）は別 ADR 案件として保留

## 受け入れ条件 6 項目
要素単位 try/catch、全件破損→空配列、全件正常→順序維持、`developer.log` 診断、エラー UI 専用ウィジェット、空/エラーの Widget 区別

## 次工程
`current_task.md` に技術アプローチ・新規テスト 5 ケース・完了基準を記載済み。次は **architect-lead → TDD Tester（Red）→ feature-implementer（Green）→ Critic → Security → QA** の順に回してください。
