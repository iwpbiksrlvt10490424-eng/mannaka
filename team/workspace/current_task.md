---

## 今日のタスク: Cycle 34

**ダークモード残件修正 — navigationBarTheme 補完 & border 色修正**

### 選定理由

| 理由 | 内容 |
|------|------|
| Critic 残件 | Cycle 33 APPROVED 後も 2件の指摘が未解消 |
| ブランド崩れ | ダークモードでナビバーのアイコン/ラベルが Material3 デフォルト色にフォールバックする |
| 高優先度はブロック中 | App Store URL・Google Maps APIキー・メール設定は全て外部依存待ち |
| 最小変更・低リスク | `lib/theme/app_theme.dart` のみ修正で完結 |

### 修正対象（2件）

| # | 重要度 | 問題 | 修正方針 |
|---|--------|------|---------|
| 1 | 中 | `dark()` の `navigationBarTheme` に `labelTextStyle`・`iconTheme` 欠落 | light() と同構造で、unselected に `Colors.white70` 等のダーク色を使う |
| 2 | 軽 | `border`/`enabledBorder` が `fillColor`（`darkSurface`）と同色で不可視 | `AppColors.darkBorder = Color(0xFF3A3A3C)` を追加して置換 |

`current_task.md` 保存済み、バックログを `[🚧]` Cycle 34 に更新済みです。
