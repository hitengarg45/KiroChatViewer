#!/bin/bash
LOG_DIR="$HOME/Library/Application Support/KiroChatViewer/logs"
LOG_FILE="$LOG_DIR/app.log"

LINES=${1:-100}
CATEGORY=${2:-""}

echo "📋 Recent KiroChatViewer logs (last $LINES lines):"
echo "   Log dir: $LOG_DIR"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "⚠️  No log file found. Launch the app first."
    exit 1
fi

if [ -n "$CATEGORY" ]; then
    echo "   Filtering by: [$CATEGORY]"
    echo ""
    tail -n "$LINES" "$LOG_FILE" | grep "\[$CATEGORY\]"
else
    tail -n "$LINES" "$LOG_FILE"
fi

echo ""
echo "---"
# Show rotated log files
ROTATED=$(ls -la "$LOG_DIR"/app.*.log 2>/dev/null | wc -l | tr -d ' ')
echo "📁 Log files: app.log + $ROTATED rotated"
du -sh "$LOG_DIR" 2>/dev/null | awk '{print "💾 Total size: " $1}'
