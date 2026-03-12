# Release Notes — KiroChatViewer v3.6.0

**Date:** 2026-03-13

## Performance & Polish

### Tool Result Truncation
- Large tool outputs (1000+ lines) no longer cause SwiftUI layout slowdowns
- Collapsed view: max 30 lines, expanded: max 150 lines
- "Show all N lines…" button loads full content on demand
- Line count displayed in header for large results
- Applies to all tool types: bash, grep, fs_read, code, AWS, web, glob

### fs_write Rendering Improvements
- `append` command now renders appended content in a blue-tinted code block
- `insert` command now renders inserted content in a blue-tinted code block
- Previously both fell through to generic args display

### Enhanced Performance Monitor
- Auto-captures app-wide metrics: conversations, total messages, avg msgs/conv, largest conversation, workspaces
- State metrics: titled, pinned, bookmarked counts
- Storage metrics: DB file size, estimated data size
- Sectioned popover UI with emoji headers (⏱ Timing, 📊 Data, 📌 State, 💾 Storage)
- "Live" badge replaces confusing reset button

### Performance Overhaul (from v3.5.0 development)
- Singleton observation fix: `@StateObject` → `@ObservedObject` for all singletons
- Database loading moved entirely off main thread (0ms blocking)
- Single SQLite query + single `@Published` update (was 4-5 re-renders)
- Async file I/O in TitleManager and BookmarkManager
- Cached `filteredConversations` with explicit invalidation
- Debounced search (300ms delay)
- Batched title generation publishes (groups of 3)
- Reversed ScrollView for instant bottom-first rendering
- `MessageView: Equatable` prevents unnecessary re-renders
- Loading indicator in sidebar during conversation load

### Test Suite
- Comprehensive tests using swift-testing framework
- Model edge case tests, bookmark tests, title tests, theme tests, utility tests

### Documentation
- Comprehensive optimization analysis document (30 optimizations evaluated)
- Detailed decision records with trigger thresholds for future revisits

## Technical Details
- macOS 14+ (Sonoma) minimum
- Swift 6.0 toolchain with Swift 5 language mode
- 4 files changed, 517 insertions in optimization branch

## Download
- DMG: `KiroChatViewer-v3.6.0.dmg`
