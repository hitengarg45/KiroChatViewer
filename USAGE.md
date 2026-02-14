# KiroChatViewer - Build & Run Guide

## ✅ Status: WORKING

The app successfully builds and runs, handling all 79 conversations in your database.

## Quick Start

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift run
```

The app will launch and display all your Kiro CLI conversations.

## What It Does

1. **Reads** from: `~/Library/Application Support/kiro-cli/data.sqlite3`
2. **Displays** all conversations sorted by most recent
3. **Handles** both old and new conversation formats automatically
4. **Shows** clean user/assistant message distinction
5. **Supports** search across all conversations
6. **Exports** to Markdown format

## UI Overview

```
┌─────────────────────────────────────────────────────┐
│  Kiro Chats                          [Refresh]      │
├──────────────┬──────────────────────────────────────┤
│              │                                       │
│ Conversation │  Conversation Title                  │
│ List         │  Directory: /path/to/project         │
│              │  Updated: 2 hours ago                │
│ [Search...]  │  ─────────────────────────────────   │
│              │                                       │
│ • Chat 1     │  👤 You                              │
│ • Chat 2     │  [User message here]                 │
│ • Chat 3     │                                       │
│              │  ✨ Kiro                             │
│              │  [Assistant response here]           │
│              │                                       │
└──────────────┴──────────────────────────────────────┘
```

## Features

✅ View all 79 conversations
✅ Sort by most recent activity
✅ Auto-generated titles from first message
✅ Search across all content
✅ Export individual conversations to Markdown
✅ Dark mode support (automatic)
✅ Native macOS look and feel

## Technical Details

- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Database**: SQLite via SQLite.swift
- **Platform**: macOS 13+
- **Format Support**: Handles both conversation history formats

## Troubleshooting

### App won't launch
```bash
# Rebuild from scratch
cd ~/Documents/MyProjects/KiroChatViewer
rm -rf .build
swift build
swift run
```

### Database not found
The app looks for: `~/Library/Application Support/kiro-cli/data.sqlite3`

Make sure you have kiro-cli installed and have had at least one conversation.

### No conversations showing
Check that the database exists and has data:
```bash
sqlite3 ~/Library/Application\ Support/kiro-cli/data.sqlite3 "SELECT COUNT(*) FROM conversations_v2;"
```

## Git Repository

```bash
cd ~/Documents/MyProjects/KiroChatViewer
git log --oneline
```

Current commits:
- Fix: Handle both conversation history formats
- Fix build errors
- Initial commit

## Next Steps

The app is fully functional! You can now:
1. Browse all your conversations
2. Search for specific topics
3. Export conversations you want to keep
4. Continue using kiro-cli - new conversations will appear automatically

Enjoy! 🎉
