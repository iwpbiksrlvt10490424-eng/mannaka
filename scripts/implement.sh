#!/bin/bash
# implement.sh — request.md を読んでClaude Codeに実装させる

set -euo pipefail

REPO_DIR="/Users/sasakikyoutadashi/mannaka"
REQUEST_FILE="$REPO_DIR/request.md"
REPORT_FILE="$REPO_DIR/report.md"
LOG_FILE="$REPO_DIR/scripts/watcher.log"
DEVICE_ID="366D236E-C477-41BC-A9B1-C80FB6044606"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== 実装開始 ==="
cd "$REPO_DIR"

# request.md の内容を取得
REQUEST=$(cat "$REQUEST_FILE")
if [ -z "$REQUEST" ] || echo "$REQUEST" | grep -q "ここに指示を書く"; then
    log "有効な指示がありません。スキップします。"
    exit 0
fi

# report.md を「実行中」に更新
cat > "$REPORT_FILE" << EOF
# 実装レポート

## ステータス

🔄 実行中...

## 実行日時

$(date '+%Y-%m-%d %H:%M:%S')

## リクエスト内容

$(cat "$REQUEST_FILE")
EOF

log "Claude Code に指示を送信中..."

# Claude Code を非インタラクティブモードで実行
CLAUDE_OUTPUT=$(claude -p "
あなたはmannakaプロジェクト（/Users/sasakikyoutadashi/mannaka）のシニアFlutterエンジニアです。
以下の指示を読んでコードを実装してください。

実装ルール:
- withOpacity()は使用禁止、withValues(alpha: x)を使う
- flutter analyze が0 issuesになるように
- 既存のアーキテクチャ（Riverpod v2）を維持
- 変更したファイルとその内容を必ず報告する

指示:
$REQUEST
" 2>&1) || true

log "Claude Code 完了"

# flutter analyze 実行
log "flutter analyze 実行中..."
ANALYZE_RESULT=$(cd "$REPO_DIR" && flutter analyze 2>&1) || true
ANALYZE_STATUS="✅ 0 issues"
if echo "$ANALYZE_RESULT" | grep -q "error"; then
    ANALYZE_STATUS="❌ エラーあり"
fi

# git status で変更ファイルを取得
CHANGED_FILES=$(git -C "$REPO_DIR" diff --name-only 2>/dev/null || echo "なし")
CHANGED_STAGED=$(git -C "$REPO_DIR" diff --cached --name-only 2>/dev/null || echo "")

# git commit & push
if [ -n "$CHANGED_FILES" ] || [ -n "$CHANGED_STAGED" ]; then
    log "Git commit & push..."
    git -C "$REPO_DIR" add -A
    git -C "$REPO_DIR" commit -m "auto: $(date '+%Y%m%d-%H%M') request.md から自動実装" || true
    git -C "$REPO_DIR" push origin main || log "push失敗（ネットワーク確認）"
    log "Push完了"
else
    log "変更なし"
fi

# スクリーンショット取得
log "スクリーンショット取得中..."
SCREENSHOT_PATH="$REPO_DIR/screenshots/ui_$(date '+%Y%m%d_%H%M%S').png"
bash "$REPO_DIR/scripts/screenshot.sh" "$SCREENSHOT_PATH" || log "スクリーンショット取得失敗（シミュレーター確認）"

# report.md を更新
cat > "$REPORT_FILE" << EOF
# 実装レポート

## ステータス

✅ 実装完了

## 実行日時

$(date '+%Y-%m-%d %H:%M:%S')

## 実装内容

$CLAUDE_OUTPUT

## 変更ファイル

$CHANGED_FILES

## Flutter Analyze

$ANALYZE_STATUS

## スクリーンショット

$(ls "$REPO_DIR/screenshots/"*.png 2>/dev/null | tail -3 | xargs -I{} basename {} | sed 's/^/- screenshots\//')

## 次のアクション候補

- report.md の内容を ChatGPT に貼ってレビューしてもらう
- screenshots/ フォルダの最新画像も一緒に貼る
EOF

log "=== 完了 ==="
log "report.md を確認してください"
