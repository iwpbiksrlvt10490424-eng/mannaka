Cycle 45 を本日のタスクとして選定しました。

## 選定: Cycle 45 — Cycle 44 Critic carry-over 一括解消（テスト 2 ファイルのみ）

**理由**:
- Cycle 1（本日 07:00-07:09）で Cycle 44 が QA APPROVED → 残課題は Critic carry-over の **ISSUE-C1（CLI shell テストが CWD 暗黙仮定）** と **WARNING-C2（mutation 検出 regex がネスト generic 取りこぼし）** の 2 件
- いずれも「テスト fragility」で、Cycle 43〜44 で築いた安全網に穴を残したまま新サイクルに進むと、特定起動方法でしか効かない「見せかけの緑」になるリスクがある
- 実装本体・CLI shell・`pubspec.yaml` を触らない軽量サイクル（テスト 2 ファイル修正のみ）
- 高優先度バックログの open 項目は運用系（support メール受信確認・App Store スクリーンショット・ポリシー URL 確定）のみで、コーディング自律サイクルには適合しない

**バックログ更新**:
- Cycle 44 → `[✅]`（QA APPROVED 注記付き）
- Cycle 45 → `[🚧]` 新規追加

`current_task.md` に受け入れ条件・技術的アプローチ・完了基準を記載済み。次フェーズ（architect-lead → TDD Tester → Engineer）に進めます。
