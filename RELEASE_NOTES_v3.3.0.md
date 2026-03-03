# KiroChatViewer v3.3.0 Release Notes

**Release Date**: 2026-03-03

## Backup & Recovery System

### New Features
- ✅ **Auto-backup on launch/reload**: Automatically backs up the Kiro CLI database on every app launch and reload (1-hour cooldown between backups)
- ✅ **Backup Now**: Manual backup option under Tools menu with confirmation dialog
- ✅ **Transparent backup merge**: App reads from both kiro-cli DB and latest backup simultaneously — missing conversations from backup appear automatically without any user action
- ✅ **kiro-cli DB always wins**: On duplicate conversations, the current kiro-cli database takes priority (most recent data)
- ✅ **Toast notification**: Subtle bottom-right toast when auto-backup completes ("Backed up recent chats")
- ✅ **Alert for manual backup**: "Backup successful" alert when using Backup Now
- ✅ **Max 3 backups**: Oldest backup pruned automatically when limit is reached
- ✅ **Backup location**: `~/Library/Application Support/KiroChatViewer/backups/`

### Bug Fixes
- ✅ **Fixed scroll reset on reload**: Conversation detail view no longer scrolls to top when refreshing the conversation list

## Technical Details
- Added `BackupManager.swift` — handles backup scheduling, file management, and toast/alert notifications
- `DatabaseManager` now reads from both kiro-cli DB and latest backup, merging in-memory
- Backup filenames: `data-<ISO8601-timestamp>.sqlite3`
- Removed restore-to-DB feature in favour of transparent in-memory merge
