#!/bin/bash
echo "📋 Recent KiroChatViewer logs (last 10 minutes):"
echo ""
log show --predicate 'subsystem == "com.kiro.chatviewer"' --last 10m --info --style compact
