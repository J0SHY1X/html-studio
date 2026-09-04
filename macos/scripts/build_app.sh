#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
if [[ -z ${SDKROOT:-} ]]; then
  export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
fi
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/clang-module-cache"

swift build --disable-sandbox -c release --package-path "$PROJECT_ROOT" --product HTMLStudio
BUILD_BIN=$(swift build --disable-sandbox -c release --package-path "$PROJECT_ROOT" --show-bin-path)
DIST_DIR="$PROJECT_ROOT/dist"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/Resources/Info.plist")
ARCH=$(uname -m)
STAGE_DIR=$(mktemp -d /private/tmp/html-studio-build.XXXXXX)
trap 'rm -rf "$STAGE_DIR"' EXIT
APP_DIR="$STAGE_DIR/HTML Studio.app"
DIST_APP_DIR="$DIST_DIR/HTML Studio.app"
ZIP_PATH="$DIST_DIR/HTML Studio-macOS-$ARCH-$VERSION.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp -f "$BUILD_BIN/HTMLStudio" "$MACOS_DIR/HTMLStudio"
cp -f "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]]; then
  cp -f "$PROJECT_ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
  ICON_WORK=$(mktemp -d)
  ICONSET_DIR="$ICON_WORK/AppIcon.iconset"
  ICON_GENERATOR="$ICON_WORK/icon-generator"
  swiftc -sdk "$SDKROOT" \
    -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
    "$PROJECT_ROOT/Tools/IconGenerator.swift" \
    -o "$ICON_GENERATOR"
  "$ICON_GENERATOR" "$ICONSET_DIR"
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

chmod +x "$MACOS_DIR/HTMLStudio"
xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

mkdir -p "$DIST_DIR"
rm -rf -- "$DIST_APP_DIR"
ditto --norsrc "$APP_DIR" "$DIST_APP_DIR"
xattr -cr "$DIST_APP_DIR"
codesign --verify --deep --strict --verbose=2 "$DIST_APP_DIR"
ditto -c -k --keepParent --norsrc "$APP_DIR" "$ZIP_PATH"

echo "$DIST_APP_DIR"
echo "$ZIP_PATH"
