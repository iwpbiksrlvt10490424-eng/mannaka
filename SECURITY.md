# セキュリティチェックリスト（常時実施）

## 🔴 現在の既知リスク

### 1. Firebase設定のハードコード
- **場所**: `lib/firebase_options.dart`
- **内容**: APIキー、プロジェクトID等
- **リスク**: Firebaseキーは公開が前提（Firebase Security Rulesで制御）だが、Rulesを適切に設定しないと全データが読み書き可能
- **対応策**: Firebase Security Rulesを必ず設定・定期レビューする

---

## ✅ 毎回コード変更時にチェックする項目

### APIキー・シークレット
- [ ] 新しいAPIキー・トークン・パスワードをコードに直書きしていないか
- [ ] `.env`や`secrets.dart`などのファイルが`.gitignore`に含まれているか
- [ ] `git log`に過去のキーが残っていないか

### 入力バリデーション
- [ ] ユーザー入力（駅名・名前等）に最大文字数制限があるか
- [ ] URLやディープリンクのパラメータをサニタイズしているか
- [ ] `url_launcher`で開くURLは`http/https/mailto`のみ許可しているか

### 通信セキュリティ
- [ ] HTTPSのみ使用（HTTPは禁止）
- [ ] 外部APIレスポンスのエラーハンドリングが適切か（クラッシュしないか）
- [ ] タイムアウトが設定されているか（無限待機を防ぐ）

### データ保存
- [ ] `SharedPreferences`に機密情報（パスワード等）を保存していないか
- [ ] `debugPrint`でAPIキーや個人情報をログ出力していないか
- [ ] Firestoreに不要な個人情報を書き込んでいないか

### 位置情報
- [ ] GPS座標を第三者サービスに送信する場合はユーザーへの説明があるか
- [ ] 位置情報の使用はプライバシーポリシーに記載されているか

### 依存パッケージ
- [ ] `flutter pub outdated`で既知の脆弱性があるパッケージをチェック
- [ ] 不要なパッケージ（使っていないのにpubspecに残っているもの）がないか

---

## 🔧 推奨改善（優先度順）

1. **高**: Foursquareキーをバックエンドプロキシ経由に移行
2. **高**: Firebase Security Rulesの設定・確認
3. **中**: `flutter_secure_storage`パッケージ導入（センシティブデータの暗号化保存）
4. **中**: ログ出力の整理（本番ビルドでは`debugPrint`を無効化）
5. **低**: 証明書ピンニング（高セキュリティが必要な場合）

---

## 📋 チェック実施記録

| 日付 | 実施者 | 変更内容 | 問題発見 |
|------|--------|----------|---------|
| 2026-03-11 | Claude | 初回チェック | Foursquare APIキーハードコード検出 |
| 2026-03-18 | Claude (Engineer) | HotpepperService debugPrint $e → ${e.runtimeType} に修正 | APIキーログ漏洩リスク対応 |
| 2026-03-19 | Claude (Engineer) | voting_sessions Firestoreルール強化 + hostName/voterName バリデーション追加 + Foursquareキー secrets.dart 移行確認・既知リスク削除 | Cycle 13 セキュリティ強化 |

