# KiroChatViewer v3.1.0 Release Notes

**Release Date**: February 19, 2026

## New Features

### 🏷️ Conversation Rename
- Rename conversations with custom titles
- Dialog-based rename interface
- Titles stored separately in `~/Library/Application Support/KiroChatViewer/titles.json`
- Kiro CLI database remains untouched

### 📌 Pin Conversations
- Pin important conversations to keep them at the top
- Blue pin icon indicator
- Works in both flat and grouped views
- Pinned conversations always appear first
- Stored in `~/Library/Application Support/KiroChatViewer/pinned.json`

### 🔄 Flexible Sorting
**Flat View:**
- Sort by Title (A-Z)
- Sort by Latest (newest first)
- Sort by Oldest (oldest first)

**Grouped View:**
- Sort by Name (alphabetical)
- Sort by Latest Conversation (most recent activity)
- Sort by Oldest Conversation (oldest activity)

Sort preferences persist separately for each view.

### 🚫 Filter Internal Conversations
- Automatically excludes Kiro CLI's internal conversations
- Hides `.title-generation` meta-conversations (62 entries)
- Only shows conversations from actual project directories

## Technical Details

### New Files
- `TitleManager.swift` - Manages custom titles and pinned state

### Data Storage
All customizations stored separately from Kiro CLI:
- `~/Library/Application Support/KiroChatViewer/titles.json` - Custom titles
- `~/Library/Application Support/KiroChatViewer/pinned.json` - Pinned conversations

### Database Safety
- No modifications to Kiro CLI database (except delete feature)
- All UI customizations stored in separate files
- Safe to use alongside Kiro CLI

## Upgrade Notes

Upgrading from v3.0.0 is seamless - no data migration required.

## Download

[KiroChatViewer-v3.1.0.dmg](../Releases/KiroChatViewer-v3.1.0.dmg)
