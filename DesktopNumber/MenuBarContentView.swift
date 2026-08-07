import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var spaceObserver: SpaceObserver
    @ObservedObject var usageObserver: CursorUsageObserver
    @ObservedObject var commuteController: CommuteModeController
    @ObservedObject var notifySettings: CursorNotifySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text("Cursor Agent Push")
                .font(.caption)
                .foregroundStyle(.secondary)

            if notifySettings.isInstalled {
                Toggle(
                    "Push when agent finishes",
                    isOn: Binding(
                        get: { notifySettings.isEnabled },
                        set: { notifySettings.setEnabled($0) }
                    )
                )

                Text("ntfy topic")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                TextField(
                    "your-topic-name",
                    text: Binding(
                        get: { notifySettings.topic ?? "" },
                        set: { notifySettings.setTopic($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button(notifySettings.isSendingTestPush ? "Sending..." : "Send Test Push") {
                    Task {
                        await notifySettings.sendTestPush()
                    }
                }
                .disabled(notifySettings.isSendingTestPush)

                if let testPushStatus = notifySettings.testPushStatus {
                    Text(testPushStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(notifySettings.isInstalling ? "Installing..." : "Install Push Hooks") {
                    Task {
                        await notifySettings.install()
                    }
                }
                .disabled(notifySettings.isInstalling)

                Text("Installs Cursor hooks into ~/.cursor and sends a test push.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let installError = notifySettings.installError {
                Text(installError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        }
        .padding(12)
        .frame(width: 300)
    }
}
