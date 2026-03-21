# CLAUDE.md

## Project Mission
「まんなか」— グループ全員にとってベストなお店を自動提案するiOSアプリ。
ターゲット：20〜30代女性 / App Store公開予定
忙しい開発者が短時間で価値検証できるMVPを、最小の手戻りで継続開発する。

## Commands
```bash
flutter pub get
flutter analyze          # 必須。エラー0件でなければ実装完了とみなさない
flutter test             # 必須。全パスでなければリリース不可
flutter devices          # 実行前にdevice-idを確認する（ハードコード禁止）
flutter run --device-id=<flutter devicesで確認したID>
flutter build ios

# Claude Code: ツール許可プロンプトをスキップして自動実行
claude --dangerously-skip-permissions
```

## Development Principles
- MVP優先。まず動く最小構成を作る
- 早すぎる抽象化を避ける
- 既存コードの流儀に合わせる
- 勝手に新技術・依存を追加しない
- UI・状態管理・API・永続化の責務を分離する

## Flutter Rules（違反禁止）
- `withOpacity()` 禁止 → `withValues(alpha: x)`（Dart 3.9.2 deprecated）
- `flutter_map` + `dart:ui` 同時使用 → `import 'dart:ui' as ui;` で `ui.Path()` と明示
- APIキー直書き禁止 → `lib/config/secrets.dart`（gitignore済み）
- 非同期後のcontext使用前に `if (mounted)` を確認
- ダイアログの `TextEditingController` → `.then((_) => ctrl.dispose())`
- JSONパース: `(json['x'] as Map?)?['y'] as List? ?? []`
- `MapController` は `dispose()` で必ず破棄
- `Share.share()` on iOS は `sharePositionOrigin` 必須
- 地図リンクは緯度経度必須: `maps.apple.com/?ll={lat},{lng}&q={name}`

## Bottom Sheet Rules
- `autofocus: false` を必ず設定（trueにするとキーボードがリストを隠す）
- 固定高さのシートはキーボード高さを引く: `height: size.height * 0.82 - viewInsets.bottom`
- モーダル内のナビゲーション重複防止に `_isNavigating` フラグを使う

## Architecture
```
Participant[] → SearchNotifier.calculate()
  → MidpointService（中間点・重心・スコアリング）
  → HotpepperService（APIキーあり時）/ Overpass（フォールバック）
  → SearchState.hotpepperRestaurants → 結果画面表示
```
スコア: 予約可否25% + 重心距離30% + 距離公平性30% + 評価15%
結果画面は必ず `MidpointService.scoreRestaurants` を使う。単純ソートで代替禁止。

- `kTransitMatrix` は35×35のみ（集合候補は0〜34の35駅に限定）
- 35以上のインデックスはHaversineフォールバック（安全）

## Riverpod Patterns
- `ref.watch` → `build()` 内のみ
- `ref.read` → コールバック・イベントハンドラ内のみ
- `ref.listen` → 副作用（SnackBar・ナビゲーション）

## TDD Rules（必須）
1. **Red**: 失敗するテストを `test/` に先に書く
2. **Green**: テストが通る最小限の実装をする
3. **Refactor**: コードを整理する（テストは引き続きパス）

## Quality Bar
- `flutter analyze` 0 issues / `flutter test` 全パス
- エラー処理・空データ・ローディング状態を考慮
- `flutter analyze` が通っても**ロジックの正しさは別**。目視確認必須
- `secrets.dart` が Git に含まれていない

## Workflow
1. 要件整理（product-manager）
2. 方針確認（architect-lead）
3. 実装（feature-implementer）
4. レビュー（qa-reviewer）
5. 改善（refactor-optimizer）
6. 最終報告

## Reporting Format
```
## Summary
## Changed files
## Why this approach
## Validation（flutter analyze / flutter test 結果）
## Risks / Follow-ups
```

## UI Design Rules
- 絵文字をUIアイコンとして使用禁止 — Material Icons のみ
- リストアイテムの leading に絵文字・アイコン禁止 — テキストのみ
- 削除操作はそのデータが見える画面に置く（設定画面に置かない）
- Divider禁止 — SizedBox 8-10px で区切る
- カード: `white, borderRadius 12, BoxShadow(black 6%, blur 8, offset(0,2))`
- 背景: `Color(0xFFF7F7F7)` / Primary: `#FF6B81`（コーラルピンク）
- データ収集・分析の説明はUIに出さない
- 初めて使うユーザーへのガイダンスを入力画面の先頭に入れる

## Pre-Implementation Checklist
1. E2Eフロー — 「画面→操作→結果」を辿れるか
2. 大規模書き換え時 — 旧コードの依存関係を列挙し新コードで引き継ぐか確認
3. 1箇所変えたら他画面も確認

## Constraints
- APIキー・secrets/.env を直接読み書きしない
- 指示なしで大規模リファクタをしない
- 指示なしで依存関係を追加しない
- `// ignore` でエラーを隠さない
- debugPrint は本番で `kReleaseMode` 分岐か `developer.log` を使う

## Versioning
- Semantic Versioning: `MAJOR.MINOR.PATCH+BUILD`
- `pubspec.yaml` の `version:` フィールドで一元管理

## Environment
```bash
flutter run --dart-define=HOTPEPPER_KEY=xxx --dart-define=ENV=dev
flutter build ios --dart-define=HOTPEPPER_KEY=yyy --dart-define=ENV=prod
```

## Tech Stack
- Flutter + Dart 3.9.2 / flutter_riverpod ^2.6.1
- flutter_map ^8.1.1 + latlong2 ^0.9.1
- share_plus ^10.1.2 / shared_preferences ^2.5.2
- geolocator ^13.0.1 / url_launcher ^6.3.0 / http ^1.2.2
- Hotpepper API / Foursquare API v3 / Overpass API
