#!/usr/bin/env bash
#
# Build CapNote.app from source.
#
#   bin/make-app.sh                  → builds for the host arch with version 0.0.0-dev
#   bin/make-app.sh 0.1.0            → builds for the host arch with the given version
#   bin/make-app.sh 0.1.0 universal  → builds a universal (arm64 + x86_64) bundle
#
# Code-signing identity is taken from the CODESIGN_IDENTITY environment
# variable. The default ("-") is ad-hoc, suitable for local development.
# When set to a real "Developer ID Application: ..." identity the script
# also enables hardened runtime and a secure timestamp, which is what
# notarization requires.

set -euo pipefail

VERSION="${1:-0.0.0-dev}"
ARCH_MODE="${2:-host}"
APP_NAME="CapNote"
BUNDLE_ID="io.capacities.cap-note"
DEPLOYMENT_TARGET="14.0"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Building $APP_NAME $VERSION ($ARCH_MODE)"

RPATH_FLAGS=(-Xlinker -rpath -Xlinker "@executable_path/../Frameworks")

case "$ARCH_MODE" in
    host)
        swift build -c release "${RPATH_FLAGS[@]}"
        BIN_PATH="$REPO_ROOT/.build/release/$APP_NAME"
        ;;
    universal)
        swift build -c release --arch arm64 --arch x86_64 "${RPATH_FLAGS[@]}"
        BIN_PATH="$REPO_ROOT/.build/apple/Products/Release/$APP_NAME"
        ;;
    *)
        echo "Unknown arch mode: $ARCH_MODE (expected 'host' or 'universal')"
        exit 1
        ;;
esac

if [[ ! -f "$BIN_PATH" ]]; then
    echo "Could not find built binary at $BIN_PATH"
    exit 1
fi

echo "==> Locating Sparkle.framework"
SPARKLE_FRAMEWORK_SRC="$(find "$REPO_ROOT/.build/artifacts" \
    -type d \
    -path "*Sparkle.xcframework/macos-*" \
    -name "Sparkle.framework" \
    | head -n 1 || true)"

if [[ -z "$SPARKLE_FRAMEWORK_SRC" ]]; then
    echo "Could not locate Sparkle.framework under .build/artifacts."
    echo "Run 'swift build -c release' once and retry."
    exit 1
fi
echo "    found: $SPARKLE_FRAMEWORK_SRC"

APP_BUNDLE="$REPO_ROOT/dist/$APP_NAME.app"
echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp -R "$SPARKLE_FRAMEWORK_SRC" "$APP_BUNDLE/Contents/Frameworks/"

ICON_SRC="$REPO_ROOT/Resources/AppIcon.icns"
if [[ ! -f "$ICON_SRC" ]]; then
    echo "Could not find $ICON_SRC. Run bin/make-icon.sh to generate it."
    exit 1
fi
cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Writing Info.plist"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>$DEPLOYMENT_TARGET</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://lardissone.github.io/cap-note/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Codesigning ($CODESIGN_IDENTITY)"
SPARKLE_DIR="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

# Strip pre-existing signatures so codesign isn't confused by Team ID
# differences between Sparkle's prebuilt artifact and our identity.
find "$APP_BUNDLE" -type d -name "_CodeSignature" -prune -exec rm -rf {} +

# Choose signing options based on whether this is ad-hoc or a real identity.
SIGN_OPTS=(--force)
PRESERVE_INNER_OPTS=()
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    SIGN_OPTS+=(--options runtime --timestamp)
    # Sparkle's XPC services and helper apps ship with specific
    # entitlements. Preserve them when re-signing so they keep working.
    PRESERVE_INNER_OPTS=(--preserve-metadata=entitlements,flags,runtime)
fi

# Sign innermost components first, then walk outwards.
shopt -s nullglob
for xpc in "$SPARKLE_DIR/Versions/B/XPCServices/"*.xpc; do
    codesign "${SIGN_OPTS[@]}" "${PRESERVE_INNER_OPTS[@]}" \
        --sign "$CODESIGN_IDENTITY" "$xpc"
done
shopt -u nullglob

if [[ -d "$SPARKLE_DIR/Versions/B/Updater.app" ]]; then
    codesign "${SIGN_OPTS[@]}" --deep "${PRESERVE_INNER_OPTS[@]}" \
        --sign "$CODESIGN_IDENTITY" \
        "$SPARKLE_DIR/Versions/B/Updater.app"
fi

if [[ -f "$SPARKLE_DIR/Versions/B/Autoupdate" ]]; then
    codesign "${SIGN_OPTS[@]}" "${PRESERVE_INNER_OPTS[@]}" \
        --sign "$CODESIGN_IDENTITY" \
        "$SPARKLE_DIR/Versions/B/Autoupdate"
fi

codesign "${SIGN_OPTS[@]}" --sign "$CODESIGN_IDENTITY" "$SPARKLE_DIR"
codesign "${SIGN_OPTS[@]}" --deep --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo
echo "Built $APP_BUNDLE ($VERSION)"
