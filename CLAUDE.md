# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## アプリ概要
「まんなか」— グループ全員にとってベストなお店を自動提案するiOSアプリ。
ターゲット：20〜30代女性 / App Store公開予定

## コマンド
```bash
flutter pub get
flutter analyze          # 必須。エラー0件でなければ実装完了とみなさない
flutter test             # 必須。全パスでなければリリース不可
flutter run --device-id=366D236E-C477-41BC-A9B1-C80FB6044606
flutter build ios
```

## 開発ルール（違反禁止）
- `withOpacity()` 禁止 → `withValues(alpha: x)`（Dart 3.9.2 deprecated）
- **APIキー直書き禁止** → `lib/config/secrets.dart`（gitignore済み）
- 非同期後のcontext使用前に `if (mounted)` を確認
- ダイアログの `TextEditingController` → `.then((_) => ctrl.dispose())`
- JSON パース: `(json['x'] as Map?)?['y'] as List? ?? []`
- `MapController` は `dispose()` で必ず破棄
- `flutter_map` + `dart:ui` 同時使用 → `import 'dart:ui' as ui;` で `ui.Path()` と明示

## ボトムシートルール
- `autofocus: false` を必ず設定（trueにするとキーボードがリストを隠す）
- 固定高さのシートはキーボード高さを引く: `height: size.height * 0.82 - viewInsets.bottom`
- モーダル内でナビゲーションが重複しないよう `_isNavigating` フラグを使う:
  ```dart
  bool _isNavigating = false;
  Future<void> _openSheet() async {
    if (_isNavigating) return;
    _isNavigating = true;
    await showModalBottomSheet(...);
    if (mounted) _isNavigating = false;
  }
  ```

## 大規模書き換えルール（必須）
1. **書き換え前**: 旧コードが呼ぶ関数・プロバイダーを列挙し、新コードで引き継ぐか明示
2. **書き換え後**: `flutter analyze` だけでは不十分。スコアリング・判定ロジックは目視で仕様と照合
3. コアロジックを持つ画面を書き換えた場合、`MidpointService.scoreRestaurants` が正しく呼ばれているか確認

## アーキテクチャ

### データフロー（核心）
```
Participant[] → SearchNotifier.calculate()
  → MidpointService（中間点・重心・スコアリング）
  → HotpepperService（APIキーあり時）/ Overpass（フォールバック）
  → SearchState.hotpepperRestaurants → 結果画面表示
```
**スコア**: 予約可否25% + 重心距離30% + 距離公平性30% + 評価15%
**重要**: 結果画面は必ず `MidpointService.scoreRestaurants` を使うこと。単純ソートで代替禁止。

### 主要プロバイダー
- `search_provider.dart` — `SearchNotifier` / `SearchState`（中核）
- `history_provider.dart` / `visit_log_provider.dart` — SharedPreferences永続化
- `favorites_provider.dart` — お気に入り駅（上限3件）

### 主要画面
| 画面 | 概要 |
|---|---|
| `home_screen.dart` | FlutterMap + DraggableSheet + まんちゃんマスコット |
| `search_screen.dart` | 参加者入力（GPS/駅/地図タップ）+ フィルタ |
| `results_screen.dart` | 最大5タブ（集合候補駅ごと）、各タブにジャンルフィルター+レストランリスト |
| `restaurant_detail_screen.dart` | 詳細 + 地図 + Hotpepper予約（SliverAppBar）|
| `map_input_screen.dart` | 地図タップで出発地指定 |
| `history_screen.dart` | 検索履歴 / 飲食記録（2タブ）|
| `settings_screen.dart` | プロフィール / お気に入り駅 / API設定 |

### kTransitMatrix の制限
- 35×35のみ（kStationsは59駅）
- 集合候補は0〜34の35駅に限定（仕様）
- 35以上のインデックスはHaversineフォールバック（安全）

## UIデザインルール
- **絵文字をUIアイコンとして使用禁止** — Material Icons のみ
- **リストアイテムのleadingに絵文字・アイコン禁止** — テキストのみ
- **削除操作はそのデータが見える画面に置く**（設定画面に置かない）
- カード: `white, borderRadius 12, BoxShadow(black 6%, blur 8, offset(0,2))`
- 背景: `Color(0xFFF7F7F7)` / Primary: `#FF6B81`（コーラルピンク）
- 新機能追加前に「どの画面→どの操作→どの結果」のフローを確認してから実装

## 批判役チェックリスト（実装前に必ず確認）
1. E2Eフロー — 「画面→操作→結果」を辿れるか？繋がらない機能は実装しない
2. 削除操作 — データが見える画面にのみ置く
3. 全画面一貫性 — 1箇所変えたら他画面も確認
4. 書き換え時 — 旧コードの依存関係を列挙し、新コードで引き継ぐか確認

## コードベース全体監査（「改善点は？」と聞かれたら必ず実行）

**CLIは指示されたことしかやらない。「改善して」と言われてもflutter analyzeだけで終わりにするな。**
必ずExploreエージェントを起動してコードを実際に読んで問題を見つけてから実装すること。

監査チェックリスト（Exploreエージェントに渡すこと）：
- `Future.delayed` の不必要な人工遅延（スプラッシュ・ボタン等）
- `await` で画面遷移をブロックしていないか（先に遷移 → スケルトン表示が原則）
- ソート・フィルタが `MidpointService.scoreRestaurants` を正しく使っているか
- 各APIサービスのタイムアウト値が適切か（フォールバックは長め）
- `flutter analyze` が通っても**ロジックの正しさは別**。目視確認必須

## App Store リリース前チェックリスト
- [ ] `flutter analyze` 0 issues
- [ ] `flutter test` 全パス
- [ ] `secrets.dart` が Git に含まれていない
- [ ] `pubspec.yaml` のビルド番号インクリメント済み
- [ ] `ios/Runner/Info.plist` の Google Maps キーを本番用に変更
- [ ] `settings_screen.dart` の App ID を実際のものに変更
- [ ] `support@mannaka.app` が受信できること
- [ ] TestFlight で実機動作確認

## スラッシュコマンド（インストール済み）
- `/feature-dev` — 機能ブリーフから実装まで自動化（コミュニティ89k+ installs）
- `/commit` — 差分解析から適切なコミットメッセージを生成
- `/review-pr` — PRの差分をレビューしてフィードバック
- `/simplify` — 変更コードのリファクタ・品質改善

## Riverpod パターン（コミュニティベストプラクティス）
- `ref.watch` → `build()` 内のみ（再ビルドをトリガー）
- `ref.read` → コールバック・イベントハンドラ内のみ（1回読み取り）
- `ref.listen` → 状態変化に応じた副作用（SnackBar・ナビゲーションなど）
- 新しいNotifierでは `ref.watch(provider.notifier)` ではなく `ref.read(provider.notifier)` でメソッド呼び出し

## 技術スタック
- Flutter + Dart 3.9.2 / flutter_riverpod ^2.6.1
- flutter_map ^8.1.1 + latlong2 ^0.9.1
- share_plus ^10.1.2 / shared_preferences ^2.5.2
- geolocator ^13.0.1 / url_launcher ^6.3.0 / http ^1.2.2
- Hotpepper API / Foursquare API v3 / Overpass API（フォールバック順）
