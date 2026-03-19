# まんなか 自律開発チームシステム

## 概要

あなたが仕事に行っている間（平日 07:00〜）、開発チームが自動でアプリを作り続けます。
帰宅後（21:00〜）にレポートを確認してフィードバックを入れるだけでOKです。

---

## チーム構成

| エージェント | 役割 | タイミング |
|---|---|---|
| 🎯 **PM** | バックログからタスク選定・仕様作成 | 各サイクル冒頭 |
| 💻 **Engineer** | Flutter実装 | PM後 |
| 🔍 **Critic** | コードレビュー・UI整合性チェック | 実装後 |
| 🔒 **Security** | セキュリティ・APIキー・プライバシーチェック | 実装後 |
| 🔧 **Engineer(Fix)** | Critic/Securityの指摘を修正 | 問題検出時のみ |
| ✅ **QA** | flutter analyze・flutter test・最終確認 | 各サイクル末尾 |
| 📣 **Marketing** | ASO・SNSコンテンツ・競合分析 | 毎週金曜のみ |

---

## 毎日のスケジュール

```
07:00  自動セッション開始（cron）
  │
  ├─ サイクル1（〜08:15）
  │   PM → Engineer → Critic → Security → Fix → QA
  │
  ├─ サイクル2（〜09:30）
  ├─ サイクル3（〜10:45）
  ├─ サイクル4（〜12:00）
  │
12:00  セッション終了・レポート生成
  │
21:00  あなたが帰宅
  │
  └─ レポート確認 → バックログ更新 → フィードバック記入
```

---

## あなたがやること（帰宅後15分）

### 1. レポートを読む
```bash
cat ~/mannaka/team/reports/$(date +%Y-%m-%d).md
```
または `~/mannaka/team/reports/` フォルダをFinderで開く

### 2. バックログを更新する
```bash
# バックログを編集（次に取り組んでほしいタスクを追加・優先度変更）
open ~/mannaka/team/backlog.md
```

### 3. フィードバックを残す（任意）
```bash
# 気になった点を FEEDBACK.md に書いておく
# 翌朝の開発チームが読みます
```

---

## ファイル構成

```
~/mannaka/team/
├── SYSTEM.md          ← このファイル（使い方説明）
├── backlog.md         ← タスク一覧（あなたが管理）
├── daily_session.sh   ← 自動セッションスクリプト
├── agents/            ← 各エージェントへの指示書
│   ├── pm_prompt.md
│   ├── engineer_prompt.md
│   ├── critic_prompt.md
│   ├── security_prompt.md
│   ├── fix_prompt.md
│   ├── qa_prompt.md
│   └── marketing_prompt.md
├── workspace/         ← エージェント間の作業ファイル（一時）
│   ├── current_task.md       ← 今日のタスク仕様
│   ├── implementation_notes.md ← 実装記録
│   ├── review_feedback.md    ← コードレビュー結果
│   ├── security_report.md    ← セキュリティレビュー
│   ├── fix_notes.md          ← 修正記録
│   └── qa_report.md          ← QA最終報告
└── reports/           ← 日次レポート（あなたが読む）
    ├── 2026-03-17.md
    ├── 2026-03-18.md
    └── ...
```

---

## バックログの使い方

`backlog.md` を編集して開発チームへの指示を出します：

```markdown
- [ ] タスク名 — 詳細説明
- [🚧] 進行中のタスク — （自動で更新される）
- [✅] 完了タスク — （自動でチェックが入る）
```

**優先度を変える**: 上に書いたタスクほど先に取り組まれます

---

## 手動実行（いつでも動かせます）

```bash
cd ~/mannaka
~/mannaka/team/daily_session.sh
```

または特定のエージェントだけ実行：

```bash
cd ~/mannaka
claude --dangerously-skip-permissions -p "$(cat team/agents/qa_prompt.md)"
```

---

## cron設定確認

```bash
crontab -l
```

---

## トラブルシューティング

**スクリプトが動かない場合**:
```bash
bash ~/mannaka/team/daily_session.sh
```

**claude が見つからない場合**:
```bash
ls -la ~/.local/bin/claude
```

**レポートが空の場合**:
```bash
cat ~/mannaka/team/reports/$(date +%Y-%m-%d)_session.log
```
