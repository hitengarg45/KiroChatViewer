# KiroChatViewer

A native macOS application to view and search your Kiro CLI chat conversations.

## Current Version: 1.0.1

[Download Latest Release](Releases/KiroChatViewer-v1.0.1.dmg) (2.7 MB)

## Features

- 📝 View all saved Kiro CLI conversations
- 🔍 Search across conversation titles and content
- 📤 Export conversations to Markdown
- 🌓 Light/Dark mode toggle
- 📅 Sort by recent activity
- 💬 Full markdown rendering (code blocks, formatting)
- 🎨 Custom app icon (V3, no padding)
- 🔄 Dual refresh buttons (list and conversation)
- ⬇️ Scroll to bottom button for easy navigation
- 💬 Conversations open at bottom showing latest messages

## Installation

### Quick Install

1. Download `KiroChatViewer-v1.0.1.dmg` from [Releases](Releases/)
2. Open the DMG file
3. Drag KiroChatViewer to your Applications folder (or double-click to run directly)
4. Launch from Applications or Spotlight

**First launch**: macOS may show "unidentified developer" warning. Right-click → Open → Open anyway, or go to System Settings → Privacy & Security → Open Anyway.

### Alternative: Run from Terminal

```bash
cd ~/Documents/MyProjects/KiroChatViewer
open KiroChatViewer.app
```

### Troubleshooting

**"App is damaged" error**:
```bash
xattr -cr ~/Documents/MyProjects/KiroChatViewer/KiroChatViewer.app
```

**App won't open**: Make sure you have conversations in `~/Library/Application Support/kiro-cli/data.sqlite3`

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
cp .build/release/KiroChatViewer KiroChatViewer.app/Contents/MacOS/
```

To create a DMG:
```bash
hdiutil create -volname "KiroChatViewer v1.0.0" -srcfolder KiroChatViewer.app -ov -format UDZO Releases/KiroChatViewer-v1.0.0.dmg
```

## Release Notes

### Version 1.0.1 (2026-02-16)

**UI/UX Improvements**

New Features:
- ✅ Dual refresh buttons (conversation list and current conversation)
- ✅ Scroll to bottom button for easy navigation
- ✅ Conversations now open at bottom showing latest messages
- ✅ Beautiful DMG installer with custom purple gradient background
- ✅ Updated app icon (V3) with padding removed
- ✅ Smooth animations for refresh operations
- ✅ Loading overlay during conversation refresh

Technical:
- Improved scroll behavior with instant jump to bottom
- Fixed refresh animations to work consistently
- Optimized DMG layout and window sizing
- Auto-resize background to fit DMG window perfectly

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
- ✅ Light/Dark mode toggle in toolbar
- ✅ Conversation list with auto-generated titles

Technical:
- Swift Package Manager
- SQLite.swift for database access
- swift-markdown-ui for rendering
- Handles 79+ conversations efficiently

## License

MIT
