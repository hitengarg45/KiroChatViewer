# KiroChatViewer

A native macOS application to view and search your Kiro CLI chat conversations.

## Current Version: 1.0.0

[Download Latest Release](Releases/KiroChatViewer-v1.0.0.dmg) (2.9 MB)

## Features

- 📝 View all saved Kiro CLI conversations
- 🔍 Search across conversation titles and content
- 📤 Export conversations to Markdown
- 🌓 Dark mode support
- 📅 Sort by recent activity
- 💬 Full markdown rendering (code blocks, formatting)
- 🎨 Custom app icon

## Installation

1. Download `KiroChatViewer-v1.0.0.dmg` from [Releases](Releases/)
2. Open the DMG file
3. Drag KiroChatViewer to your Applications folder
4. Launch from Applications or Spotlight

**First launch**: macOS may show security warning. Right-click → Open → Open anyway.

## Usage

The app automatically reads from your Kiro CLI database at:
```
~/Library/Application Support/kiro-cli/data.sqlite3
```

- Click any conversation to view its full history
- Use the search bar to filter conversations
- Click "Export to Markdown" to save a conversation

## Requirements

- macOS 13.0 (Ventura) or later

## Building from Source

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift build -c release
```

## Release Notes

### Version 1.0.0 (2026-02-14)

**Initial Release**

Features:
- ✅ Native macOS app with SwiftUI
- ✅ Read conversations from Kiro CLI SQLite database
- ✅ Support for both old and new conversation history formats
- ✅ Full markdown rendering with code syntax highlighting
- ✅ Search functionality across all conversations
- ✅ Export conversations to Markdown files
- ✅ Custom app icon
- ✅ Dark mode support
- ✅ Conversation list with auto-generated titles

Technical:
- Swift Package Manager
- SQLite.swift for database access
- swift-markdown-ui for rendering
- Handles 79+ conversations efficiently

## Documentation

- **[INSTALL.md](INSTALL.md)** - Installation instructions
- **[USAGE.md](USAGE.md)** - How to use the app
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Technical details

## License

MIT
