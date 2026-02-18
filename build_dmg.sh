#!/bin/bash
set -e

# Beautiful DMG Builder for KiroChatViewer
# Usage: ./build_dmg.sh          - builds test DMG for development
#        ./build_dmg.sh release  - builds versioned release DMG

APP_NAME="KiroChatViewer"
VERSION="2.1.1"
SOURCE_APP="${APP_NAME}.app"
BACKGROUND_FILE="Resources/dmg_background.png"
CUSTOM_BACKGROUND="Resources/dmg_background_source.png"

if [ "$1" = "release" ]; then
    DMG_NAME="${APP_NAME}-v${VERSION}"
    VOLUME_NAME="${APP_NAME} v${VERSION}"
    echo "🚀 Building RELEASE DMG (v${VERSION})..."
else
    DMG_NAME="${APP_NAME}-test"
    VOLUME_NAME="${APP_NAME} Test"
    echo "🧪 Building TEST DMG..."
fi

OUTPUT_DMG="Releases/${DMG_NAME}.dmg"

# Resize custom background to fit DMG window (800x600)
if [ -f "${CUSTOM_BACKGROUND}" ]; then
    echo "🎨 Resizing custom background to fit DMG window..."
    python3 << 'PYTHON'
from PIL import Image
bg = Image.open('Resources/dmg_background_source.png')
bg_resized = bg.resize((800, 600), Image.Resampling.LANCZOS)
bg_resized.save('Resources/dmg_background.png')
PYTHON
elif [ ! -f "${BACKGROUND_FILE}" ]; then
    echo "🎨 Creating background image..."
    python3 << 'PYTHON'
from PIL import Image, ImageDraw, ImageFont

# Create 600x400 image with light gray background
width, height = 600, 400
img = Image.new('RGB', (width, height), color='#F5F5F5')
draw = ImageDraw.Draw(img)

# Kiro purple: #8B5CF6
purple = (139, 92, 246)

# Horizontal layout: [App] [Arrow + Text] [Applications]
# Center everything vertically
center_y = height // 2

# Arrow in the middle
arrow_y = center_y
arrow_start_x = 220
arrow_end_x = 380

# Arrow line
draw.line([(arrow_start_x, arrow_y), (arrow_end_x, arrow_y)], fill=purple, width=4)

# Arrow head
draw.polygon([
    (arrow_end_x, arrow_y),
    (arrow_end_x - 15, arrow_y - 10),
    (arrow_end_x - 15, arrow_y + 10)
], fill=purple)

# Text
try:
    font_medium = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
except:
    font_medium = ImageFont.load_default()

# "Drag to Install" text (above arrow, centered)
text = "Drag to Install"
bbox = draw.textbbox((0, 0), text, font=font_medium)
text_width = bbox[2] - bbox[0]
text_x = (arrow_start_x + arrow_end_x - text_width) // 2
text_y = arrow_y - 35  # Just above the arrow

draw.text((text_x, text_y), text, fill=purple, font=font_medium)

# Save
img.save('Resources/dmg_background.png')
PYTHON
fi

# Create temporary directory
TMP_DIR="/tmp/${APP_NAME}-dmg"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}/.background"

# Copy app
echo "📦 Copying app..."
cp -R "${SOURCE_APP}" "${TMP_DIR}/"

# Ad-hoc code sign so recipients don't get "app is damaged" error
echo "🔏 Code signing app..."
codesign --force --deep --sign - "${TMP_DIR}/${APP_NAME}.app"

# Copy background
cp "${BACKGROUND_FILE}" "${TMP_DIR}/.background/"

# Create Applications symlink
ln -s /Applications "${TMP_DIR}/Applications"

# Create temporary DMG
TMP_DMG="/tmp/${DMG_NAME}-temp.dmg"
rm -f "${TMP_DMG}"

echo "💿 Creating temporary DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
  -srcfolder "${TMP_DIR}" \
  -ov -format UDRW \
  "${TMP_DMG}" > /dev/null

# Mount it
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
echo "📂 Mounting DMG..."
hdiutil attach "${TMP_DMG}" > /dev/null
sleep 2

# Set window properties with AppleScript
echo "🎨 Styling DMG window..."
osascript << EOA
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {350, 200, 1150, 822}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:dmg_background.png"
        set position of item "${APP_NAME}.app" of container window to {170, 300}
        set position of item "Applications" of container window to {620, 300}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOA

# Make .background folder invisible
SetFile -a V "${MOUNT_DIR}/.background" 2>/dev/null || true

# Unmount
echo "💾 Finalizing..."
hdiutil detach "${MOUNT_DIR}" > /dev/null
sleep 1

# Convert to compressed
rm -f "${OUTPUT_DMG}"
hdiutil convert "${TMP_DMG}" -format UDZO -o "${OUTPUT_DMG}" > /dev/null

# Clean up
rm -f "${TMP_DMG}"
rm -rf "${TMP_DIR}"

echo "✅ Beautiful DMG created!"
ls -lh "${OUTPUT_DMG}"
