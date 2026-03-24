#!/bin/bash
# watcher.sh — request.md の変更を監視して自動実装を起動する
#
# 使い方:
#   bash scripts/watcher.sh          # フォアグラウンド実行
#   bash scripts/watcher.sh &        # バックグラウンド実行
#
# 停止:
#   Ctrl+C（フォアグラウンド）または kill $(cat scripts/watcher.pid)

REPO_DIR="/Users/sasakikyoutadashi/mannaka"
REQUEST_FILE="$REPO_DIR/request.md"
LOG_FILE="$REPO_DIR/scripts/watcher.log"
PID_FILE="$REPO_DIR/scripts/watcher.pid"

echo $$ > "$PID_FILE"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=============================="
log " Watcher 起動"
log " 監視ファイル: $REQUEST_FILE"
log " PID: $$"
log "=============================="

# request.md の最終更新時刻を記録
LAST_MODIFIED=""

# fswatch で監視
/opt/homebrew/bin/fswatch -o "$REQUEST_FILE" | while read -r; do
    CURRENT_MODIFIED=$(stat -f "%m" "$REQUEST_FILE" 2>/dev/null)

    if [ "$CURRENT_MODIFIED" = "$LAST_MODIFIED" ]; then
        continue
    fi
    LAST_MODIFIED="$CURRENT_MODIFIED"

    log "request.md が更新されました。実装を開始します..."

    # 実装スクリプト実行（ログに出力）
    bash "$REPO_DIR/scripts/implement.sh" 2>&1 | tee -a "$LOG_FILE"

    log "実装サイクル完了。次の更新を待機中..."
done
