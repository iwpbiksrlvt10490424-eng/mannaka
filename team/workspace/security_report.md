---

# セキュリティレビュー結果

**判定: PASS**

今回の変更（`lib/theme/app_theme.dart` のみ）は純粋な UI テーマ定義であり、セキュリティリスクなし。

| チェック項目 | 結果 |
|---|---|
| APIキー直書き | ✅ なし |
| secrets.dart gitignore | ✅ 確認済 |
| HTTPS のみ使用 | ✅ 通信処理なし |
| ユーザー入力の外部API直渡し | ✅ 該当なし |
| ログに機密情報 | ✅ なし |
| SharedPreferences に機密情報 | ✅ 該当なし |
| テストコードにAPIキー・個人情報 | ✅ なし |

変更内容は `AppColors.darkCardBg` 定数追加と `AppTheme.dark()` の ThemeData 拡張のみ。攻撃面の拡大ゼロ。`withValues(alpha:)` も正しく使用。

既知の継続リスク（本変更と無関係、SECURITY.md で管理中）:
- Foursquare APIキーのバックエンドプロキシ移行（高）
- Firebase Security Rules 設定（高）
- 本番 debugPrint 無効化（中）
