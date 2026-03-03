# Release Workflow

## New Feature Development Process

### 1. Create Test Branch
```bash
git checkout -b test/feature-name
```

### 2. Development Phase
- Make all changes and commits on test branch
- Build frequently: `swift build -c release`
- Test thoroughly after each change

### 3. Create Test DMG (Optional)
```bash
cp .build/release/KiroChatViewer KiroChatViewer.app/Contents/MacOS/
hdiutil create -volname "KiroChatViewer Test" -srcfolder KiroChatViewer.app -ov -format UDZO test-build.dmg
```

### 4. Validation
- Test all features work as expected
- Verify no regressions
- Get user feedback if needed

### 5. Release (Only After Full Validation)
```bash
# Merge to main
git checkout main
git merge test/feature-name

# Update version
# Edit KiroChatViewer.app/Contents/Info.plist - update CFBundleShortVersionString and CFBundleVersion

# Build release
swift build -c release
cp .build/release/KiroChatViewer KiroChatViewer.app/Contents/MacOS/

# Create release DMG
hdiutil create -volname "KiroChatViewer vX.Y.Z" -srcfolder KiroChatViewer.app -ov -format UDZO Releases/KiroChatViewer-vX.Y.Z.dmg

# Update README.md with release notes

# Commit release
git add -A
git commit -m "Release vX.Y.Z - Description"

# Tag release
git tag -a vX.Y.Z -m "Version X.Y.Z - Description"

# Create release branch
git branch release/vX.Y.Z

# Clean up test branch
git branch -D test/feature-name
```

## Important Rules

1. **Never create release tags/branches until feature is fully tested**
2. **Always use test branches for development**
3. **Only merge to main when ready to release**
4. **Test DMGs before creating official release**
5. **Update context file after each release**

## Current Branches

- `main` - Stable releases only
- `release/vX.Y.Z` - Snapshot of each release
- `test/*` - Feature development and testing
