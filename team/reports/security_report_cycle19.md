# セキュリティレビュー — Cycle 19

**実施日**: 2026-03-24
**対象変更**: `implementation_notes.md` 記載の Cycle 19 Green フェーズ（7修正）

---

## 判定: WARNING

---

### CRITICAL（即時修正必須）

なし

---

### WARNING（修正推奨）

#### ISSUE-W1: `debugPrint` に生例外 `$e` が残存（Cycle 19 スコープ外）

Cycle 19 で対象7ファイルの修正は完了済み。ただし同様の問題が他ファイルに残存している。

| ファイル | 行 | 内容 |
|---|---|---|
| `lib/services/restaurant_cache_service.dart` | 39 | `debugPrint('RestaurantCacheService.get: $e')` |
| `lib/services/restaurant_cache_service.dart` | 55 | `debugPrint('RestaurantCacheService.set: $e')` |
| `lib/providers/search_provider.dart` | 526 | `debugPrint('prefetch: ${point.stationName} failed - $e')` |

**リスク**: `$e` は `Exception.toString()` を展開するため、スタックトレース・内部パス・データ構造がデバイスログに出力される。
**修正**: `$e` → `${e.runtimeType}` に統一する。

---

### INFO

#### Cycle 19 修正の確認結果（すべて PASS）

| チェック項目 | 結果 | 備考 |
|---|---|---|
| APIキー直書き | ✅ PASS | `secrets.dart` / `firebase_options.dart` とも `.gitignore` 対象 |
| `secrets.dart` コミット除外 | ✅ PASS | `.gitignore` 1行目に明記 |
| HTTPS のみ使用 | ✅ PASS | `http://` の使用なし。LINE共有も `https://line.me/...` |
| ユーザー入力サニタイズ | ✅ PASS | `main.dart`: `_sessionIdPattern`・`_sanitizeVoterName`・座標範囲バリデーション実装済み |
| Cycle 19 対象の `$e` → `${e.runtimeType}` | ✅ PASS | `visited_restaurants_provider`・`reserved_restaurants_provider`・`main.dart` 計7箇所修正済み |
| App Store URLプレースホルダー除去 | ✅ PASS | `share_utils.dart` / `settings_screen.dart` ともにTODOコメントアウト済み（実際の出力なし） |
| SharedPreferences に機密情報 | ✅ PASS | ニックネーム・ホーム駅・プロフィール画像パスのみ保存 |
| テストコードに機密情報 | ✅ PASS | `voting_security_cycle19_test.dart` にAPIキー・個人情報なし |

---

## 次のアクション

1. **ISSUE-W1** — `restaurant_cache_service.dart`（39, 55行）と `search_provider.dart`（526行）の `$e` を `${e.runtimeType}` に修正する（次Cycleに組み込み推奨）
