Red フェーズ完了です。

---

## 結果サマリー

**テストファイル**: `test/theme/dark_mode_cycle34_test.dart`  
**結果**: 8件 / 8件 Red（全て正しい理由で失敗）

| グループ | テスト数 | 失敗理由 |
|---------|---------|---------|
| navigationBarTheme — labelTextStyle | 2件 | `labelTextStyle` が `dark()` 内に未定義 |
| navigationBarTheme — iconTheme | 2件 | `iconTheme` が `dark()` 内に未定義 |
| AppColors.darkBorder 定数 | 2件 | `darkBorder` 定数が `AppColors` に未定義 |
| inputDecorationTheme border 色修正 | 2件 | `border`/`enabledBorder` が `darkSurface` のまま（`darkBorder` 未使用） |

## Engineer への引き継ぎ（Green にするための実装）

`lib/theme/app_theme.dart` のみ3箇所修正：

1. **`AppColors` に追加**: `static const Color darkBorder = Color(0xFF3A3A3C);`
2. **`dark()` の `navigationBarTheme` に追加**: `labelTextStyle`（unselected: `Colors.white70`）と `iconTheme`（unselected: `Colors.white70`）
3. **`dark()` の `inputDecorationTheme` を変更**: `border`/`enabledBorder` の `borderSide` を `darkSurface` → `darkBorder` に置換
