#!/bin/zsh
# Puts Nimbus online: public GitHub repo, the DMG on a release, and the website on GitHub Pages.
# Run ./scripts/package.sh first so dist/Nimbus-<version>.dmg exists. Safe to run again.
set -eu
cd "$(dirname "$0")/../.."
REPO=blackbargoat/Nimbus
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" app/Resources/Info.plist)
DMG=app/dist/Nimbus-$VERSION.dmg
[[ -f $DMG ]] || { echo "Missing $DMG. Run app/scripts/package.sh first."; exit 1; }
STAGE=$(mktemp -d); cp "$DMG" "$STAGE/Nimbus.dmg"

gh repo view $REPO >/dev/null 2>&1 || gh repo create $REPO --public \
    --description "A little cloud for your Mac that takes class notes" \
    --homepage "https://blackbargoat.github.io/Nimbus/"
git remote get-url origin >/dev/null 2>&1 || git remote add origin https://github.com/$REPO.git
git push -u origin main

if gh release view v$VERSION -R $REPO >/dev/null 2>&1; then
    gh release upload v$VERSION "$STAGE/Nimbus.dmg" -R $REPO --clobber
else
    gh release create v$VERSION "$STAGE/Nimbus.dmg" -R $REPO --title "Nimbus $VERSION" \
        --notes "Download Nimbus.dmg, drag Nimbus into Applications, open it. The first time, approve it in System Settings > Privacy & Security > Open Anyway. Needs macOS 26 or newer (Apple silicon or Intel)."
fi

gh api repos/$REPO/pages >/dev/null 2>&1 || gh api -X POST repos/$REPO/pages -f build_type=workflow >/dev/null
gh workflow run pages.yml -R $REPO
echo "Site (live in about a minute): https://blackbargoat.github.io/Nimbus/"
echo "Download: https://github.com/$REPO/releases/latest/download/Nimbus.dmg"
