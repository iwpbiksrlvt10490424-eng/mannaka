# セキュリティレビュー

**日付**: 2026-04-14
**対象**: Google Maps APIキー本番化（TDD Green フェーズ完了後）
**レビュアー**: Security Agent

## 判定: WARNING

---

### CRITICAL（即時修正必須）

なし

---

### WARNING（修正推奨）

#### ISSUE W-1: テストコードのコメントに旧APIキーリテラルが記載
- **場所**: `test/security/google_maps_api_key_test.dart:13`
- **内容**: コメント内に `AIzaSyArT8DEsqEioGlvywVEcqe_fPofPtqIxAM` が記載されている
- **リスク**: このファイルは untracked（新規追加予定）のため、コミットするとリポジトリに実際のAPIキーが残る
- **推奨**: コメントからキーリテラルを削除し、`AIzaSy...（省略）` のようにマスクする

#### ISSUE W-2: Git履歴にAPIキーが残存
- **場所**: `ios/Runner/Info.plist` の過去コミット（3箇所）
- **内容**: `AIzaSyArT8DEsqEioGlvywVEcqe_fPofPtqIxAM` が git history に残っている
- **リスク**: リポジトリを公開した場合（または既に公開済みの場合）、キーが漏洩する
- **推奨**: Google Cloud Console で当該キーをローテーション（新キー発行 → 旧キー無効化）。`implementation_notes.md` にも同様の推奨あり

#### ISSUE W-3: debugPrint がリリースビルドで無保護
- **場所**: `lib/` 配下の全 `debugPrint` 呼び出し（40箇所以上）
- **内容**: `kReleaseMode` / `kDebugMode` による分岐が一切なく、リリースビルドでもデバッグログが出力される
- **リスク**: APIレスポンスの一部（`response.body.substring(0, 200)`）やエラー情報がデバイスのコンソールログに残る
- **推奨**: CLAUDE.md のルール通り `kReleaseMode` 分岐 or `developer.log` への移行。最低限、API通信系のログを保護すること

#### ISSUE W-4: 例外ダンプにAPIキーが含まれる可能性
- **場所**: `lib/services/geocoding_service.dart:39`
- **内容**: `debugPrint('[Geocoding] 例外: $e')` で例外オブジェクトをそのまま出力。HTTP例外の場合、リクエストURL（`key=...` パラメータ含む）が例外メッセージに含まれる可能性がある
- **リスク**: Geocoding APIキーがログに平文出力される
- **推奨**: `${e.runtimeType}` のみ出力する（他のサービスファイルでは既にこのパターンを採用済み）

---

### INFO

#### I-1: GoogleService-Info.plist がgit追跡対象
- **場所**: `ios/Runner/GoogleService-Info.plist`
- **内容**: Firebase API キー `AIzaSyCfs68Arc-...` が含まれる
- **評価**: Firebase の設計上、クライアントAPIキーは公開前提。セキュリティは Firebase Security Rules で担保する。SECURITY.md に記載済み
- **確認事項**: Firebase Security Rules が適切に設定されていることを定期的にレビューすること

#### I-2: secrets.dart は正しく保護されている
- `.gitignore` に `lib/config/secrets.dart` が記載済み
- `git ls-files` でトラック対象外であることを確認済み
- `secrets.dart.example` にはプレースホルダー（`YOUR_xxx_API_KEY`）のみ

#### I-3: Secrets.xcconfig は正しく保護されている
- `.gitignore` に `ios/Flutter/Secrets.xcconfig` が記載済み
- `Debug.xcconfig` / `Release.xcconfig` からは `#include?`（optional include）で参照

#### I-4: 全外部API通信はHTTPS
- `GeocodingService`: `https://maps.googleapis.com/...`
- `HotpepperService`: `https://webservice.recruit.co.jp/...`
- `FoursquareService`: `https://api.foursquare.com/...`
- `OverpassService`: `https://overpass-api.de/...`
- HTTP通信は検出されず

#### I-5: SharedPreferences に機密情報なし
- パスワード、トークン、APIキー等の保存は検出されず

#### I-6: テストコードに実際の個人情報なし
- セキュリティテストはパターンマッチ（正規表現）で検証しており、実際のキーを使用していない（W-1 のコメント除く）

---

### チェックリスト結果

| チェック項目 | 結果 |
|---|---|
| APIキーがソースコードに直書きされていない | PASS（Info.plist はビルド変数化済み） |
| secrets.dart がコミット対象になっていない | PASS |
| HTTPS のみ使用 | PASS |
| ユーザー入力をそのまま外部APIに渡していない | PASS（駅名は `$stationName駅` として Geocoding に渡すが、URLエンコード済み） |
| ログに機密情報が出力されていない | WARNING（W-3, W-4） |
| SharedPreferences に機密情報を保存していない | PASS |
| Firebase Security Rules の読み書き制限 | 要確認（SECURITY.md 記載の通り定期レビュー推奨） |
| テストコードにAPIキーや個人情報が含まれていない | WARNING（W-1: コメント内にキーリテラル） |

---

### 推奨アクション（優先度順）

1. **W-1**: テストコメントからAPIキーリテラルを削除してからコミット
2. **W-4**: `geocoding_service.dart:39` を `${e.runtimeType}` に修正
3. **W-2**: Google Cloud Console でキーローテーション実施
4. **W-3**: `debugPrint` の `kReleaseMode` ガード導入（段階的に対応可）
