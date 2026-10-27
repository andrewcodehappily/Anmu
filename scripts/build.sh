#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/暗幕.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -R Resources/*.lproj "$app/Contents/Resources/"
cp Resources/Info.plist "$app/Contents/Info.plist"
xcrun swiftc Sources/*.swift -O -target arm64-apple-macos26.0 -o "$app/Contents/MacOS/Dimmer" -framework Cocoa -framework Carbon
codesign --force --sign - "$app"
echo "完成：$PWD/$app"
