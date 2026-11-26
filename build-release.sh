#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="TextAnonymizer.xcodeproj"
SCHEME="TextAnonymizer"

BUILD_DIR="/tmp/text-anonymizer-release"
APP_NAME="AI Text Anon.app"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"

ZIP_NAME="AI Text Anon.zip"
ZIP_PATH="$HOME/Downloads/$ZIP_NAME"

ICON_MASTER="$PROJECT_DIR/ContentAnonymizerIcon_v2_1024x1024.png"
ICON_ASSET_DIR="$PROJECT_DIR/Sources/TextAnonymizer/Resources/Assets.xcassets/AppIcon.appiconset"

generate_icon_variant() {
  local pixel_size="$1"
  local filename="$2"

  /usr/bin/sips -z "$pixel_size" "$pixel_size" "$ICON_MASTER" \
    --out "$ICON_ASSET_DIR/$filename" >/dev/null
}

echo ""
echo "========================================"
echo "AI Text Anon - Release Build"
echo "========================================"
echo ""

cd "$PROJECT_DIR"

echo "1. Updating AppIcon variants from V2 master..."
echo ""

if [ ! -f "$ICON_MASTER" ]; then
  echo "ERROR: App icon master not found at:"
  echo "$ICON_MASTER"
  exit 1
fi

generate_icon_variant 16 "ContentAnonymizerIcon_16x16.png"
generate_icon_variant 32 "ContentAnonymizerIcon_16x16@2x.png"
generate_icon_variant 32 "ContentAnonymizerIcon_32x32.png"
generate_icon_variant 64 "ContentAnonymizerIcon_32x32@2x.png"
generate_icon_variant 128 "ContentAnonymizerIcon_128x128.png"
generate_icon_variant 256 "ContentAnonymizerIcon_128x128@2x.png"
generate_icon_variant 256 "ContentAnonymizerIcon_256x256.png"
generate_icon_variant 512 "ContentAnonymizerIcon_256x256@2x.png"
generate_icon_variant 512 "ContentAnonymizerIcon_512x512.png"
generate_icon_variant 1024 "ContentAnonymizerIcon_512x512@2x.png"

echo "AppIcon variants updated."
echo ""

echo "2. Running tests..."
echo ""

xcodebuild test \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS'

echo ""
echo "Tests passed."
echo ""

echo "3. Removing previous Release build..."
rm -rf "$BUILD_DIR"

echo ""
echo "4. Building Release..."
echo ""

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build

echo ""
echo "Release build completed."
echo ""

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: App was not created at:"
  echo "$APP_PATH"
  exit 1
fi

echo "5. Creating ZIP in Downloads..."
echo ""

rm -f "$ZIP_PATH"

ditto -c -k --keepParent \
  "$APP_PATH" \
  "$ZIP_PATH"

echo ""
echo "ZIP created."
echo ""

echo "========================================"
echo "Release completed successfully"
echo "========================================"
echo ""
echo "App:"
echo "$APP_PATH"
echo ""
echo "ZIP:"
echo "$ZIP_PATH"
echo ""

read -r -p "Open the Release app now? [y/N] " OPEN_APP

if [[ "$OPEN_APP" =~ ^[Yy]$ ]]; then
  open "$APP_PATH"
fi

echo ""

read -r -p "Copy the Release app to /Applications? [y/N] " INSTALL_APP

if [[ "$INSTALL_APP" =~ ^[Yy]$ ]]; then
  echo ""

  if [ -d "/Applications/$APP_NAME" ]; then
    echo "Removing existing version from /Applications..."
    rm -rf "/Applications/$APP_NAME"
  fi

  echo "Copying app..."
  cp -R "$APP_PATH" "/Applications/"

  echo ""
  echo "Installed:"
  echo "/Applications/$APP_NAME"
fi

echo ""
echo "Done."
