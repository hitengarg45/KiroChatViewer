# KiroChatViewer

Native macOS application to view Kiro CLI chat history.

## 🚀 Quick Start

**Double-click to install:**
```
KiroChatViewer.dmg (778 KB)
```

Or from terminal:
```bash
open ~/Documents/MyProjects/KiroChatViewer/KiroChatViewer.dmg
```

**First launch**: macOS may show security warning. Right-click → Open → Open anyway.

## Features
- ✅ View all conversations sorted by recent activity
- ✅ Auto-generated titles from first message
- ✅ Search across all conversations
- ✅ Clean message display (user/assistant distinction)
- ✅ Export to Markdown
- ✅ Dark mode support (automatic)

## Documentation

- **[INSTALL.md](INSTALL.md)** - Installation instructions
- **[USAGE.md](USAGE.md)** - How to use the app
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical details

## Build from Source

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift build -c release
```

## Database
Reads from: `~/Library/Application Support/kiro-cli/data.sqlite3`

## Architecture
- SwiftUI for UI
- SQLite.swift for database access
- Minimal dependencies
- Native macOS (requires macOS 13+)
