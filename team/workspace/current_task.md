## PM タスク選定 完了

**今日のタスク: Google Maps APIキー本番化**

| 項目 | 内容 |
|------|------|
| 優先度 | 🔴 高（リリースブロッカー） |
| 現状 | flutter analyze 0 / flutter test 333 all passed |
| 問題 | `Info.plist:44` に開発用APIキーがハードコード（git追跡対象） |
| 方針 | `--dart-define` によるビルド時注入（既存 HOTPEPPER_KEY パターン踏襲） |

### 選定理由
- 🔴高優先度の2件のうち、コード変更を伴う唯一のタスク（`support@mannaka.app` は外部作業のみ）
- CLAUDE.md の「APIキー直書き禁止」ルールに現状違反している
- App Store 公開前に解消必須のセキュリティ課題

### ユーザーへの確認事項
1. **本番用 Google Maps APIキー**をお持ちですか（Google Cloud Console で発行済みか）
2. キー注入方式は `--dart-define` 方式（既存パターン踏襲）で進めてよいか

**成果物:**
- `team/workspace/current_task.md` — タスク定義・受け入れ条件・技術アプローチ記載済み
- `team/backlog.md` — 該当タスクを `[🚧]` に更新済み

architect-lead → feature-implementer に引き渡し可能です。
