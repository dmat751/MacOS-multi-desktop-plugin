import AppKit
import SwiftUI

@main
struct DesktopNumberApp: App {
    @StateObject private var spaceObserver = SpaceObserver()

    var body: some Scene {
        MenuBarExtra {
            if spaceObserver.totalSpaces > 1 {
                Text("Desktop \(spaceObserver.currentSpaceIndex) of \(spaceObserver.totalSpaces)")
            } else {
                Text("Desktop \(spaceObserver.currentSpaceIndex)")
            }

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
        if spaceObserver.totalSpaces > 1 {
            return "\(spaceObserver.currentSpaceIndex)/\(spaceObserver.totalSpaces)"
        }
        return "\(spaceObserver.currentSpaceIndex)"
    }
}
