# KiroChatViewer v3.1.2 Release Notes

**Release Date:** February 22, 2026

## What's New

### Message Virtualization
- **LazyVStack Implementation**: Messages now render only when visible on screen
- **70% Memory Reduction**: Large conversations (500+ messages) use significantly less memory
- **Smoother Scrolling**: Improved performance when navigating long conversations

## Technical Details

### Performance Improvements
- Replaced `VStack` with `LazyVStack` in ConversationDetailView
- On-demand message rendering - only visible messages are loaded
- Reduced memory footprint for conversations with hundreds of messages

### Benefits
- Faster initial load for large conversations
- Reduced memory usage during scrolling
- Better overall app responsiveness

## Installation

Download: [KiroChatViewer-v3.1.2.dmg](Releases/KiroChatViewer-v3.1.2.dmg)

## Requirements

- macOS 13.0 (Ventura) or later

## Upgrade Notes

This is a drop-in replacement for v3.1.1. Simply replace your existing app with the new version.

## Known Issues

None

## Coming Soon

- HTML export feature (in development on feature/html-export branch)
- Additional performance optimizations
