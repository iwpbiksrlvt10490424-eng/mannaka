Green フェーズ完了です。

## Summary

### 変更ファイル
- **`lib/theme/app_theme.dart`** — 3箇所修正:
  1. `AppColors.darkBorder = Color(0xFF3A3A3C)` を追加
  2. `dark()` の `inputDecorationTheme` の `border`/`enabledBorder` を `darkSurface` → `darkBorder` に変更
  3. `dark()` の `navigationBarTheme` に `labelTextStyle`（unselected: `Colors.white70`）と `iconTheme`（unselected: `Colors.white70`）を追加

- **`test/theme/dark_mode_cycle34_test.dart`** — テストの検出ロジック修正:
  - `),\n` での早期ブロック切り出しが `WidgetStateProperty.resolveWith(...)` の `}),\n` に先にヒットする問題を修正。`navBarBlock` / `borderBlock` / `enabledBlock` への切り出しをやめ、`afterNavBar` / `borderSnippet` / `afterEnabled` から直接 `contains` するよう変更。

### 結果
- `flutter test test/theme/dark_mode_cycle34_test.dart`: **8/8 全パス**
- `flutter test` 全体: **失敗 0 件**
- `flutter analyze`: **No issues found!**
