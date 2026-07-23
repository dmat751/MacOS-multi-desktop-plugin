import AppKit
import SwiftUI

@main
struct DesktopNumberApp: App {
    @StateObject private var spaceObserver = SpaceObserver()
    @StateObject private var usageObserver = CursorUsageObserver()

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

            Button("Quit") {
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

        if let costCents = usageObserver.todayCostCents {
            return "\(desktopLabel) · \(UsageFormatting.formatDollars(cents: costCents))"
        }

        return desktopLabel
    }
}
