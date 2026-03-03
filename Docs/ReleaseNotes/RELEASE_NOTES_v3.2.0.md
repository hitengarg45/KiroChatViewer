# KiroChatViewer v3.2.0 Release Notes

**Release Date:** February 23, 2026

## What's New

### Runtime Logging & Debugging
- **Comprehensive Logging System**: Track app behavior with categorized logs (database, ui, performance)
- **Log Viewer Scripts**: 
  - `view_logs.sh` - Stream live logs in terminal
  - `show_recent_logs.sh` - View recent logs
- **Console.app Integration**: Filter logs with `subsystem:com.kiro.chatviewer`

### Export Improvements
- **Fixed Export Dialog**: Dialog now reopens correctly after canceling
- **Unique Filenames**: Auto-generated timestamps prevent overwrites
- **Success/Error Alerts**: Clear feedback when export completes or fails
- **Better Logging**: Track export operations for debugging

### UX Enhancements
- **Smooth Scroll to Bottom**: Conversations now consistently open at the bottom
- **Polished Animation**: Instant positioning with smooth final adjustment
- **Fixed LazyVStack Timing**: Proper rendering before scroll operations

## Technical Details

### Logging System
- **AppLogger.swift**: Centralized logging with os.log
- **Three Categories**:
  - `database` - Database operations, load times, errors
  - `ui` - User interactions, navigation, exports
  - `performance` - Metrics, timing, optimization data

### Export Fix
- Changed from `.constant()` binding to proper `@State` binding
- Filename format: `conversation-<id>-<timestamp>.md`
- Proper error handling with user-visible alerts

### Scroll Behavior
- Instant initial scroll (no visible animation)
- 50ms delay for LazyVStack rendering
- Smooth 300ms animated adjustment
- Works consistently across all conversations

## Installation

Download: [KiroChatViewer-v3.2.0.dmg](Releases/KiroChatViewer-v3.2.0.dmg)

## Requirements

- macOS 13.0 (Ventura) or later

## Upgrade Notes

This is a drop-in replacement for v3.1.2. Simply replace your existing app with the new version.

## Debugging

To view runtime logs:
```bash
# Stream live logs
./view_logs.sh

# View recent logs
./show_recent_logs.sh
```

Or use Console.app with filter: `subsystem:com.kiro.chatviewer`

## Known Issues

None

## Coming Soon

- HTML export feature (in development on feature/html-export branch)
- Additional performance optimizations
- Search improvements
