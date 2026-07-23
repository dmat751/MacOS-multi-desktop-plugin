# DesktopNumber

A macOS menu bar app that shows the active desktop number (e.g. `3` or `3/5`) and today's Cursor usage cost (e.g. `3/5 · $0.42`), so you don't have to press Ctrl+↑ to check which desktop you're on or open the Cursor dashboard to see today's spend.

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

After launch, the current desktop number appears in the menu bar. When Cursor usage data is available, the label also shows today's cost, for example `3/5 · $0.42`.

Clicking the icon opens a menu with:
- the current desktop number
- today's Cursor cost and token usage
- the time of the last refresh
- a manual refresh action

The app runs as an agent (`LSUIElement`) — it has no Dock icon.

## Launch at login (optional)

1. Open **System Settings** → **General** → **Login Items & Extensions** → **Open at Login**.
2. Click **+** and select `DesktopNumber.app`.

Alternatively, you can copy the app to `/Applications` and add it from there.

## Testing

```bash
xcodebuild -scheme DesktopNumber -configuration Debug -derivedDataPath build test
```

## Notes

- The app uses private CoreGraphics APIs (`CGSCopyManagedDisplaySpaces`) to detect desktops — a common approach in tools like this, but the API may change in future macOS versions.
- Desktop order is sorted according to the visual layout from Mission Control (file `~/Library/Preferences/com.apple.spaces.plist`).
- Cursor usage is read from the local Cursor session database (`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`) and fetched from Cursor's dashboard API. You must be logged into Cursor on the same Mac.
- The Cursor usage API is unofficial and may change without notice. If usage cannot be loaded, the desktop number still works and the menu shows the error.
