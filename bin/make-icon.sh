#!/usr/bin/env bash
#
# Regenerate Resources/AppIcon.icns from the Swift source in
# bin/draw-icon.swift. Run this whenever the icon design changes.
#
#   bin/make-icon.sh
#
# The script renders a PNG for every size the macOS iconset format
# expects, packages them with `iconutil`, and writes the resulting
# .icns into Resources/. Intermediate PNGs are kept under
# Resources/AppIcon.iconset/ so iconutil can read them, and that
# directory is git-ignored.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRAW_SCRIPT="$REPO_ROOT/bin/draw-icon.swift"
RESOURCES_DIR="$REPO_ROOT/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"

if [[ ! -f "$DRAW_SCRIPT" ]]; then
    echo "Could not find $DRAW_SCRIPT"
    exit 1
fi

mkdir -p "$RESOURCES_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Standard macOS iconset entries. Each row is "<filename> <pixel size>".
ENTRIES=(
    "icon_16x16.png 16"
    "icon_16x16@2x.png 32"
    "icon_32x32.png 32"
    "icon_32x32@2x.png 64"
    "icon_128x128.png 128"
    "icon_128x128@2x.png 256"
    "icon_256x256.png 256"
    "icon_256x256@2x.png 512"
    "icon_512x512.png 512"
    "icon_512x512@2x.png 1024"
)

echo "==> Rendering icon PNGs"
for entry in "${ENTRIES[@]}"; do
    name="${entry%% *}"
    size="${entry##* }"
    out="$ICONSET_DIR/$name"
    swift "$DRAW_SCRIPT" "$size" "$out"
    echo "    $name (${size}px)"
done

echo "==> Packaging $ICNS_PATH"
iconutil --convert icns "$ICONSET_DIR" --output "$ICNS_PATH"

echo
echo "Wrote $ICNS_PATH ($(du -h "$ICNS_PATH" | cut -f1))"
