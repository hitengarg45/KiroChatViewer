# KiroChatViewer v3.4.0 Release Notes

**Release Date**: 2026-03-08

## Settings & Theming

### New Features
- ✅ **Settings window** (⌘,) with sidebar navigation: About, Appearance, Conversations, Backup, Database
- ✅ **Theme system**: System, Light, Dark, and Kiro (deep purple) modes
- ✅ **Kiro theme**: Custom purple sidebar, background, and message bubble colors
- ✅ **Custom themes**: Create, edit, delete your own color themes with live preview
- ✅ **Font settings**: Font family picker (System, SF Pro, Helvetica Neue, Avenir Next, Georgia, Menlo, Monaco, Source Code Pro), size slider, line spacing slider
- ✅ **Apply/Restore Defaults**: Pending changes with Apply button, Restore Defaults with confirmation
- ✅ **About tab**: App icon, version, developer info, GitHub link

## Conversation Detail Improvements

### New Features
- ✅ **Chat-style layout**: User messages right-aligned, Kiro responses left-aligned
- ✅ **Full tool call details**: Arguments always visible with scroll, results with Show More/Less
- ✅ **Text wrapping**: No more horizontal scrolling for long tool arguments and results
- ✅ **Increased message spacing**: Better readability between messages

## Conversation List Improvements

### New Features
- ✅ **Terminal icon** on each conversation row
- ✅ **Message count** shown per conversation (e.g., "12 msgs")
- ✅ **Hover highlight** on non-selected conversations (skipped for selected row)
- ✅ **Visible separators** between conversation tiles
- ✅ **Grouped view**: Folder rows show chat count and latest time, right-side chevron, indented conversations
- ✅ **Cleaner rows**: Removed folder path from conversation tiles

## Bug Fixes
- ✅ Fixed conversation detail not updating on reload (updatedAt-based view identity)
- ✅ Fixed System theme not applying correctly when switching from Dark/Kiro
- ✅ Fixed three-dot menu not visible in dark themes
- ✅ Fixed Kiro theme background not applying to empty detail state
- ✅ Filtered out conversations from ~/Library/Application Support/

## Technical Details
- Added `ThemeManager.swift` — theme modes, built-in/custom themes, font settings
- Added `SettingsView.swift` — full Settings window with 5 tabs
- Updated `ContentView.swift` — theme integration, list styling, grouped view
- Updated `ConversationDetailView.swift` — chat layout, tool details
- Updated `Models.swift` — full args formatting
