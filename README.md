# DesktopNumber

A macOS menu bar app that shows the active desktop number (e.g. `3` or `3/5`) and today's Cursor usage cost (e.g. `3/5 · $0.42`), so you don't have to press Ctrl+↑ to check which desktop you're on or open the Cursor dashboard to see today's spend.

It also includes:

- **Office / Power status** — read-only check that your Mac is configured for lock-screen safety on AC power (`Prevent automatic sleeping on power adapter when the display is off`).
- **Commute mode** — keeps the Mac awake with the lid closed for local Cursor agents during a commute, with automatic safety cutoffs.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+

## Building

```bash
cd mac-desktop-number-plugin
xcodebuild -scheme DesktopNumber -configuration Release -derivedDataPath build build
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

After launch, the current desktop number appears in the menu bar. When Cursor usage data is available, the label also shows today's cost, for example `3/5 · $0.42`. When commute mode is active, the label also shows a coffee indicator.

Clicking the icon opens a menu with:

- the current desktop number
- today's Cursor cost and token usage
- office / power status (AC, prevent-sleep setting, lock-screen safety)
- commute mode controls and safety status
- a manual refresh action

The app runs as an agent (`LSUIElement`) — it has no Dock icon.

## Commute mode setup

Commute mode uses `pmset -a disablesleep` so a MacBook can stay awake with the lid closed. This requires narrowly scoped, passwordless `sudo` access for exactly two commands.

Install once from the menu (**Grant Access** next to Start Commute Mode) or manually:

```bash
sudo scripts/install-commute-permission.sh
```

Uninstall:

```bash
sudo scripts/uninstall-commute-permission.sh
```

The installer writes `/etc/sudoers.d/desktopnumber-commute` allowing only:

- `/usr/bin/pmset -a disablesleep 1`
- `/usr/bin/pmset -a disablesleep 0`

## Office vs commute

| Scenario | What to use |
| --- | --- |
| Office, plugged in, Ctrl+Cmd+Q lock screen | macOS Battery setting **Prevent automatic sleeping on power adapter when the display is off** — check status in the menu |
| Commute, lid closed, local Cursor agent | **Commute mode** in the menu (90-minute limit) |
| Safest closed-lid workflow | Cursor **Cloud Agent** — laptop can sleep |

Commute mode does **not** use `caffeinate`. That tool does not prevent sleep when the lid is closed.

## Cursor agent notifications (optional)

Send push notifications via [ntfy.sh](https://ntfy.sh) when a local Cursor agent finishes or needs your approval. This uses Cursor **user hooks** installed into `~/.cursor/`.

Install once from the DesktopNumber menu by enabling **Push when agent finishes** or **Push when approve needed**, or from the terminal:

```bash
./scripts/install-cursor-notify-hooks.sh
```

Uninstall:

```bash
./scripts/uninstall-cursor-notify-hooks.sh
```

The installer:

- copies hook scripts to `~/.cursor/hooks/`
- merges the `stop` hook into `~/.cursor/hooks.json` (backs up any existing file first)
- removes leftover DesktopNumber `beforeShellExecution` / `beforeMCPExecution` hooks if a previous version installed them
- creates `~/.cursor/hooks/notify.env` from `notify.env.example` (set your ntfy topic there)
- sends a test push when `NTFY_TOPIC` is configured

Edit `~/.cursor/hooks/notify.env`:

```bash
NTFY_TOPIC=your-topic-name
NTFY_ENABLED=1
NTFY_APPROVE_ENABLED=1
```

Enable or disable push notifications from the DesktopNumber menu bar toggles:

- **Push when agent finishes** — installs or removes the Cursor `stop` hook and writes `NTFY_ENABLED=1` or `0`
- **Push when approve needed** — starts or stops DesktopNumber log monitoring and writes `NTFY_APPROVE_ENABLED=1` or `0`

No Cursor restart is required for toggle changes. After installing or updating hooks, restart Cursor once and verify them in **Customize → Hooks**. If notifications do not arrive, open the **Hooks** output channel for errors.

**Approve coverage:** DesktopNumber does **not** install `beforeShellExecution` or `beforeMCPExecution` hooks, so Cursor's native shell and MCP approval prompts stay in control. Approve pushes come only from the log monitor (`Shell permissions: requesting shell approval`, sandbox shell runs with `allCommandsPreapproved` + not allowlisted, and `shouldBlockMcp: needsApproval`).

After updating DesktopNumber, re-enable **Push when agent finishes** once to refresh scripts in `~/.cursor/hooks/`.

## Commute mode safety

When commute mode is enabled, the app and an embedded `CommuteFailsafe` helper monitor:

- **90-minute timer** — auto-disable after 90 minutes
- **Battery ≤ 20% on battery power** — auto-disable so the Mac can sleep
- **Thermal pressure (`serious` / `critical`)** — auto-disable so the Mac can sleep and cool down; finish the task at home
- **App quit** — disables commute mode on normal quit
- **Fail-safe helper** — if the menu app crashes, the helper still disables sleep when limits are hit

**Risks:** heat buildup in a bag, faster battery drain, and interrupted agent tasks after automatic shutdown. Do not leave commute mode running indefinitely.

## Launch at login (optional)

1. Open **System Settings** → **General** → **Login Items & Extensions** → **Open at Login**.
2. Click **+** and select `DesktopNumber.app`.

Alternatively, you can copy the app to `/Applications` and add it from there.

## Testing

```bash
xcodebuild -scheme DesktopNumber -configuration Debug -derivedDataPath build test
```

Unit tests use mocks and do not change system power settings.

## Notes

- The app uses private CoreGraphics APIs (`CGSCopyManagedDisplaySpaces`) to detect desktops — a common approach in tools like this, but the API may change in future macOS versions.
- Desktop order is sorted according to the visual layout from Mission Control (file `~/Library/Preferences/com.apple.spaces.plist`).
- Cursor usage is read from the local Cursor session database (`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`) and fetched from Cursor's dashboard API. You must be logged into Cursor on the same Mac.
- The Cursor usage API is unofficial and may change without notice. If usage cannot be loaded, the desktop number still works and the menu shows the error.
