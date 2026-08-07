import AppKit
import SwiftUI

@main
struct DesktopNumberApp: App {
    @StateObject private var spaceObserver = SpaceObserver()
    @StateObject private var usageObserver = CursorUsageObserver()
    @StateObject private var commuteController = CommuteModeController()

    var body: some Scene {
        MenuBarExtra {
            if spaceObserver.totalSpaces > 1 {
                Text("Desktop \(spaceObserver.currentSpaceIndex) of \(spaceObserver.totalSpaces)")
            } else {
                Text("Desktop \(spaceObserver.currentSpaceIndex)")
            }

            Divider()

            if let costCents = usageObserver.todayCostCents {
                Text("Today's Cursor cost: \(UsageFormatting.formatDollars(cents: costCents))")
            } else if usageObserver.isLoading {
                Text("Today's Cursor cost: Loading...")
            } else {
                Text("Today's Cursor cost: --")
            }

            if let tokens = usageObserver.todayTokens {
                Text("Tokens today: \(UsageFormatting.formatTokens(tokens))")
            }

            if let lastUpdated = usageObserver.lastUpdated {
                Text("Updated \(UsageFormatting.formatRelativeTime(lastUpdated))")
            }

            if let errorMessage = usageObserver.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(usageObserver.isLoading ? "Refreshing..." : "Refresh Cursor Usage") {
                usageObserver.refresh()
            }
            .disabled(usageObserver.isLoading)

            Divider()

            Text("Office / Power")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let officeStatus = commuteController.officeStatus {
                Text("On AC power: \(officeStatus.isOnACPower ? "Yes" : "No")")
                Text(
                    "Prevent sleep when display off: \(officeStatus.preventSleepWhenDisplayOff ? "ON" : "OFF")"
                )
                Text("Office lock-screen safe: \(officeStatus.isOfficeReady ? "Yes" : "No")")
            } else {
                Text("Office status: unavailable")
            }

            Button("Refresh Power Status") {
                commuteController.refreshOfficeStatus()
            }

            Divider()

            Text("Commute Mode (closed lid)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Keeps the Mac awake with lid closed. Risk: heat and battery drain.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if commuteController.isActive {
                Button("Stop Commute Mode") {
                    commuteController.stop(reason: .user)
                }
                if let remaining = commuteController.remainingSeconds {
                    Text("Time left: \(UsageFormatting.formatDuration(seconds: remaining))")
                }
            } else {
                Button("Start Commute Mode (90 min)") {
                    commuteController.enable()
                }
                .disabled(!commuteController.hasPasswordlessAccess || commuteController.phase == .enabling)
            }

            if let batteryPercent = commuteController.batteryPercent {
                Text("Battery: \(batteryPercent)%")
            }

            Text("Thermal: \(UsageFormatting.formatThermalState(commuteController.thermalState))")

            if !commuteController.hasPasswordlessAccess {
                Text("Setup required: run scripts/install-commute-permission.sh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastStopReason = commuteController.lastStopReason {
                Text(UsageFormatting.formatCommuteStopReason(lastStopReason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = commuteController.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Quit") {
                commuteController.stop(reason: .userQuit)
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Text(menuBarLabel)
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
        }
    }

    private var menuBarLabel: String {
        let desktopLabel: String
        if spaceObserver.totalSpaces > 1 {
            desktopLabel = "\(spaceObserver.currentSpaceIndex)/\(spaceObserver.totalSpaces)"
        } else {
            desktopLabel = "\(spaceObserver.currentSpaceIndex)"
        }

        var label = desktopLabel

        if let costCents = usageObserver.todayCostCents {
            label += " · \(UsageFormatting.formatDollars(cents: costCents))"
        }

        if commuteController.isActive {
            label += " ☕"
        }

        return label
    }
}
