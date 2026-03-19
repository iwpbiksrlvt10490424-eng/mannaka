# 今日のタスク

## タスク名
Cycle 17 残件修正（Cycle 18）— search_screen クラッシュリスク・エラー詳細露出・テストAPIキー実値・location_session_service テスト追加

## 背景・目的
Cycle 17 の Critic/Security レビューで検出された未対応指摘を解消する。
`search_screen.dart` のクラッシュリスク（use-after-dispose）と本番エラー詳細のUI露出は品質基準違反。
テストファイルに残るAPIキー実値はセキュリティリスク。
`location_session_service` の ownerUid 書き込みは未テストのまま。

## ユーザーストーリー
As a ユーザー, I want アプリがシェア後に突然落ちないことを期待する, so that 快適にシェアができる。
As a 開発者, I want テストコードにAPIキー実値が含まれないことを保証する, so that Git履歴に機密情報が漏れない。
As a セキュリティ担当, I want location_session に ownerUid が必ず書き込まれることをテストで証明する, so that 不正なセッション操作を防げる。

## 受け入れ条件（テストで証明できる形で書く）

- [ ] `search_screen.dart` の `Share.share()` 呼び出し直後に `if (!mounted) return;` が存在する
- [ ] `search_screen.dart` のエラーダイアログに Firestore例外の詳細文字列（`$e` / `e.toString()`）が表示されない（固定メッセージのみ）
- [ ] `voting_security_cycle16_test.dart` 内に APIキー実値（`RB4P...` 等の40文字以上の英数字リテラル）が存在しない
- [ ] `test/services/location_session_service_test.dart` が新規作成され、ownerUid フィールドが書き込まれることを検証するテストが最低1件 Green になる
- [ ] `flutter analyze` 0 issues
- [ ] `flutter test` 全パス（新テスト含む）

## 技術的アプローチ（変更ファイル・方針）

| 優先度 | ファイル | 変更内容 |
|--------|----------|----------|
| 🔴 HIGH | `lib/screens/search_screen.dart` (行1145付近) | `Share.share()` の `.then()` または `await` 直後に `if (!mounted) return;` を追加 |
| 🔴 HIGH | `test/security/voting_security_cycle16_test.dart` (6箇所) | APIキー実値リテラル → `RegExp(r'[A-Z0-9]{40,}').hasMatch(content)` 形式に置換 |
| 🟡 MEDIUM | `lib/screens/search_screen.dart` (行1130付近) | エラーダイアログの文字列を `'現在お店情報を取得できません。しばらくしてからお試しください。'` 固定に変更 |
| 🟢 LOW | `test/services/location_session_service_test.dart` (新規) | `LocationSessionService.createSession()` が ownerUid を Firestore ドキュメントに書き込むことをモックで検証 |

TDD フロー:
1. Red: `location_session_service_test.dart` を先に書いてテスト失敗確認
2. Green: `search_screen.dart` 2箇所修正 + `cycle16_test.dart` APIキー置換
3. Refactor: `flutter analyze` / `flutter test` で全件確認

## 完了基準

- [ ] flutter analyze 0 issues
- [ ] flutter test 全パス（新テスト含む）
