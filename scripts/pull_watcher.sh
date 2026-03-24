#!/bin/bash
# pull_watcher.sh — GitHubの更新を30秒ごとにチェックしてauto pull
# VS Codeで開いているフォルダが自動で更新される
#
# 使い方: bash scripts/pull_watcher.sh &

REPO_DIR="/Users/sasakikyoutadashi/mannaka"
LOG_FILE="$REPO_DIR/scripts/pull_watcher.log"
INTERVAL=30  # 秒

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "Pull Watcher 起動 (${INTERVAL}秒ごとにチェック)"

while true; do
    cd "$REPO_DIR"

    # リモートの最新を取得（fetchのみ）
    git fetch origin main --quiet 2>/dev/null

    # ローカルとリモートの差分チェック
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)

    if [ "$LOCAL" != "$REMOTE" ]; then
        log "新しいコミットを検出。Pull します..."
        git pull origin main --rebase --quiet 2>&1 | tee -a "$LOG_FILE"
        log "Pull完了: $(git log --oneline -1)"

        # flutter packages get（pubspec.yaml が変わった場合のため）
        if git diff HEAD~1 --name-only 2>/dev/null | grep -q "pubspec.yaml"; then
            log "pubspec.yaml変更検出 → flutter pub get"
            flutter pub get 2>&1 | tail -3 | tee -a "$LOG_FILE"
        fi
    fi

    sleep "$INTERVAL"
done
