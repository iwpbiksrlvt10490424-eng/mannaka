`current_task.md` を更新しました。バックログの該当タスクはすでに `[🚧]` 状態です（前回セッションで設定済み）。

---

## 今日のタスク選定結果

**ダークモード残件修正（Cycle 34）**

### 選定理由

| 観点 | 内容 |
|------|------|
| 既着手 | Cycle 33 QA レビューで検出済みの2件 ISSUE が未解消のまま [🚧] |
| リリースブランド影響 | ダークモードでナビバーのアイコン/ラベルが Material3 デフォルト色にフォールバック → ブランド崩れ |
| 高優先度タスクはブロック中 | App Store URL・Google Maps APIキー・support メールはすべて外部依存待ちで着手不可 |
| 最小変更・低リスク | `lib/theme/app_theme.dart` 1ファイルのみで完結 |

### 修正対象（2件）

| # | ISSUE | 修正方針 |
|---|-------|---------|
| 1 | `navigationBarTheme` の `labelTextStyle`・`iconTheme` 欠落 | dark() に選択中/非選択の WidgetStateProperty を追加 |
| 2 | `inputDecorationTheme` の border が `darkSurface` と同色で不可視 | `AppColors.darkBorder = Color(0xFF3A3A3C)` を定義して置換 |

### 進め方
TDD (Red → Green → Refactor) で `test/theme/dark_theme_cycle34_test.dart` を先に書いてから実装します。
