TDD テスト設計完了。

## サマリ

Cycle 14「手動追加シート最寄り駅ピッカー統合」の回帰テストを 6 本作成。

**作成ファイル**: `test/widgets/manual_restaurant_add_sheet_station_test.dart`
- ソース静的検査 × 3（`_nearestStation` state・`_save()` 双方の `nearestStation:` 引数・UI 契約）
- モデル契約 × 2（`ReservedRestaurant` / `VisitedRestaurant` の JSON ラウンドトリップ + 旧データ互換）
- `history_screen.dart` 表示経路ガード × 1

**実行結果**: 6/6 PASS

**注意点**: 本 Cycle は WIP 実装が既に入っているため、新規テストは全て Green で通る（PM 指示「Green（WIP の文字通りそのまま）」どおり）。純粋な Red→Green TDD ではなく、**コミット前に契約を凍結する回帰ガード**として機能する。`tdd_tests.md` に各テストが Red になる条件（逆条件）を明記し、後続 Cycle でリグレッションを即検知できるようにした。

**未カバー領域**: Widget レベルのピッカー開閉操作、E2E 永続化、iOS シミュレータでの UX は静的テスト外なので qa-reviewer への申し送り事項として記録。
