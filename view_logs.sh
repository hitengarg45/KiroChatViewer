#!/bin/bash
echo "🔍 Streaming KiroChatViewer logs..."
echo "Press Ctrl+C to stop"
echo ""

# Start app in background
open /Users/ghiten/Documents/MyProjects/KiroChatViewer/KiroChatViewer.app

# Stream logs
log stream --predicate 'subsystem == "com.kiro.chatviewer"' --level info
