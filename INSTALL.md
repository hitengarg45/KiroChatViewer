# Installation Guide

## Quick Install

1. **Open the DMG**:
   ```bash
   open ~/Documents/MyProjects/KiroChatViewer/KiroChatViewer.dmg
   ```

2. **Drag to Applications** (or double-click to run directly)

3. **First Launch**: 
   - macOS may show "unidentified developer" warning
   - Right-click the app → Open → Open anyway
   - Or: System Settings → Privacy & Security → Open Anyway

## Alternative: Run from Terminal

```bash
cd ~/Documents/MyProjects/KiroChatViewer
open KiroChatViewer.app
```

## Rebuild DMG (if needed)

```bash
cd ~/Documents/MyProjects/KiroChatViewer
swift build -c release
cp .build/release/KiroChatViewer KiroChatViewer.app/Contents/MacOS/
hdiutil create -volname "KiroChatViewer" -srcfolder KiroChatViewer.app -ov -format UDZO KiroChatViewer.dmg
```

## What's Included

- **KiroChatViewer.dmg** - Installable disk image (ready to use)
- **KiroChatViewer.app** - macOS application bundle
- Source code in `Sources/`

## Troubleshooting

### "App is damaged" error
```bash
xattr -cr ~/Documents/MyProjects/KiroChatViewer/KiroChatViewer.app
```

### App won't open
Make sure you have conversations in:
`~/Library/Application Support/kiro-cli/data.sqlite3`

### Rebuild from source
```bash
cd ~/Documents/MyProjects/KiroChatViewer
rm -rf .build KiroChatViewer.app KiroChatViewer.dmg
swift build -c release
# Then follow rebuild steps above
```
