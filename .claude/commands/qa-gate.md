# QA Gate

実装完了後の品質確認。全観点を確認してからリリース可否を判定する。

## Steps

1. `cd ~/mannaka && flutter analyze` を実行する
2. `cd ~/mannaka && flutter test` を実行する
3. 以下のチェックリストを確認する
4. 判定を出す

## Checklist

### 自動チェック
- [ ] flutter analyze 0 issues
- [ ] flutter test 全パス

### テスト品質
- [ ] 受け入れ条件が全てテストでカバーされているか
- [ ] 正常系だけでなく異常系・境界値のテストがあるか

### 実装品質
- [ ] `if (mounted)` チェック漏れなし
- [ ] dispose 漏れなし（TextEditingController, MapController等）
- [ ] APIキー直書きなし
- [ ] `// ignore` でエラーを隠していないか

### UX確認
- [ ] APIエラー時にクラッシュしないか（空状態表示があるか）
- [ ] ローディング状態が表示されるか
- [ ] 全画面に戻るボタンがあるか
- [ ] 初めて使うユーザーへのガイダンスがあるか

### UIルール確認
- [ ] 絵文字をUIアイコンとして使っていないか
- [ ] Dividerを使っていないか（SizedBox 8-10pxを使う）
- [ ] リストアイテムのleadingに絵文字がないか

### ロジック確認
- [ ] 結果ソートが MidpointService.scoreRestaurants を使っているか
- [ ] kTransitMatrix の35×35制限に違反していないか

## Output Format

```markdown
## 判定: [✅ APPROVED / ⚠️ CONDITIONAL / ❌ REJECTED]

## flutter analyze: [0 issues / X issues]
## flutter test: [全パス / X件失敗]

## チェック結果
[問題があった項目を記載]

## リリース判定理由
[1〜2文で理由を説明]
```
