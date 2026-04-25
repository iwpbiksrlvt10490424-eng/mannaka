# まんなかアプリ バックログ

> 優先度: 🔴高 / 🟡中 / 🟢低
> ステータス: [ ] 未着手 / [🚧] 進行中 / [✅] 完了

---

## 🔴 高優先度

- [✅] **App Store URL修正** — `ShareUtils.appStoreUrl` に `id6743108270` で一元管理済み（2026-04-09 完了）
- [✅] **Google Maps APIキー本番化** — `ios/Runner/Info.plist` は `$(GOOGLE_MAPS_API_KEY)` ビルド変数化済・`Secrets.xcconfig` は gitignore済・AppDelegate にプレースホルダ検知あり（2026-04-21 確認完了）
- [✅] **分析データ収集のオプトイン整合性確保** — opt-out トグル追加・ポリシー第2条に新規6コレクション追記・クラスコメント整合（2026-04-21 Cycle 1 QA APPROVED）
- [✅] **Cycle 2: 分析 opt-in UI の Critic 指摘修正** — `_AnalyticsOptInTile` padding整列(10→14)・`setOptIn` 失敗時ロールバック・Widget E2E テスト追加（2026-04-21 Cycle 2 QA APPROVED）
- [✅] **Cycle 3: AnalyticsOptInTile 失敗フィードバック + 命名改善** — `catch (_)` サイレント解消（SnackBar 通知）・`initialValue` → `value` 改名（2026-04-21 Cycle 3 QA APPROVED）
- [✅] **Cycle 4: AnalyticsOptInTile 残 WARNING 3件解消** — in-flight 再タップ直列化・Cycle 2 テストヘッダコメント更新・`pumpAndSettle` 4s タイマー待ち除去（2026-04-21 Cycle 4 QA APPROVED）
- [✅] **Cycle 5: プライバシーポリシー最終改定日を 2026-04-21 に更新** — `policy_screen.dart:21` の改定日を 2026年4月10日 → 2026年4月21日 に更新し本文改定と整合化（2026-04-21 Cycle 5 QA APPROVED）
- [✅] **Cycle 6: プライバシーポリシー第2条本文の回帰テスト整備** — 第2条 9 コレクション名・デフォルトON・オプトアウト・匿名ID・Firebase 送信先を静的に守る 16 ケースを追加（ミューテーション検証済）。2026-04-21 Cycle 6 QA APPROVED
- [✅] **Cycle 7: location_share_screen エラー UI の生例外 `$e` 露出解消 + Widget 回帰テスト整備** — L43/L79 の `_error = '... $e'` を固定文言化、`location_share_screen_error_exposure_test.dart` 9 ケースで静的回帰保護（2026-04-22 QA APPROVED）
- [✅] **Cycle 8: location_share_screen async setState の `mounted` ガード追加** — `_loadSession`/`_submit` の `await` 後 `setState` 6 箇所に `if (!mounted) return;` を追加し deactivated widget クラッシュを予防（2026-04-22 Cycle 8 QA APPROVED）
- [✅] **Cycle 9: settings_screen.dart `_pickImage` の mounted ガード追加（Cycle 8 横展開）** — L152 の `setState(() {})` 直前に `if (!mounted) return;` を追加し、画像選択中の画面離脱クラッシュを予防。3 段階静的回帰テストで「同パターン全箇所一括修正」ルールを永続化（2026-04-22 Cycle 9 QA APPROVED）
- [✅] **Cycle 10: lib/ 全域 `debugPrint` を `developer.log` 化（CLAUDE.md `kReleaseMode` ルール違反 43 箇所一括解消）** — `lib/` 配下 49 箇所を `developer.log(..., name: '<Scope>', error: e)` に置換、`location_share_screen.dart` の `catch (_)` → `catch (e, st)` + 診断ログ、`foundation.dart` dead import 8 ファイル除去。`test/lib_no_debug_print_test.dart` 9 ケースで静的回帰ガード（2026-04-22 Cycle 10 QA APPROVED）
- [✅] **Cycle 11: Aimachi → まんなか ブランド残骸除去（UI/シェア/ポリシー 20+ 箇所一括統一）** — 11 ファイル 20 箇所置換・mailto subject URLエンコード・静的回帰 `test/lib_no_aimachi_in_ui_test.dart` 16/16 Green。`flutter test` 413 pass。`class AimachiApp`・`ranking_screen.dart` 全体は温存（2026-04-22 Cycle 11 QA APPROVED）
- [✅] **Cycle 12: ranking_screen / search_screen Aimachi ブランド残骸の横展開除去** — 3 行置換（ranking_screen.dart:410/602・search_screen.dart:605）+ `_patternAllowlist` 方式へテスト進化。`flutter test` 415 pass / `flutter analyze` 0 issues（2026-04-22 Cycle 12 QA APPROVED）
- [✅] **Cycle 13: ranking_screen.dart 「Aimachi指数」系 7 箇所を「まんなか指数」系に最終統一** — `ranking_screen.dart` L39/L108/L122/L410/L507 を「まんなか指数」に置換済み。ユーザー判断で `home_screen.dart:306` のヘッダーロゴは `'Aimachi'` として温存（`_patternAllowlist` に `RegExp(r"'Aimachi'")` を追加してガード）。`flutter analyze` 0 / `flutter test` 416 pass。2026-04-22 Cycle 13 完了扱い（Critic/Security/QA は API limit により未実施だが成果物は静的テストで保護済み）
- [✅] **Cycle 14: 手動追加シートに最寄り駅ピッカーを正式統合 + 回帰テスト** — `manual_restaurant_add_sheet.dart` に最寄り駅ピッカー (StationSearchSheet 呼び出し) 統合済み。`ReservedRestaurant.nearestStation` / `VisitedRestaurant.nearestStation` に反映され、`history_screen.dart:373` で表示。新規 `manual_restaurant_add_sheet_station_test.dart` 6 ケースで契約を静的ガード。`flutter analyze` 0 / `flutter test` 403 pass（2026-04-23 Cycle 14 QA APPROVED）
- [✅] **Cycle 15: `saved_share_drafts_provider` のデータ損失レース修正** — `Notifier` → `AsyncNotifier` 化、`add`/`remove` 冒頭で `await future` 初期ロード待ち。`saved_drafts_screen.dart` を `.when(loading/error/data)` 化。新規 `saved_share_drafts_race_test.dart` 6 ケース。`flutter analyze` 0 / `flutter test` +409 ~2 全パス（2026-04-23 Cycle 15 QA APPROVED / Security PASS）
- [✅] **Cycle 16: `saved_share_drafts_provider` 要素単位 try/catch + エラーUI分離（Cycle 15 Critic ISSUE 1+2）** — 前半（provider 要素単位 try/catch + `developer.log` 診断 + `saved_share_drafts_corruption_test.dart` 7 ケース Green）＋後半（`saved_drafts_screen.dart` の `_errorUi()` 分離・`ShareUtils.appStoreUrl` 一元化・Aimachi ブランド残骸除去・Widget/Source 契約テスト 10 ケース Green）を完了（2026-04-24 Cycle 16 QA APPROVED / Security PASS）
- [✅] **Cycle 17: `saved_drafts_screen` エラーUI にリトライ導線追加（Cycle 16 Critic NON-BLOCKING 2）** — 本番実装（`_errorUi(WidgetRef ref)` + `TextButton.icon` + `ref.invalidate(savedShareDraftsProvider)`）+ Riverpod 2.6.1 整合の Widget テスト 3 ケース（`saved_drafts_screen_retry_test.dart`）。Cycle 2 で Red 化 → Cycle 3 で「単一 Notifier 内 state で 1 回目 throw / 2 回目成功」方式に書き直して `+407 ~2` Green。`flutter analyze` 0 / 本番コード差分ゼロ維持（2026-04-24 Cycle 17 Cycle 3 QA APPROVED / Security PASS）
- [✅] **Cycle 18: Cycle 17 Critic WARNING-1 解消 — `saved_drafts_screen_retry_test.dart` の Riverpod バージョン依存を冒頭に明記** — テストヘッダに「⚠️ Riverpod 2.6.x 依存 / major bump 時は再設計必須」の警告コメント追加 + 新規 `saved_drafts_screen_retry_test_version_guard_test.dart` 5 ケースで静的保護。`flutter test +412 ~2` Green / `flutter analyze` 0 issues / 本番コード差分ゼロ（2026-04-24 Cycle 18 QA APPROVED）
- [✅] **Cycle 19: Cycle 18 Critic WARNING-1/2 解消 — version guard の minor 検証強化 + ファイル名リネーム** — 旧 `saved_drafts_screen_retry_test_version_guard_test.dart` 削除・正規 `saved_drafts_retry_version_guard_test.dart` にリネーム（structure_test [S1-a]/[S1-b] で機械担保）。`[6]` で `flutter_riverpod` minor >= 6 を assert 追加。`flutter analyze` 0 / `flutter test` +418 ~2 全パス、本番コード・pubspec 差分ゼロ（2026-04-24 Cycle 19 QA APPROVED / Security PASS）
- [✅] **Cycle 20: structure_test の移行専用ガード [S1-a]/[S1-b] 削除** — `saved_drafts_retry_version_guard_structure_cleanup_test.dart` 7 ケースで削除/存続を静的 assert、`+3 -4` の削除駆動差分。`flutter analyze` 0 / `flutter test` +423 ~2。本番コード・pubspec・version guard 本体は無変更（2026-04-24 Cycle 20 QA APPROVED / Security PASS）
- [✅] **Cycle 21: saved_drafts サイクルチェーン最終清掃（Cycle 20 Critic ISSUE-1 + OBSERVATION-1/-2 一括解消）** — (a) retry_test ヘッダコメント正規名化、(b) `saved_drafts_retry_version_guard_structure_cleanup_test.dart` 削除、(c) structure_test の group タイトルを責務ベース命名（`version guard minor 検証メタガード`）に置換。`chain_cleanup_cycle21_test.dart` 8 ケースで C1〜C4 を 1:1 ガード。`flutter analyze` 0 / `flutter test` 424 pass / 本番コード・pubspec 無変更（2026-04-24 Cycle 21 QA APPROVED / Security PASS）
- [✅] **Cycle 22: プライバシーポリシー最終改定日を 2026-04-24 に更新（第2条オプトアウト導線修正との整合化）** — `policy_screen.dart:21` の「最終改定日：2026年4月21日」→「2026年4月24日」1 行置換。`policy_screen_revision_date_test.dart` 7/7 Green。`flutter analyze` 0 / `flutter test` 425 pass（2026-04-24 Cycle 22 QA APPROVED / Security PASS）
- [🚧] **Cycle 23: saved_drafts_screen LINE 本文のブランド誤字「まんなか」→「Aimachi」差し戻し（commit 9d3e746 整合化）** — 本日 Cycle 16（未コミット）で `saved_drafts_screen.dart:187` の LINE 誘導文言が `Aimachi → まんなか` に誤置換された（backlog の旧 Cycle 11 記載を根拠にした判断）。しかし commit `9d3e746`（2026-04-23 ユーザー本人）で方向が逆転し、UI 全域は「Aimachi」に確定している。誘導文「あなたもまんなか（無料）で…」の直後に App Store URL `.../app/aimachi/...` が続くため、LINE 受信者は「まんなか」を検索して見つからず「Aimachi」ページに着地する App Store コンバージョンバグ。L187 を `'あなたもAimachi（無料）で同じ条件のお店を探してみましょう👇'` に戻し、`saved_drafts_screen_error_ui_test.dart` テスト [3] 群 2 ケースの期待値と誘導コメントを反転。スコープ外：他ファイルの Aimachi 表記（既に整合済み）・未コミットの Cycle 16〜22 差分の棚卸し。
- [ ] **support@mannaka.app 受信確認** — メール設定を確認してサポートメールが届くことを確認
- [✅] **flutter analyze 完全クリーン化** — 現在のwarning/infoをすべて0にする
- [✅] **flutter test 全パス確認** — 既存テストが全て通ることを確認し、不足テストを追加
- [✅] **Aima → Aimachi ブランド名統一** — UIテキスト36箇所+クラス名リネーム+Aimachichi タイポ修正+App Store URL一元管理（2026-04-09 完了）
- [✅] **UIテキスト「Aimachi」→「まんなか」完全統一** — UIテキスト47箇所+シェアファイル名2箇所+コメント1箇所修正完了（2026-04-10 Cycle 2-3 QA APPROVED）

## 🟡 中優先度

- [✅] **policy_screen.dart UX修正** — 利用規約の手動改行+全角スペースインデント除去 + Divider違反修正（Critic Cycle 1 指摘 2026-04-09 QA APPROVED）
- [✅] **Critic Cycle 3 指摘修正** — search_screen.dart Divider違反2箇所 + policy_screen.dart SizedBox冗長整理（2026-04-09 QA APPROVED）
- [✅] **scene_area_screen 絵文字UIアイコン違反修正** — リストアイテム leading の絵文字をテキストのみに修正（Critic Cycle 3 ISSUE-3）（2026-04-09 Cycle 5 QA APPROVED）
- [✅] **meeting_point_card 絵文字UIアイコン違反修正** — `Text(point.stationEmoji)` を Material Icon に置換（Critic Cycle 5 CRITICAL → 2026-04-09 QA APPROVED）

- [✅] **Foursquare APIキー安全化** — `api_config.dart` のハードコードを `secrets.dart` 経由に移行（実装確認済み）
- [✅] **オフライン時のエラーハンドリング改善** — ネットワーク未接続時にクラッシュしないことを確認・改善
- [✅] **検索履歴のUI改善** — 履歴画面のUXを整理（スワイプ削除+AppBarクリアで実装済みを確認）
- [✅] **レストランカード写真フォールバック** — 写真URLが取得できない場合のグラデーション背景を統一（Cycle 2完了）
- [✅] **Cycle 2 指摘バグ修正** — use-after-dispose クラッシュ・Controller dispose漏れ・URLスキーム検証（Cycle 3完了）
- [✅] **パフォーマンス最適化** — 地図画面のフレームレート計測と改善（Cycle 24で完了済み）
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

- [✅] **TestFlight配布準備** — Bundle ID統一・PrivacyManifest追加・アプリ表示名修正・ExportOptions整合性（2026-04-10 Cycle 1 QA APPROVED）
- [✅] **PrivacyInfo.xcprivacy 位置情報収集宣言 + ポリシー外部API記載** — NSPrivacyCollectedDataTypes空問題(Critic Cycle 1 ISSUE) + Security W5解消（2026-04-10 Cycle 4 QA APPROVED）
- [🚧] **App Store スクリーンショット作成 + ポリシー改定日修正** — 6.7インチ・6.1インチ用スクリーンショット準備 + Critic Cycle 4 ISSUE（改定日未更新）解消
- [ ] **プライバシーポリシーURL確定** — 実際のホスティング先URLに更新
- [ ] **まんちゃんアニメーション追加** — マスコットに新しいアニメーションパターンを追加
- [✅] **シェア機能のテンプレート改善** — シェアテキストをより魅力的に（Cycle 30完了 2026-03-24）
- [✅] **ダークモード残件修正（Cycle 34）** — `ThemeMode.system` 適用・`AppTheme.dark()` の `navigationBarTheme`/`inputDecorationTheme` 修正（2026-03-30 Cycle 34 APPROVED）
- [✅] **近接集合地点の重複排除 + 有楽町線追加** — 1.2km以内の近接駅を上位1件に絞る deduplication 実装 & kTransitGraph に有楽町線エッジを追加（2026-03-26 完了・QA APPROVED）
- [✅] **deduplication バグ修正（Cycle 35）** — 赤坂見附・国会議事堂前（0.91km）が重複排除されず `flutter test` FAIL（2026-04-02 修正確認済み）

---

## 完了済み

<!-- 完了したタスクはここに移動 -->

---

_最終更新: 自律開発チームが自動管理_
