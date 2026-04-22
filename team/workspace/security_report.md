セキュリティレビューを `team/workspace/security_report.md` に出力しました。

## 判定: **WARNING**

**CRITICAL**: なし

**WARNING**（ISSUE 行あり）:
1. `saved_drafts_screen.dart:82-98` — `public_shares` へ書き込むユーザー入力が無検証（文字数/件数の上限なし、`firestore.rules` 側も未制約）
2. `saved_drafts_screen.dart:89` — 「保存→あとから送る」フロー追加により、参加者名が公開 Firestore（`allow read: if true`）に送信される経路が増加
3. `saved_share_drafts_provider.dart:13-29` — `build()` 内 `_load()` fire-and-forget により、読み込み完了前の `add()` で既存下書きを空配列で上書きするレース（データ損失）

**INFO**:
- 公開URL `https://mannnaka.web.app`（"n" 3つ）のドメイン綴り要確認
- APIキー直書き・`http://`・debugPrint での機密漏洩・SharedPreferences の機密保存・テスト内の個人情報 いずれも検出なし
- `.gitignore` と `git ls-files` の突き合わせで `secrets.dart` / `Secrets.xcconfig` / `firebase_options.dart` のトラッキング対象外を確認済み
