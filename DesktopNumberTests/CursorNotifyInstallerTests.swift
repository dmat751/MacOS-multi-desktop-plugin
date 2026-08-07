import XCTest
@testable import DesktopNumber

final class CursorNotifyInstallerTests: XCTestCase {
    func testMergeCreatesStopHookWhenMissing() throws {
        let data = try CursorNotifyInstaller.mergedHooksJSON(
            existingData: nil,
            stopHookCommand: CursorNotifyInstaller.stopHookCommand
        )
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]
        let stopHooks = hooks?["stop"] as? [[String: Any]]

        XCTAssertEqual(json?["version"] as? Int, 1)
        XCTAssertEqual(stopHooks?.count, 1)
        XCTAssertEqual(stopHooks?.first?["command"] as? String, "./hooks/on-stop.sh")
        XCTAssertEqual(stopHooks?.first?["matcher"] as? String, "Stop")
    }

    func testMergeDoesNotDuplicateStopHook() throws {
        let existing = """
        {
          "version": 1,
          "hooks": {
            "stop": [
              { "command": "./hooks/on-stop.sh", "matcher": "Stop" }
            ]
          }
        }
        """.data(using: .utf8)

        let data = try CursorNotifyInstaller.mergedHooksJSON(
            existingData: existing,
            stopHookCommand: CursorNotifyInstaller.stopHookCommand
        )
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]
        let stopHooks = hooks?["stop"] as? [[String: Any]]

        XCTAssertEqual(stopHooks?.count, 1)
    }

    func testInstallCopiesHookScripts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberInstallerTests-\(UUID().uuidString)", isDirectory: true)
        let hooksRoot = root.appendingPathComponent("CursorHooks", isDirectory: true)
        let cursorRoot = root.appendingPathComponent(".cursor", isDirectory: true)
        try FileManager.default.createDirectory(at: hooksRoot, withIntermediateDirectories: true)

        let repoHooks = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("cursor-hooks", isDirectory: true)

        try FileManager.default.copyItem(
            at: repoHooks.appendingPathComponent("notify-ntfy.sh"),
            to: hooksRoot.appendingPathComponent("notify-ntfy.sh")
        )
        try FileManager.default.copyItem(
            at: repoHooks.appendingPathComponent("on-stop.sh"),
            to: hooksRoot.appendingPathComponent("on-stop.sh")
        )
        try FileManager.default.copyItem(
            at: repoHooks.appendingPathComponent("notify.env.example"),
            to: hooksRoot.appendingPathComponent("notify.env.example")
        )

        let installer = CursorNotifyInstaller(
            fileManager: .default,
            resourceDirectory: hooksRoot,
            cursorDirectory: cursorRoot
        )

        try installer.install(sendTestNotification: false)

        let installedHook = cursorRoot
            .appendingPathComponent("hooks/on-stop.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: installedHook.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: installedHook.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value
        XCTAssertEqual(permissions, 0o755)

        let hooksJSONData = try Data(contentsOf: cursorRoot.appendingPathComponent("hooks.json"))
        let json = try JSONSerialization.jsonObject(with: hooksJSONData) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]
        let stopHooks = hooks?["stop"] as? [[String: Any]]
        XCTAssertEqual(stopHooks?.first?["command"] as? String, "./hooks/on-stop.sh")
        XCTAssertEqual(stopHooks?.first?["matcher"] as? String, "Stop")
    }
}
