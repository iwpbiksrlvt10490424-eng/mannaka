Cycle 42 Green 完了。

## Summary
- Red 14 ケース全て pass（runner 9 / shell 構造 3 / W-1 セキュリティ 2）
- 全 suite: `+632 ~3: All tests passed!`
- `flutter analyze`: `No issues found!`

## Changed files
- `lib/tools/voting_sessions_backfill_logic.dart` — `BackfillCliResult` + `runBackfillCli` 追記、`dart:convert` import
- `tools/backfill_voting_sessions.dart` — 新規 CLI shell（依存追加ゼロ）
- `lib/services/rating_enrichment_service.dart:265` — `$e` → `${e.runtimeType}`（W-1 carry-over 終止）

## Why this approach
- runner を logic 層に置くことで shell は 60 行未満の純粋 I/O 配線に保てる（C13・C17 構造担保）
- dry-run 既定 / `--apply` 時のみ `outputJson` 生成 → 「dry-run のはずが書き込む」事故を runner レイヤーで閉じる
- 例外は exitCode 化し外部に漏らさない（運用者は exit code で判定）

## Risks / Follow-ups
- C18 運用 5 段は shell 冒頭コメントに明記。実 Firestore JSON 変換スクリプト本体は依存追加ゼロ維持のため別運用
- W-1 終止確認は QA 再点検でセキュリティレポートを更新する必要あり
