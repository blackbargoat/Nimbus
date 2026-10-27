#!/bin/zsh
# Builds Nimbus.app into ./build (release, ad-hoc signed) for this Mac.
# For a universal .dmg to share, use ./scripts/package.sh instead.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Nimbus.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Nimbus "$APP/Contents/MacOS/Nimbus"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Optional shared Google key (kept out of git; see .gitignore).
[[ -f Resources/bundled-google-key ]] && cp Resources/bundled-google-key "$APP/Contents/Resources/"
codesign --force --sign - --identifier app.nimbus.classnotes \
    --entitlements Resources/Nimbus.entitlements "$APP"
echo "Built $APP"
