# セキュリティレビュー

**日時**: 2026-03-19
**対象サイクル**: Cycle 17（Green フェーズ完了）
**レビュアー**: Claude (Security Agent)

## 判定: WARNING

---

### CRITICAL（即時修正必須）

なし

---

### WARNING（修正推奨）

#### ISSUE-W1: `voting_security_cycle16_test.dart` に Foursquare APIキー実値が含まれている

- **ファイル**: `test/security/voting_security_cycle16_test.dart`
- **該当行**: Lines 208, 216, 222, 231, 252, 277
- **内容**: `RB4PAHEZPYFPF0S4FIV11R102LA2PKPC15C04HGZ3MMMRM5L` が
  文字列リテラル・コメント・エラーメッセージとして複数箇所に埋め込まれている。

  このファイルの意図は「cycle15_test.dart がこのキーを含まないことを検証する」ことだが、
  検出対象の文字列として cycle16_test.dart 自体にキー実値が残っている。
  テストファイルは `.gitignore` 対象外のため、git にコミットされるとキーが公開される。

- **修正**: `content.contains('RB4PAHEZPYFPF0S4FIV11R102LA2PKPC15C04HGZ3MMMRM5L')` を
  `RegExp(r'[A-Z0-9]{40,}').hasMatch(content)` に置換。エラーメッセージ内の実値も同様に除去する。

#### ISSUE-W2: セッション作成失敗時のエラー詳細がUIに露出している

- **ファイル**: `lib/screens/search_screen.dart`
- **該当行**: Line 1130
  ```dart
  Text('リンクの作成に失敗しました: $e'),
  ```
- **内容**: `$e` をそのまま SnackBar に表示しており、Firestore のエラー詳細
  （コレクションパス、ルール違反メッセージ等）がユーザー画面に出力される。
- **修正**: `Text('リンクの作成に失敗しました。もう一度お試しください。')` の固定メッセージに変更する。

---

### INFO

#### INFO-1: ISSUE-W1 (ownerUid 未設定) は Cycle 17 で解消済み ✅

- **旧 ISSUE-W1**: `LocationSessionService.createSession()` が `ownerUid` を Firestore に保存しない問題
- **状態**: Cycle 17 Green フェーズで修正済み
  - `location_session_service.dart`: `ownerUid` パラメータ追加・set() データに含める
  - `search_screen.dart`: `ownerUid: FirebaseAuth.instance.currentUser?.uid ?? ''` を渡すよう修正
  - これにより `firestore.rules` の `allow create: if request.auth.uid == request.resource.data.ownerUid` が正常に機能するようになった

#### INFO-2: ownerUid に空文字が渡されるケースが存在する

- **ファイル**: `lib/screens/search_screen.dart` Line 1125
  ```dart
  ownerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
  ```
- **内容**: `currentUser` が null の場合 ownerUid = '' でドキュメントが作成される。
  Firestore Rules `allow create: if request.auth != null && request.auth.uid == request.resource.data.ownerUid`
  の条件上、認証済みユーザーの UID は常に non-null のため実害は発生しにくい。
  ただし認証タイミングによる競合を避けるため、null 時は早期リターンが望ましい。

#### INFO-3: `voting_sessions` update が全認証ユーザーに開放されている

- **ファイル**: `firestore.rules:13`
- **内容**: `allow update: if request.auth != null;` — 投票機能のため意図的に緩和済みだが、
  将来的には `candidates` フィールドのみ更新可能に制限することが推奨される。

---

### チェックリスト結果

| 項目 | 結果 | 備考 |
|------|------|------|
| APIキー直書き（ソースコード） | ✅ PASS | `api_config.dart` → `secrets.dart` 経由、gitignore 済み |
| `secrets.dart` gitignore | ✅ PASS | `.gitignore` L1-2 で除外確認済み |
| HTTPS のみ使用 | ✅ PASS | Hotpepper/Foursquare 全て `https://` |
| ユーザー入力の外部API直渡し | ✅ PASS | 型安全・50文字バリデーション実装済み |
| debugPrint に機密情報 | ✅ PASS | エラーログは `${e.runtimeType}` のみ |
| SharedPreferences に機密情報 | ✅ PASS | 検索履歴・お気に入り駅のみ保存 |
| Firebase Security Rules 設定 | ✅ PASS | デフォルト deny + 細粒度ルール設定済み |
| `voting_sessions` delete 制限 | ✅ PASS | `hostUid` チェック済み（Cycle 13） |
| `location_sessions` ownerUid 制限 | ✅ PASS | Cycle 17 で実装・Rules 両方対応済み |
| テストコード APIキー実値 | ⚠️ WARNING | cycle16_test.dart に実値あり → ISSUE-W1 |
| エラーメッセージの情報漏洩 | ⚠️ WARNING | search_screen.dart L1130 → ISSUE-W2 |

---

### 次回対応推奨（優先度順）

1. **高**: `voting_security_cycle16_test.dart` のキー実値を RegExp パターンに置換（ISSUE-W1）
2. **中**: `search_screen.dart` L1130 のエラー表示を固定メッセージに変更（ISSUE-W2）
3. **中**: `FirebaseAuth.instance.currentUser?.uid ?? ''` を null ガードに変更（INFO-2）
4. **中**: `voting_sessions` update を `candidates` フィールド限定に制限（INFO-3）
5. **低**: 本番ビルドで `debugPrint` を `kDebugMode` ガードで無効化

---

### チェック実施記録

| 日付 | 実施者 | 変更サイクル | 問題発見 |
|------|--------|-------------|---------|
| 2026-03-19 | Claude (Security Agent) | Cycle 16 | ISSUE-W1: ownerUid 未設定 / 旧報告 |
| 2026-03-19 | Claude (Security Agent) | Cycle 17 | ISSUE-W1 解消確認・新規: cycle16_test キー実値 / search_screen エラー露出 |
