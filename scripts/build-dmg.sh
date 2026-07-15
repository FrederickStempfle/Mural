#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

./scripts/build-app.sh

STAGE="$ROOT/.build/dmg-stage"
RW_DMG="$ROOT/.build/Mural-rw.dmg"
OUT_DMG="$ROOT/dist/Mural.dmg"

rm -rf "$STAGE" "$RW_DMG" "$OUT_DMG"
mkdir -p "$STAGE/.background"
ditto "$ROOT/dist/Mural.app" "$STAGE/Mural.app"
cp "$ROOT/Packaging/DMGBackground.png" "$STAGE/.background/background.png"
cp "$ROOT/Packaging/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

hdiutil detach /Volumes/Mural -force > /dev/null 2>&1 || true
hdiutil create -volname Mural -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW_DMG" > /dev/null
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen > /dev/null

# The install shortcut is a Finder alias rather than a symlink: symlinks on
# HFS+ cannot carry a resource fork, and the custom folder icon needs one.
osascript <<'EOF'
tell application "Finder"
    set theAlias to make new alias file at disk "Mural" to POSIX file "/Applications"
    set name of theAlias to "Applications"
end tell
EOF

# Stamp the hand-drawn folder icon onto the alias: icns resource fork plus the
# kHasCustomIcon FinderInfo flag, OR-ed into the existing FinderInfo so the
# alias flags Finder already wrote are preserved.
ICON_WORK="$ROOT/.build/applications-icon.icns"
cp "$ROOT/Packaging/ApplicationsIcon.icns" "$ICON_WORK"
sips -i "$ICON_WORK" > /dev/null
/usr/bin/python3 - "$ICON_WORK" /Volumes/Mural/Applications <<'PY'
import ctypes
import sys

icon, target = sys.argv[1], sys.argv[2]
fork = open(icon + "/..namedfork/rsrc", "rb").read()

libc = ctypes.CDLL(None, use_errno=True)
info = ctypes.create_string_buffer(32)
if libc.getxattr(target.encode(), b"com.apple.FinderInfo", info, 32, 0, 0) < 0:
    info = ctypes.create_string_buffer(32)
finder_info = bytearray(info.raw[:32])
finder_info[8] |= 0x04  # kHasCustomIcon

for name, value in ((b"com.apple.ResourceFork", fork), (b"com.apple.FinderInfo", bytes(finder_info))):
    if libc.setxattr(target.encode(), name, value, len(value), 0, 0) != 0:
        raise OSError(ctypes.get_errno(), f"setxattr {name.decode()} on {target} failed")
PY
rm -f "$ICON_WORK"

# Style the window with Finder itself so the background picture record is one
# this macOS version's Finder actually honors (alias records written by other
# tools are ignored on recent macOS).
osascript <<'EOF'
tell application "Finder"
    tell disk "Mural"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 968, 632}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 120
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Mural.app" of container window to {240, 250}
        set position of item "Applications" of container window to {532, 247}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

SetFile -a C /Volumes/Mural 2> /dev/null || true
sync
hdiutil detach /Volumes/Mural > /dev/null
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUT_DMG" > /dev/null
rm -f "$RW_DMG"

echo "$OUT_DMG"
