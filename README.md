# Anmu (暗幕)

[English](README.md) | [繁體中文](README-ZH-TW.md) | [简体中文](README-ZH-CN.md)

Dim a selected macOS app’s window while keeping mouse and keyboard input working normally.

Anmu is a lightweight menu bar utility that places a click-through, translucent black overlay over the target window. The overlay appears only while the selected app is in the foreground and hides when you switch to another app.

## Features

- Automatically use English, Traditional Chinese, or Simplified Chinese based on system language preferences.
- Select a target from running apps.
- Adjust dimming from 0–95% in real time.
- Follow the target window’s position and size, updating every 0.15 seconds.
- Join macOS full-screen spaces; special games and exclusive full-screen modes still need individual testing.
- The overlay does not intercept mouse input or take keyboard focus. The control window behaves like a regular window and does not stay on top.
- Toggle the overlay with the global shortcut **Control + Option + Command + D**.
- Remember the dimming level and target app. The overlay starts disabled on every launch.
- Disable the overlay when displays wake or the display configuration changes.

## Requirements

The current build script and downloadable app target **macOS 26.0 or later on Apple Silicon (arm64)**. This is a build configuration, not a requirement established by the app’s features. Intel and older macOS versions have not been verified.

## Download and use

Download the ZIP from [Releases](https://github.com/andrewcodehappily/Anmu/releases), extract it, and open `暗幕.app`. The app is ad-hoc signed and is not notarized by Apple, so macOS may restrict opening it. You can also review the source and build it yourself.

The interface supports English, Traditional Chinese, and Simplified Chinese. It follows your macOS preferred languages, with English as the fallback. Relaunch Anmu after changing the language. macOS per-app language preferences are also supported.

1. Open the app you want to dim, then launch Anmu.
2. Select the target in the control window. Click **重新整理 App 清單** (Refresh app list) if it is missing.
3. Adjust **遮暗程度** (Dimming level) and check **啟用遮罩** (Enable overlay).
4. Click **收起控制台，回到 App** (Hide controls and return to app).
5. Use the **◐ / ●** menu bar icon to reopen the controls, or use the global shortcut to toggle the overlay.

To restore the original brightness, click **立即恢復亮度** (Restore brightness), disable the overlay, or quit Anmu. Adjust your physical display brightness separately.

## Build from source

Install Xcode or compatible Command Line Tools with the macOS 26 SDK and Swift compiler, then run from the project root:

```sh
./scripts/build.sh
open 'build/暗幕.app'
```

Uses native AppKit, Core Graphics, and Carbon, with no third-party packages.

## Limitations

- The overlay only darkens the image. It does not make app backgrounds transparent or guarantee privacy from bystanders or viewers 10 meters away.
- For apps with multiple windows, the current version handles only the frontmost visible regular window in the window list that is larger than 40 × 40.
- No screen recording or image analysis is performed; the system window list supplies window positions and sizes.
- If shortcut registration fails, the controls show a message. The menu bar controls remain available.
- Full-screen, multiple-display, and app-specific compatibility need more real-world testing. A successful build does not verify every scenario.

## Contributions welcome

Issues and pull requests are welcome! Contributions for older macOS compatibility, Intel/universal builds, interface localization, bug fixes, and documentation improvements are especially welcome.

Please describe your changes, the macOS version and chip architecture used for testing, and the results in your PR. Pull requests are reviewed on their merits.

## License

[MIT License](LICENSE)
