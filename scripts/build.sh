#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app="build/暗幕.app"
mkdir -p "$app/Contents/MacOS"
cp Resources/Info.plist "$app/Contents/Info.plist"
xcrun swiftc Sources/main.swift -O -target arm64-apple-macos26.0 -o "$app/Contents/MacOS/Dimmer" -framework Cocoa -framework Carbon
codesign --force --sign - "$app"
echo "完成：$PWD/$app"
