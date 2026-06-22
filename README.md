# DesktopNumber

A macOS menu bar app that shows the active desktop number (e.g. `3` or `3/5`), so you don't have to press Ctrl+↑ to check which desktop you're on.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+

## Building

```bash
cd mac-desktop-number-plugin
xcodebuild -scheme DesktopNumber -configuration Release build
```

The built app is located at:

```
build/Build/Products/Release/DesktopNumber.app
```

When building from Xcode (without `-derivedDataPath build`), check the path in the `xcodebuild` log.

## Running

```bash
open build/Build/Products/Release/DesktopNumber.app
```

After launch, the current desktop number appears in the menu bar. Clicking the icon opens a menu with the text "Desktop X of Y".

The app runs as an agent (`LSUIElement`) — it has no Dock icon.

## Launch at login (optional)

1. Open **System Settings** → **General** → **Login Items & Extensions** → **Open at Login**.
2. Click **+** and select `DesktopNumber.app`.

Alternatively, you can copy the app to `/Applications` and add it from there.

## Notes

- The app uses private CoreGraphics APIs (`CGSCopyManagedDisplaySpaces`) to detect desktops — a common approach in tools like this, but the API may change in future macOS versions.
- Desktop order is sorted according to the visual layout from Mission Control (file `~/Library/Preferences/com.apple.spaces.plist`).
