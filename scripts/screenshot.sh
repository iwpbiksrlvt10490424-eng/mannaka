#!/bin/bash
# screenshot.sh — シミュレーターのスクリーンショットを取得する

DEVICE_ID="366D236E-C477-41BC-A9B1-C80FB6044606"
OUTPUT_PATH="${1:-/Users/sasakikyoutadashi/mannaka/screenshots/ui_$(date '+%Y%m%d_%H%M%S').png}"

# シミュレーターが起動しているか確認
DEVICE_STATE=$(xcrun simctl list devices | grep "$DEVICE_ID" | grep -o 'Booted\|Shutdown' | head -1)

if [ "$DEVICE_STATE" != "Booted" ]; then
    echo "シミュレーターが起動していません。起動します..."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
    sleep 5
fi

# スクリーンショット取得
xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_PATH"
echo "スクリーンショット保存: $OUTPUT_PATH"
