# まんなかアプリ バックログ

> 優先度: 🔴高 / 🟡中 / 🟢低
> ステータス: [ ] 未着手 / [🚧] 進行中 / [✅] 完了

---

## 🔴 高優先度

- [ ] **App Store URL修正** — `settings_screen.dart` の `id000000000` を実際のApp IDに変更（リリースブロッカー）
- [ ] **Google Maps APIキー本番化** — `ios/Runner/Info.plist` のキーを本番用に差し替え
- [ ] **support@mannaka.app 受信確認** — メール設定を確認してサポートメールが届くことを確認
- [✅] **flutter analyze 完全クリーン化** — 現在のwarning/infoをすべて0にする
- [✅] **flutter test 全パス確認** — 既存テストが全て通ることを確認し、不足テストを追加

## 🟡 中優先度

- [✅] **Foursquare APIキー安全化** — `api_config.dart` のハードコードを `secrets.dart` 経由に移行（実装確認済み）
- [✅] **オフライン時のエラーハンドリング改善** — ネットワーク未接続時にクラッシュしないことを確認・改善
- [✅] **検索履歴のUI改善** — 履歴画面のUXを整理（スワイプ削除+AppBarクリアで実装済みを確認）
- [✅] **レストランカード写真フォールバック** — 写真URLが取得できない場合のグラデーション背景を統一（Cycle 2完了）
- [✅] **Cycle 2 指摘バグ修正** — use-after-dispose クラッシュ・Controller dispose漏れ・URLスキーム検証（Cycle 3完了）
- [ ] **パフォーマンス最適化** — 地図画面のフレームレート計測と改善
- [✅] **アクセシビリティ対応** — VoiceOver/TalkBackの基本対応（重要ボタンのsemanticLabel追加）
- [✅] **Critic/Security 指摘修正** — TDD違反(buildGoogleMapsRouteUrl テスト追加)・疑似Divider除去・_ReserveButton http許容修正（2026-03-19 Cycle 3完了）
- [✅] **Cycle 3 残件修正** — 絵文字アイコン違反(地図マーカー)・_NearbyResultsSheet mounted クラッシュリスク・$e 生ログ4箇所（2026-03-19 Cycle 4完了）
- [✅] **Cycle 4 残件修正** — voting_screen mounted 順序バグ・log_masking 偽グリーン・restaurant_map/share_preview 絵文字違反・analytics_service $e ログ8箇所（2026-03-19 Cycle 5完了）
- [✅] **Cycle 5 残件修正** — share_preview SnackBar生例外・restaurant_map リテラル絵文字4箇所・emoji_icon_rule偽グリーン・ColoredBox疑似Divider・voting_screen到達不能コード・ranking_screen $eログ（2026-03-19 Cycle 6完了）
- [✅] **Cycle 6 残件修正** — voting_screen 疑似Divider・null-safe cast・pseudo_divider偽グリーン・Firestore Security Rules未設定（2026-03-19 Cycle 7完了）
- [✅] **Cycle 7 残件修正** — firestore.rules コレクション名不一致・voting_screen mounted/null-safe・voting_service unsafe cast・location_sessions未定義（2026-03-19 Cycle 8完了）
- [✅] **Cycle 8 残件修正** — voting_screen votes null-unsafe キャスト4箇所・build()内副作用（2026-03-19 Cycle 9完了）
- [✅] **Cycle 9 残件修正** — voting_screen String null-unsafe キャスト2箇所・テスト偽グリーン修正・analyze 2件解消（2026-03-19 Cycle 10完了）
- [✅] **Cycle 10 残件修正** — voting_screen `e as Map` unsafe cast・as Map 静的検出テスト欠落・addPostFrameCallback重複登録（2026-03-19 Cycle 11〜12完了）
- [✅] **Voting機能セキュリティ強化** — Firestore Rules hostUid制限・voterName/hostName 50文字バリデーション・SECURITY.md陳腐化記載削除（2026-03-19 Cycle 13完了）
- [✅] **Cycle 13 残件修正** — hostUid空文字バグ(CRITICAL)・ArgumentError伝達漏れ・テスト偽グリーン修正・空文字バリデーション（2026-03-19 Cycle 14完了）
- [✅] **Cycle 14 残件修正** — Firestore Rules vote()阻害(CRITICAL)・未認証hostUid空文字バグ・偽グリーン解消・APIキー実値削除・location_sessions Rules制限（2026-03-19 Cycle 15完了）
- [✅] **Cycle 15 残件修正** — テスト偽グリーン解消(cycle13 Group1 Test1/2)・APIキー実値削除(cycle15_test:359)（2026-03-19 Cycle 16完了）
- [✅] **Cycle 16 残件修正** — LocationSession ownerUid欠落(本番CRITICAL)・cycle16_test `'A'*40` 無効構文・cycle13_test allow write フォールバック偽グリーン（2026-03-19 Cycle 17完了）
- [✅] **Cycle 17 残件修正** — search_screen mounted バグ・エラー詳細UI露出・location_session_service テスト追加（2026-03-23 Cycle 18 APPROVED）
- [✅] **Cycle 19 残件修正** — visited/reserved_restaurants_provider debugPrint $e 6箇所・main.dart Firebase $e 1箇所・share_utils/settings_screen App Store URLプレースホルダー（2026-03-24 Cycle 19完了）
- [✅] **Cycle 20 残件修正** — restaurant_detail_screen ColoredBox疑似Divider3箇所(テスト失敗ブロッカー)・restaurant_cache_service/$search_provider $e残存3箇所・share_preview_screen URL・settings_screen LINE sharePositionOrigin（2026-03-24 Cycle 20 APPROVED）
- [✅] **Cycle 21 残件修正** — _PhotoCarousel placeholder Container(color:)→BoxDecoration修正(latent design_rules_test失敗)・settings_screen 友達に教えるボタンasync gap修正（2026-03-24 Cycle 21完了）
- [✅] **パフォーマンス最適化（Cycle 22）** — scoreRestaurants 再計算キャッシュ実装（2026-03-24 Cycle 22 APPROVED）
- [✅] **Cycle 22 残件修正** — sortedRestaurants キャッシュ・icon getter 絵文字除去・フィルタ変更再計算テスト（Cycle 23完了 2026-03-24）
- [✅] **パフォーマンス最適化（地図画面）** — restaurant_map_screen のフレームレート計測・RepaintBoundary/キャッシュ適用（Cycle 24 APPROVED）
- [✅] **Cycle 24 残件修正** — restaurant_map `'?'` UIテキスト違反（CLAUDE.md ルール）→ `Icons.person` に置き換え（Cycle 25 完了）
- [✅] **Cycle 26: share_utils sharePositionOrigin 修正 + materialIcon デッドコード削除** — `share_utils.dart` の iPad クラッシュリスク解消・`SortOptionExt.materialIcon` 未使用 getter 削除（2026-03-24 Cycle 26 APPROVED）
- [✅] **Cycle 27: share_preview_screen `Share.share()` await 追加** — `onPressed` を async 化し `await` 追加でシェアシート安定化（Critic Cycle 26 WARNING-2 解消）
- [✅] **Cycle 28: share_preview_screen アバター `'?'` 禁止文字修正** — `name` が空の場合のフォールバック文字 `'?'` を Material Icon に置き換え（Critic Cycle 27 WARNING-2 解消）
- [✅] **Cycle 29: share_preview_screen_cycle28_test テスト設計修正** — テスト2の文字距離 regex（400字制限）を除去し `dart format` 耐性を持たせる（Critic Cycle 28 ISSUE-1 解消）
- [✅] **Security WARNING 修正: テストの Hotpepper APIキー実値除去** — `voting_security_cycle18_test.dart:161` の APIキー実値 → 構造パターン正規表現に置換（Cycle 31 完了 2026-03-24）
- [✅] **Cycle 32: share_preview_screen トグルラベル旧表記除去** — `share_preview_screen.dart:347` `代替案①②をシェアテキストに追加` → `代替案をシェアテキストに追加`（Critic Cycle 30 ISSUE High 解消 2026-03-24）

## 🟢 低優先度

- [ ] **TestFlight配布準備** — 社内テスター向けTestFlight設定
- [ ] **App Store スクリーンショット作成** — 6.7インチ・6.1インチ用スクリーンショット準備
- [ ] **プライバシーポリシーURL確定** — 実際のホスティング先URLに更新
- [ ] **まんちゃんアニメーション追加** — マスコットに新しいアニメーションパターンを追加
- [✅] **シェア機能のテンプレート改善** — シェアテキストをより魅力的に（Cycle 30完了 2026-03-24）
- [🚧] **ダークモード残件修正（Cycle 34）** — `AppTheme.dark()` の `navigationBarTheme` に `labelTextStyle`・`iconTheme` 補完 & `inputDecorationTheme` border 色修正（`darkSurface` と同色で不可視 → `darkBorder` に変更）（Cycle 33 Critic ISSUE 1・2 解消中）

---

## 完了済み

<!-- 完了したタスクはここに移動 -->

---

_最終更新: 自律開発チームが自動管理_
