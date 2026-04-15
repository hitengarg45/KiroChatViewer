# Release Notes — KiroChatViewer v3.6.1

**Date:** 2026-04-15

## Live Chat & ACP Enhancements

### Embedded Terminal
- Resume conversations in an embedded terminal directly inside the app
- Terminal sessions persist across conversation switches (no restart on switch back)
- Minimize/expand terminal with header-only collapsed state
- Resizable terminal panel with drag handle
- Theme-aware terminal colors matching selected terminal style
- Clean process lifecycle: SIGHUP on close, closeAll on app quit

### ACP Session Viewer
- New Terminal/ACP source switcher in sidebar
- Browse ACP sessions from `~/.kiro/sessions/cli/`
- View session events: prompts, assistant messages, tool results
- Session metadata: turn count, working directory, timestamps

### Live Chat Improvements
- Full model list with 18+ models (Claude, DeepSeek, Kimi, MiniMax, GLM, Qwen, AGI Nova)
- Tool approval system: approve/reject tool calls with native UI
- Autopilot mode: auto-approve all tools for trusted workflows
- Context usage indicator showing context window percentage
- Model switching mid-conversation via `session/set_model`
- Permission request handling with option selection

### Debug Console
- Bottom drawer debug console (Xcode-style) with resizable panel
- Category-based log filtering: database, ui, performance, acp
- Level filtering: DEBUG, INFO, NOTICE, ERROR
- Text search across log entries
- Auto-scroll toggle and clear button
- Category pill badges with counts

### File Logging
- Rotating file logs at `~/Library/Application Support/KiroChatViewer/logs/`
- 5 MB max per file, 3 rotated files kept
- Dual output: os.log + file for reliable debugging

## Bug Fixes
- Delete conversation now purges from all backup DBs (prevents reappearing on reload)
- Removed dead code: unused MarkdownCache and ContinueInTerminalButton

## Technical Details
- 12 commits since v3.6.0
- New files: EmbeddedTerminalView.swift, DebugConsoleView.swift, LiveChatView.swift, LiveChatViewModel.swift
- SwiftTerm dependency added for embedded terminal
- ACP protocol: initialize → session/new → session/prompt flow with streaming

## Download
- DMG: `KiroChatViewer-v3.6.1.dmg`
