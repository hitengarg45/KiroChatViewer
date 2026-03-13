#!/bin/bash
echo "🔍 Streaming KiroChatViewer logs..."
echo "Press Ctrl+C to stop"
echo ""

LOG_FILE="$HOME/Library/Application Support/KiroChatViewer/logs/app.log"

if [ "$1" = "--os-log" ]; then
    # Use macOS unified logging (may filter some messages)
    log stream --predicate 'subsystem == "com.kiro.chatviewer"' --level debug
elif [ -f "$LOG_FILE" ]; then
    # Default: tail the log file (reliable, shows everything)
    tail -f "$LOG_FILE"
else
    echo "⚠️  Log file not found. Launch the app first, or use --os-log for system logs."
    echo "   Expected: $LOG_FILE"
fi
