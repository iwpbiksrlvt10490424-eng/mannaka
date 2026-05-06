Cycle 42 の Critic レビューを完了。

## 判定: ISSUES_FOUND

**主要指摘 (review_feedback.md)**:

- **ISSUE-R1 (MED)**: `runBackfillCli` の例外境界が不完全。top-level の JSON parse 失敗は catch するが、`classifyDoc` の hard cast (`cand as Map<String, dynamic>` `voters.cast<String>()`) で起きる per-doc TypeError が runner を素通しで CLI shell まで漏出する。test [C12-2] の「例外で潰さない」契約から外れる。修正案: per-doc ループを `try/on TypeError` で囲み、docId 付き stderr を返す。
- **ISSUE-R2 (LOW)**: `{"docs": []}` 入力で exitCode=0 が返り、運用者が「対象ゼロだから安全」と誤解する導線。stderr に warning 推奨。
- **ISSUE-R3 (LOW)**: `stdout.writeln` で末尾 LF が付く。`gcloud firestore import` が strict なら拒否される可能性。

**良い点**: dry-run の二重封じ ([C14])、import allowlist + 再実装ガード ([C13]/[C17])、W-1 修正の確認 (`\$e\b` 0 件)。

**Red 抜け穴**: Cycle 41 で挙げた **ISSUE-T1**（型不正ペイロード）の Red が未追加。ISSUE-R1 と直結する穴のため、次 Red で契約化すべき。

`flutter analyze` 0 issues、Cycle 42 範囲のスコープ自体は完了。
