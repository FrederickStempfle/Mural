#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

xcodebuild \
    -project Mural.xcodeproj \
    -scheme Mural \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath .build/xcode \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM='' \
    PROVISIONING_PROFILE_SPECIFIER='' \
    build

APP="$ROOT/dist/Mural.app"
rm -rf "$APP"
mkdir -p "$ROOT/dist"
ditto "$ROOT/.build/xcode/Build/Products/Release/Mural.app" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
