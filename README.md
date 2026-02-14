# KiroChatViewer

Native macOS app to view Kiro CLI chat history.

## Features
- ✅ View all conversations sorted by recent activity
- ✅ Auto-generated titles from first message
- ✅ Search across all conversations
- ✅ Clean message display (user/assistant distinction)
- ✅ Export to Markdown
- ✅ Dark mode support (automatic)

## Build & Run

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift build
swift run
```

## Database
Reads from: `~/Library/Application Support/kiro-cli/data.sqlite3`

## Architecture
- SwiftUI for UI
- SQLite.swift for database access
- Minimal dependencies
