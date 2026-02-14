# KiroChatViewer - Project Summary

## Overview
Native macOS application to view Kiro CLI chat history from SQLite database.

## Location
`~/Documents/MyProjects/KiroChatViewer`

## Features Implemented
✅ View all conversations sorted by most recent
✅ Auto-generated titles from first user message
✅ Search across all conversations (title + content)
✅ Clean message display with user/assistant distinction
✅ Export conversations to Markdown
✅ Dark mode support (automatic)
✅ Directory path display for each conversation
✅ Relative timestamps ("2 hours ago")

## Architecture

### Files Created
1. **App.swift** - SwiftUI app entry point
2. **Models.swift** - Data models (Conversation, Message)
3. **DatabaseManager.swift** - SQLite database access
4. **ContentView.swift** - Main list view with search
5. **ConversationDetailView.swift** - Detail view with export
6. **Package.swift** - Swift package configuration
7. **README.md** - User documentation

### Database Schema
- **Location**: `~/Library/Application Support/kiro-cli/data.sqlite3`
- **Table**: `conversations_v2`
- **Fields**: 
  - `key` (directory path)
  - `conversation_id` (UUID)
  - `value` (JSON with conversation data)
  - `created_at`, `updated_at` (timestamps)

### Dependencies
- SQLite.swift (0.15.0) - Database access
- SwiftUI - UI framework
- UniformTypeIdentifiers - File export

## How to Run

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift run
```

## How to Build

```bash
swift build
# Binary at: .build/debug/KiroChatViewer
```

## UI Structure
```
NavigationSplitView
├── Sidebar (List)
│   ├── Search bar
│   ├── Refresh button
│   └── Conversation rows
│       ├── Title (first 60 chars of first message)
│       ├── Directory name
│       └── Relative timestamp
└── Detail View
    ├── Conversation header
    │   ├── Full title
    │   ├── Directory path
    │   └── Updated timestamp
    ├── Export button
    └── Message list
        └── Message bubbles (user: blue, assistant: purple)
```

## Future Enhancements (Not Implemented)
- PDF export
- Date range filtering
- Conversation grouping by directory
- Full-text search highlighting
- Message syntax highlighting
- Copy individual messages
- Delete conversations

## Git Repository
Initialized with git at: `~/Documents/MyProjects/KiroChatViewer/.git`

## Build Status
✅ Successfully builds with `swift build`
✅ All compilation errors resolved
✅ Ready to run

## Notes
- Read-only access to database (no modifications)
- Handles 79 existing conversations in your database
- Minimal dependencies for simplicity
- Native macOS app (requires macOS 13+)
