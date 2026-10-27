#!/bin/zsh
# Builds a downloadable Nimbus: universal (Apple Silicon + Intel) app packaged as
# dist/Nimbus-<version>.dmg, and copies it into the website's downloads folder.
#
# With a "Developer ID Application" certificate and a notary profile saved as
# "Nimbus" (xcrun notarytool store-credentials Nimbus ...), the app and DMG are
# signed and notarized so they open with a double-click. Without them it builds
# ad-hoc, and users approve it once in Privacy & Security > Open Anyway.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
PROFILE=${NOTARY_PROFILE:-Nimbus}
DIST=dist
STAGE=$DIST/stage
APP=$STAGE/Nimbus.app
DMG=$DIST/Nimbus-$VERSION.dmg

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
if [[ -n "$IDENTITY" ]] && xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    MODE=notarized
else
    MODE=adhoc
fi
echo "-> $MODE build of Nimbus $VERSION"

swift build -c release --arch arm64 --arch x86_64 >/dev/null

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/Nimbus "$APP/Contents/MacOS/Nimbus"
# Drop debug info (it records local build paths such as your home folder).
strip -S -x "$APP/Contents/MacOS/Nimbus"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Optional shared Google key (kept out of git; see .gitignore).
[[ -f Resources/bundled-google-key ]] && cp Resources/bundled-google-key "$APP/Contents/Resources/"
xattr -cr "$APP"

if [[ $MODE == notarized ]]; then
    codesign --force --timestamp --options runtime --entitlements Resources/Nimbus.entitlements --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - --identifier app.nimbus.classnotes --entitlements Resources/Nimbus.entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"

if [[ $MODE == notarized ]]; then
    ditto -c -k --keepParent "$APP" "$DIST/notarize.zip"
    xcrun notarytool submit "$DIST/notarize.zip" --keychain-profile "$PROFILE" --wait
    rm "$DIST/notarize.zip"
    xcrun stapler staple "$APP"
fi

cp "scripts/How to open Nimbus.txt" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Nimbus" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"

if [[ $MODE == notarized ]]; then
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
fi
rm -rf "$STAGE"

mkdir -p ../web/public/downloads
cp "$DMG" ../web/public/downloads/Nimbus.dmg
echo "Done: $DMG (also copied to web/public/downloads)"
ls -lh "$DIST"
