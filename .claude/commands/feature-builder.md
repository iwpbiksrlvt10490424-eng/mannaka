# Feature Builder

新機能の実装時に使用。既存コード調査から実装、テスト、自己レビュー、報告まで一貫して行う。

## Goal
新機能を既存コードベースに整合する形で安全に追加する。

## Steps

1. **調査**: 関連ファイルと既存パターンを調査する（Glob/Grep使用）
2. **方針確認**: 変更方針を3〜7行で要約する
3. **Red**: 受け入れ条件を網羅する失敗テストを書く（flutter testで失敗を確認）
4. **Green**: テストが通る最小限の実装をする
5. **Refactor**: コードを整理する（テストは引き続きパス）
6. **検証**: `cd ~/mannaka && flutter test` → 全パス / `flutter analyze` → 0 issues
7. **報告**: 変更点と未解決事項をまとめる

## Flutter Rules（必ず守る）
- `withOpacity()` 禁止 → `withValues(alpha: x)`
- APIキー直書き禁止 → `lib/config/secrets.dart`
- 非同期後のcontext使用前に `if (mounted)` 確認
- Controller類は dispose() で必ず破棄
- `// ignore` でエラーを隠さない

## Rules
- 必要以上に抽象化しない
- 既存の命名とレイヤに従う
- 依存追加は最後の手段
- 例外系と空状態を無視しない

## Output Format

```markdown
## Summary
[何を実装したか]

## Changed files
- lib/xxx.dart — [変更内容]
- test/xxx_test.dart — [テスト内容]

## Why this approach
[なぜこの実装方法にしたか]

## Validation
- flutter test: [全パス / X件失敗]
- flutter analyze: [0 issues / X issues]

## Risks / Follow-ups
[残課題・リスクがあれば記載]
```
