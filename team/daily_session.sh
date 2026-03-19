#!/bin/bash
# ================================================================
# まんなかアプリ 自律開発チームセッション
# 実行: 平日 07:00 自動起動（最大5時間）
# チーム: PM → Engineer → Critic → Security → Fix → QA
# ================================================================

set -uo pipefail

# PATH設定（cronはPATHが空なので必須）
export PATH="/Users/sasakikyoutadashi/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export HOME="/Users/sasakikyoutadashi"
export FLUTTER_ROOT="$HOME/fvm/default"
export PATH="$FLUTTER_ROOT/bin:$PATH"

CLAUDE_BIN="/Users/sasakikyoutadashi/.local/bin/claude"
WORK_DIR="$HOME/mannaka"
TEAM_DIR="$WORK_DIR/team"
WORKSPACE="$TEAM_DIR/workspace"
REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="$TEAM_DIR/reports/$REPORT_DATE.md"
SESSION_LOG="$TEAM_DIR/reports/${REPORT_DATE}_session.log"

SESSION_START_EPOCH=$(date +%s)
MAX_DURATION=$((5 * 60 * 60))   # 5時間 = 18000秒（時間が来たら途中でも止まる）
CYCLES=20                         # 上限サイクル数（時間制限が先に効く）

mkdir -p "$TEAM_DIR/reports" "$WORKSPACE"

# ================================================================
# ユーティリティ
# ================================================================

log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo "$msg" | tee -a "$SESSION_LOG"
}

append_report() {
    echo "$1" >> "$REPORT_FILE"
}

time_remaining_min() {
    local now=$(date +%s)
    local elapsed=$((now - SESSION_START_EPOCH))
    echo $(( (MAX_DURATION - elapsed) / 60 ))
}

check_time_limit() {
    local now=$(date +%s)
    local elapsed=$((now - SESSION_START_EPOCH))
    [ $elapsed -lt $MAX_DURATION ]
}

run_agent() {
    local role="$1"
    local prompt_file="$2"
    local output_file="$3"

    log "▶ [$role] 起動中..."

    local prompt
    prompt=$(cat "$prompt_file")

    local result
    if result=$(cd "$WORK_DIR" && "$CLAUDE_BIN" --dangerously-skip-permissions -p "$prompt" 2>&1); then
        echo "$result" > "$output_file"
        local lines
        lines=$(wc -l < "$output_file" | tr -d ' ')
        log "✓ [$role] 完了 (${lines}行)"
    else
        local code=$?
        log "✗ [$role] 失敗 (exit $code)"
        echo "ERROR: $role agent failed with exit code $code" > "$output_file"
    fi
}

count_issues() {
    grep -c "ISSUE\|WARNING\|CRITICAL\|問題\|要修正\|❌\|ISSUES_FOUND" "$@" 2>/dev/null || echo "0"
}

# ================================================================
# レポートヘッダー
# ================================================================

cat > "$REPORT_FILE" << HEADER
# まんなかアプリ 自律開発レポート

| 項目 | 内容 |
|------|------|
| 日付 | $REPORT_DATE |
| 開始時刻 | $(date '+%H:%M') |
| 最大実行時間 | 5時間 |
| 予定サイクル数 | $CYCLES |

---

HEADER

log "============================================"
log "  まんなか 自律開発チームセッション 開始"
log "  日時: $REPORT_DATE $(date '+%H:%M')"
log "  最大実行時間: 5時間 / サイクル数: $CYCLES"
log "============================================"

# ================================================================
# メインサイクルループ
# ================================================================

COMPLETED_CYCLES=0

for CYCLE in $(seq 1 $CYCLES); do

    check_time_limit || {
        log "⏰ 制限時間到達。セッション終了（残り$(time_remaining_min)分）"
        break
    }

    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  CYCLE $CYCLE / $CYCLES 開始"
    log "  残り時間: $(time_remaining_min)分"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    append_report ""
    append_report "## サイクル $CYCLE"
    append_report ""
    append_report "> 開始: $(date '+%H:%M')  残り時間: $(time_remaining_min)分"
    append_report ""

    # ------------------------------------------------------------
    # STEP 1: PM — タスク選定
    # ------------------------------------------------------------
    log "[STEP 1/6] PM: タスク選定"
    run_agent "PM" "$TEAM_DIR/agents/pm_prompt.md" "$WORKSPACE/current_task.md"

    append_report "### 📋 PM: タスク選定"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/current_task.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    check_time_limit || { log "⏰ 時間切れ（PM後）"; break; }

    # ------------------------------------------------------------
    # STEP 2: TDD Tester — 失敗テストを先に書く（Red）
    # ------------------------------------------------------------
    log "[STEP 2/7] TDD Tester: テスト設計（Red）"
    run_agent "TDD Tester" "$TEAM_DIR/agents/tdd_tester_prompt.md" "$WORKSPACE/tdd_tests.md"

    append_report "### TDD Tester: テスト設計（Red）"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/tdd_tests.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    check_time_limit || { log "⏰ 時間切れ（TDD Tester後）"; break; }

    # ------------------------------------------------------------
    # STEP 3: Engineer — テストを通す実装（Green → Refactor）
    # ------------------------------------------------------------
    log "[STEP 3/7] Engineer: 実装（Green → Refactor）"
    run_agent "Engineer" "$TEAM_DIR/agents/engineer_prompt.md" "$WORKSPACE/implementation_notes.md"

    append_report "### Engineer: 実装（Green → Refactor）"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/implementation_notes.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    check_time_limit || { log "⏰ 時間切れ（Engineer後）"; break; }

    # ------------------------------------------------------------
    # STEP 4: Critic — コードレビュー
    # ------------------------------------------------------------
    log "[STEP 4/7] Critic: コードレビュー"
    run_agent "Critic" "$TEAM_DIR/agents/critic_prompt.md" "$WORKSPACE/review_feedback.md"

    append_report "### Critic: コードレビュー"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/review_feedback.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    check_time_limit || { log "⏰ 時間切れ（Critic後）"; break; }

    # ------------------------------------------------------------
    # STEP 5: Security — セキュリティレビュー
    # ------------------------------------------------------------
    log "[STEP 5/7] Security: セキュリティレビュー"
    run_agent "Security" "$TEAM_DIR/agents/security_prompt.md" "$WORKSPACE/security_report.md"

    append_report "### Security: セキュリティレビュー"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/security_report.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    # ------------------------------------------------------------
    # STEP 6: Fix — 問題修正（問題があった場合のみ）
    # ------------------------------------------------------------
    ISSUE_COUNT=$(count_issues "$WORKSPACE/review_feedback.md" "$WORKSPACE/security_report.md")

    if [ "$ISSUE_COUNT" -gt 0 ]; then
        check_time_limit || { log "⏰ 時間切れ（Security後）"; break; }

        log "[STEP 6/7] Engineer(Fix): 問題修正 (${ISSUE_COUNT}件検出)"
        run_agent "Engineer(Fix)" "$TEAM_DIR/agents/fix_prompt.md" "$WORKSPACE/fix_notes.md"

        append_report "### Engineer(Fix): 修正"
        append_report ""
        append_report '```'
        cat "$WORKSPACE/fix_notes.md" >> "$REPORT_FILE"
        append_report '```'
        append_report ""
    else
        log "[STEP 6/7] Fix: スキップ（問題なし）"
        echo "問題なし - 修正不要" > "$WORKSPACE/fix_notes.md"
    fi

    # ------------------------------------------------------------
    # STEP 7: QA — 最終確認
    # ------------------------------------------------------------
    check_time_limit || { log "⏰ 時間切れ（Fix後）"; break; }

    log "[STEP 7/7] QA: 最終確認"
    run_agent "QA" "$TEAM_DIR/agents/qa_prompt.md" "$WORKSPACE/qa_report.md"

    append_report "### ✅ QA: 最終確認"
    append_report ""
    append_report '```'
    cat "$WORKSPACE/qa_report.md" >> "$REPORT_FILE"
    append_report '```'
    append_report ""

    # バックログ自動更新
    TASK_NAME=$(grep -A1 "^## タスク名" "$WORKSPACE/current_task.md" 2>/dev/null | tail -1 | tr -d ' ' || echo "")
    if [ -n "$TASK_NAME" ]; then
        QA_RESULT=$(grep "判定" "$WORKSPACE/qa_report.md" 2>/dev/null || echo "")
        if echo "$QA_RESULT" | grep -q "APPROVED"; then
            log "📝 バックログ更新: '$TASK_NAME' を完了マーク"
            BACKLOG_PROMPT="~/mannaka/team/backlog.md を読み、タスク「${TASK_NAME}」のステータスを [✅] 完了に変更し、完了済みセクションに移動してください。ファイルを直接編集してください。"
            cd "$WORK_DIR" && "$CLAUDE_BIN" --dangerously-skip-permissions -p "$BACKLOG_PROMPT" > /dev/null 2>&1 || true
        fi
    fi

    COMPLETED_CYCLES=$CYCLE

    append_report ""
    append_report "> サイクル $CYCLE 完了: $(date '+%H:%M')"
    append_report ""
    append_report "---"

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  CYCLE $CYCLE 完了 $(date '+%H:%M')"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

done

# ================================================================
# 週次マーケティングレポート（金曜日のみ）
# ================================================================

if [ "$(date +%u)" = "5" ] && check_time_limit; then
    log ""
    log "📣 [Marketing] 週次レポート生成（金曜日）"

    run_agent "Marketing" "$TEAM_DIR/agents/marketing_prompt.md" "$WORKSPACE/marketing_report.md"

    append_report ""
    append_report "## 📣 週次マーケティングレポート"
    append_report ""
    cat "$WORKSPACE/marketing_report.md" >> "$REPORT_FILE"
fi

# ================================================================
# サマリー生成
# ================================================================

SESSION_END_EPOCH=$(date +%s)
DURATION_SEC=$((SESSION_END_EPOCH - SESSION_START_EPOCH))
DURATION_MIN=$((DURATION_SEC / 60))

log ""
log "📊 サマリー生成中..."

SUMMARY_PROMPT="まんなかFlutterアプリの今日の開発セッションが完了しました。
以下のファイルを確認して、開発者が帰宅後に読む日本語サマリーを作成してください：
- ~/mannaka/team/workspace/qa_report.md（最終QA結果）
- ~/mannaka/team/workspace/implementation_notes.md（実装内容）
- ~/mannaka/team/backlog.md（残タスク）

フォーマット:
## 今日の成果（1-3行）
## 明日の最優先タスク（1つ）
## 開発者へのメッセージ（激励・注意点など1行）"

SUMMARY=$(cd "$WORK_DIR" && "$CLAUDE_BIN" --dangerously-skip-permissions -p "$SUMMARY_PROMPT" 2>&1 || echo "サマリー生成に失敗しました。各セクションのレポートを直接ご確認ください。")

cat >> "$REPORT_FILE" << FOOTER

---

## セッションサマリー

| 項目 | 内容 |
|------|------|
| 実行日 | $REPORT_DATE |
| 開始 | $(date -r $SESSION_START_EPOCH '+%H:%M') |
| 終了 | $(date '+%H:%M') |
| 所要時間 | ${DURATION_MIN}分 |
| 完了サイクル | ${COMPLETED_CYCLES} / ${CYCLES} |

$SUMMARY

---
_このレポートは自律開発チームが自動生成しました_
FOOTER

log ""
log "============================================"
log "  セッション完了！"
log "  所要時間: ${DURATION_MIN}分"
log "  完了サイクル: ${COMPLETED_CYCLES}/${CYCLES}"
log "  レポート: $REPORT_FILE"
log "============================================"
log "  帰宅後はレポートを確認してください 🏠"
log "============================================"
