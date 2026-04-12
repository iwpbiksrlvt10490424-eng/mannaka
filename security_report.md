# セキュリティレビュー

**日時**: 2026-04-10（5回目）
**対象変更**: ブランドリネーム（Aima/Aimachi → まんなか）全UI文言 / ホーム駅座標ロジック改善 / シェアテキスト刷新 / バージョン 1.0.1+3
**レビュアー**: Claude (Security Agent)

## 判定: WARNING

---

### CRITICAL（即時修正必須）

なし

---

### WARNING（修正推奨）

#### ISSUE-W3: `main.dart` L44, L55 — 不正な sessionId の生値をログ出力（継続）

- **ファイル**: `lib/main.dart` Lines 44, 55
- **内容**: Deep link で不正な `sessionId` が渡された場合、攻撃者制御のraw文字列を `debugPrint` に渡している
  ```dart
  debugPrint('Deep link: 不正な sessionId を無視: $sessionId');
  ```
- **リスク**: Release ビルドでは `debugPrint` は no-op だが、Debug/Profile ビルドでは任意長の攻撃者入力がログに出力される
- **修正案**: `$sessionId` を除去し固定メッセージのみにする、または切り詰め
- 対応優先度: **低**（Release ビルドでは影響なし）

#### ISSUE-W4: HTTPレスポンスボディの debugPrint 出力（3サービス・継続）

- **ファイル**:
  - `lib/services/hotpepper_service.dart` L54
  - `lib/services/foursquare_service.dart` L45
  - `lib/services/overpass_service.dart` L43
- **内容**: non-200レスポンス時に `res.body.substring(0, min(200, ...))` をログ出力。エラーレスポンスにサーバー内部情報が含まれる可能性がある
- **リスク**: Release ビルドでは `debugPrint` は no-op のため実害なし。Debug ビルドではサーバーのエラー詳細がログに記録される
- **修正案**: `debugPrint('[Service] HTTP ${res.statusCode}');` のみにし、body出力を削除
- 対応優先度: **低**

#### ISSUE-W5: プライバシーポリシー 第3条に Foursquare / Overpass API の記載なし（継続）

- **ファイル**: `lib/screens/policy_screen.dart` L50-62
- **内容**: 第3条（第三者サービスへの情報提供）に Hotpepper と Firebase のみ記載されているが、実際には以下にも位置情報（緯度経度）を送信している:
  - **Foursquare Places API v3** (`lib/services/foursquare_service.dart` L26): `ll=$lat,$lng` をクエリパラメータで送信
  - **Overpass API (OpenStreetMap)** (`lib/services/overpass_service.dart` L22): `around:$radiusMeters,$lat,$lng` をPOSTボディで送信
- **リスク**: App Store審査およびプライバシー法令（個人情報保護法・GDPR等）でデータ送信先の開示不足と判断される可能性
- **修正案**: 第3条に Foursquare, Overpass (OpenStreetMap) の2サービスを追加
- 対応優先度: **中**

#### ISSUE-W6: プライバシーポリシー 第4条 SharedPreferences の記述が不正確（継続）

- **ファイル**: `lib/screens/policy_screen.dart` L70
- **内容**: 「端末内データはOSが提供するセキュアな保存領域（Keychain/SharedPreferences）を使用します」と記載されているが、iOSの `SharedPreferences` は `NSUserDefaults` であり Keychain ではない。暗号化されていないプレーンテキスト保存領域
- **リスク**: 誤った安全性の説明は消費者保護法上の問題になりうる。ただし保存データ自体は低機密（ニックネーム・駅情報・匿名ID）
- **修正案**: 「端末内のアプリ固有ストレージ（SharedPreferences/NSUserDefaults）」に修正するか、`flutter_secure_storage`（Keychain/Keystore利用）に実際に移行する
- 対応優先度: **低〜中**

---

### 解消済み ISSUE

#### ~~ISSUE-W1~~: `voting_security_cycle16_test.dart` Foursquare APIキー実値 → **解消済み**

- 2026-03-19 指摘。現在はキー実値が RegExp パターン `[A-Z0-9]{40,}` に置換済みを確認

#### ~~ISSUE-W2~~: `search_screen.dart` エラー詳細 `$e` のUI露出 → **解消済み**

- 2026-03-19 指摘。現在は固定メッセージに修正済みを確認

---

### INFO（今回の変更範囲）

#### INFO-1: ブランドリネーム（Aima → まんなか）にセキュリティリスクなし

14の lib/ ファイルと2つの test/ ファイルで UI表示テキストを `Aima`/`Aimachi` → `まんなか` に置換。コード識別子（`AimachiApp` クラス名等）は変更なし。

| 変更パターン | 確認結果 |
|---|---|
| `MaterialApp title` / スプラッシュ / ホーム画面ロゴ | 表示文字列のみ。機密情報なし |
| ランキング画面（指数名・説明・ハッシュタグ・フッター） | `#Aima` → `#まんなか`。機密情報なし |
| ポリシー・規約ヘッダー・本文 | `Aima` → `まんなか`。法的記載の名称変更のみ |
| シェアテキスト・LINE紹介・その他共有CTA | 下記 INFO-2 参照 |

#### INFO-2: シェアテキスト刷新のセキュリティ確認

- `settings_screen.dart`: LINE紹介テキストに `ShareUtils.appStoreUrl`（`https://apps.apple.com/...`）を追加。HTTPS のみ
- `settings_screen.dart`: `Share.share()` テキストにも同URL追加。`sharePositionOrigin` 設定済み（iOS必須）
- `share_utils.dart`: `appStoreUrl` は固定 HTTPS URL。ユーザー入力の注入なし
- `settings_screen.dart`: mailto URL が `Aima` → `まんなか`（URL エンコード済み `%E3%81%BE%E3%82%93%E3%81%AA%E3%81%8B`）
- LINE共有: `Uri.encodeComponent(text)` でテキスト全体をエンコード済み。インジェクション安全

#### INFO-3: ホーム駅座標ロジック改善にセキュリティリスクなし

- `home_screen.dart` L136-148, `settings_screen.dart` L62-73: kStations外の駅で prefs の座標（Geocoding API補正済み）を優先するロジック追加
- 入力ソースは SharedPreferences（アプリ自身が保存した値）のみ。外部入力なし
- `isRealKIndex` フラグで kStations 配列の範囲チェック済み

#### INFO-4: 既存セキュリティ対策の確認（変更なし・正常動作中）

| チェック項目 | 結果 |
|---|---|
| `secrets.dart` が git 未追跡 | PASS — `git ls-files` 空結果 |
| `firebase_options.dart` が git 未追跡 | PASS — `git ls-files` 空結果 |
| `.gitignore` に `lib/config/secrets.dart` 記載 | PASS — L1 |
| APIキー参照は `ApiConfig` → `secrets.dart` 経由のみ | PASS |
| lib/ 内に `http://` URL なし | PASS |
| Deep link sessionId バリデーション | PASS — `[A-HJ-NP-Z2-9]{6}` パターン |
| Deep link voterName サニタイゼーション | PASS — 制御文字除去 + 20文字制限 |
| Deep link restaurant フィールドサニタイゼーション | PASS — 制御文字除去 + 文字数制限 + 座標範囲検証 |
| Deep link URL スキーム検証 | PASS — `https://` のみ許可 |
| SharedPreferences に機密情報なし | PASS — ニックネーム・駅情報・匿名IDのみ |
| debugPrint でエラーは `${e.runtimeType}` のみ | PASS（W3, W4 を除く） |
| Analytics はオプトイン制 | PASS — `isOptedIn()` チェック済み |
| Foursquare APIキーは Authorization ヘッダー経由 | PASS — URL非露出 |
| テストファイルにAPIキー・個人情報なし | PASS |
| Overpass API クエリインジェクション | PASS — 型システムで数値制約 |

---

### チェックリスト結果

| 項目 | 結果 |
|---|---|
| APIキーがソースコードに直書きされていない | PASS `secrets.dart`（gitignore済み）経由のみ |
| `secrets.dart` がコミット対象になっていない | PASS `git ls-files` で確認済み |
| HTTPS のみ使用 | PASS lib/ 全ファイルで http:// なし |
| ユーザー入力をそのまま外部APIに渡していない | PASS sanitize/encode/範囲検証実装済み |
| ログに機密情報が出力されていない | WARNING W3: sessionId生値、W4: レスポンスbody（Release無害） |
| SharedPreferences に機密情報を保存していない | PASS ニックネーム・駅情報・匿名IDのみ |
| Firebase Security Rules | 未確認（サーバー側設定のため本レビュー対象外） |
| テストコードにAPIキー・個人情報が含まれていない | PASS 実値除去確認済み |

---

### 次回対応推奨（優先度順）

1. **中**: プライバシーポリシー第3条に Foursquare / Overpass を追加（W5）
2. **低〜中**: プライバシーポリシー第4条の SharedPreferences/Keychain 記述修正（W6）
3. **低**: `main.dart` L44, L55 の sessionId ログ出力を固定メッセージに変更（W3）
4. **低**: 3サービスの debugPrint からレスポンスbody出力を削除（W4）
5. **中**: `anon_user_id` を `flutter_secure_storage` に移行検討

---

### チェック実施記録

| 日付 | 実施者 | 変更内容 | 問題発見 |
|------|--------|----------|---------|
| 2026-04-10 | Claude (Security Agent) | ブランドリネーム Aima→まんなか / ホーム駅座標改善 / シェアテキスト刷新 / v1.0.1+3 | 新規問題なし / W3・W4・W5・W6継続 |
| 2026-04-10 | Claude (Security Agent) | Bundle ID変更・表示名変更・PrivacyInfo.xcprivacy新規作成 | 新規問題なし / W3・W4・W5・W6継続 |
| 2026-04-09 | Claude (Security Agent) | meeting_point_card 絵文字→Icon / スコアリング改善・UI統一 | 新規 W5（ポリシー第3条不備）・W6（ポリシー第4条不正確）/ W3・W4継続 |
| 2026-04-09 | Claude (Security Agent) | scene_area_screen 絵文字UIアイコン削除 | 新規問題なし / W3・W4継続 |
| 2026-04-09 | Claude (Security Agent) | Divider→SizedBox・SizedBox統合・UI統一等 | 新規W4（レスポンスbodyログ）/ W3継続 / W1・W2解消確認 |
| 2026-03-30 | Claude (Security Agent) | ダークモード対応・スクリーン群・テスト追加 | 新規問題なし |
| 2026-03-26 | Claude (Security Agent) | 有楽町線グラフ補完 + 重複排除閾値修正 | 新規問題なし |
| 2026-03-19 | Claude (Security Agent) | Cycle 17 Green フェーズ | W1: テストにAPIキー実値 / W2: エラー詳細UI露出 |
