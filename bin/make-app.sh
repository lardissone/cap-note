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

run_swift_build() {
    case "$ARCH_MODE" in
        host)
            swift build -c release "${RPATH_FLAGS[@]}"
            ;;
        universal)
            swift build -c release --arch arm64 --arch x86_64 "${RPATH_FLAGS[@]}"
            ;;
        *)
            echo "Unknown arch mode: $ARCH_MODE (expected 'host' or 'universal')"
            exit 1
            ;;
    esac
}

run_swift_build

# SwiftPM (with swift-tools-version 5.x) generates a `Bundle.module`
# accessor that only looks for resource bundles next to
# `Bundle.main.bundleURL`. For a CLI binary that is the executable's
# directory, but for a real `.app` it is the .app root — and macOS
# requires that everything live under `Contents/`. Patch the generated
# accessor so it looks under `Contents/Resources/` instead, then
# re-build to pick the change up.
ACCESSOR_FILES=()
while IFS= read -r -d '' file; do
    ACCESSOR_FILES+=("$file")
done < <(find "$REPO_ROOT/.build" -type f -name "resource_bundle_accessor.swift" -path "*/release/*" -print0 2>/dev/null)

NEEDS_REBUILD=0
for accessor in "${ACCESSOR_FILES[@]}"; do
    if ! grep -q 'Contents/Resources' "$accessor"; then
        echo "==> Patching $(basename "$(dirname "$(dirname "$accessor")")")/resource_bundle_accessor.swift for .app layout"
        sed -i.bak \
            's|Bundle.main.bundleURL.appendingPathComponent|Bundle.main.bundleURL.appendingPathComponent("Contents/Resources").appendingPathComponent|' \
            "$accessor"
        rm -f "${accessor}.bak"
        NEEDS_REBUILD=1
    fi
done

if [[ $NEEDS_REBUILD -eq 1 ]]; then
    echo "==> Re-linking with patched resource accessors"
    run_swift_build
fi

case "$ARCH_MODE" in
    host)
        BIN_PATH="$REPO_ROOT/.build/release/$APP_NAME"
        ;;
    universal)
        BIN_PATH="$REPO_ROOT/.build/apple/Products/Release/$APP_NAME"
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

# SwiftPM resource bundles (e.g. KeyboardShortcuts_KeyboardShortcuts.bundle).
# Copied into `Contents/Resources/` — the standard macOS bundle layout.
# The patched resource accessor injected above looks for them there.
BUILD_PRODUCTS_DIR="$(cd "$(dirname "$BIN_PATH")" && pwd -P)"
echo "==> Copying SwiftPM resource bundles from $BUILD_PRODUCTS_DIR"
shopt -s nullglob
for bundle in "$BUILD_PRODUCTS_DIR"/*.bundle; do
    [[ -d "$bundle" ]] || continue
    bundle_name="$(basename "$bundle")"
    echo "    $bundle_name"
    cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/$bundle_name"
done
shopt -u nullglob

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
