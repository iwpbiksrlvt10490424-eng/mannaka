# Architecture Checker

実装前に構成が破綻していないか確認する。

## Steps

1. タスクの概要を確認する
2. 関連する既存ファイルを調査する（Glob/Grep使用）
3. 以下の観点でレビューする

## Checklist

### レイヤ分離
- [ ] UI層（screens/widgets）がビジネスロジックを持っていないか
- [ ] サービス層がUIに依存していないか
- [ ] モデル層が純粋なデータ構造になっているか

### 状態管理（Riverpod）
- [ ] ref.watch は build() 内のみか
- [ ] ref.read はコールバック・イベントハンドラ内のみか
- [ ] NotifierProvider の粒度が適切か

### 非同期・メモリ
- [ ] 非同期後のcontext使用前に if (mounted) があるか
- [ ] TextEditingController / MapController の dispose があるか

### API・データ
- [ ] APIキーが secrets.dart 以外に書かれていないか
- [ ] JSONパースが null-safe か
- [ ] kTransitMatrix の35×35制限に抵触しないか

### 設計方針
- [ ] 結果ソートは MidpointService.scoreRestaurants を使うか
- [ ] 新規依存追加が本当に必要か

## Output

```markdown
## 方針レビュー結果

### 推奨アプローチ
[実装方法の提案]

### 影響ファイル
- [lib/xxx.dart] — [変更の概要]

### 懸念点
- [懸念1]: [対処方法]

### GOサイン
[実装を進めてよい / 要修正事項]
```
