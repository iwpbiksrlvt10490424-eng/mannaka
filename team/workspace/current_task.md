PM タスク選定完了。

**選定タスク: Cycle 14 — 手動追加シートの最寄り駅ピッカー正式統合 + 回帰テスト**

## サマリ
- `backlog.md:24` の Cycle 13 は `[✅]` に更新。`ranking_screen.dart` L39/L108/L122/L410/L507 の「まんなか指数」化は完了しており、`flutter analyze` 0 / `flutter test` 416 pass で静的検証済み。Critic/Security/QA は 2026-04-22 の API limit で未実施だが、成果物は `lib_no_aimachi_in_ui_test.dart` 16 ケースで恒久的にガードされている
- ユーザーが手動で `home_screen.dart:306` ヘッダーを `'Aimachi'` に温存し、テストの `_patternAllowlist` に `RegExp(r"'Aimachi'")` を追加して「ブランド名は Aimachi、まんなかへの巻き戻し禁止」と明記したため、この判断を Cycle 14 の同コミットで永続化する
- 🔴残件（`support@mannaka.app` 受信確認・ポリシー URL 確定・App Store スクショ）はユーザー手作業でコードスコープ外
- 現在 WIP の `manual_restaurant_add_sheet.dart` の最寄り駅ピッカーは保存経路 (`ReservedRestaurant.nearestStation` / `VisitedRestaurant.nearestStation`) と `history_screen.dart:373` の表示経路を既に接続しているが、**テスト未整備**・エッジケース未検証のためコミット前に TDD で固めるのが最優先

## 次のステップ
TDD Tester → feature-implementer で Red（新規 `test/widgets/manual_restaurant_add_sheet_station_test.dart`：ソース静的検査 3 本 + モデル契約 2 本 + history_screen ガード 1 本）→ Green（WIP の文字通りそのまま）→ qa-reviewer の順で進めればよい。変更ファイルと受け入れ条件 6 項目・ユーザー確認 4 項目は `current_task.md` に記載済み。
