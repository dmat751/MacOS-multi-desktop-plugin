import XCTest
@testable import DesktopNumber

final class CursorNotifyInstallerTests: XCTestCase {
    private func mergeHooks(existingData: Data?) throws -> [String: Any] {
        let data = try CursorNotifyInstaller.mergedHooksJSON(
            existingData: existingData,
            stopHookCommand: CursorNotifyInstaller.stopHookCommand,
            shellHookCommand: CursorNotifyInstaller.shellHookCommand,
            mcpHookCommand: CursorNotifyInstaller.mcpHookCommand
        )
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testMergeCreatesHooksWhenMissing() throws {
        let json = try mergeHooks(existingData: nil)
        let hooks = json["hooks"] as? [String: Any]
        let stopHooks = hooks?["stop"] as? [[String: Any]]
        let shellHooks = hooks?["beforeShellExecution"] as? [[String: Any]]
        let mcpHooks = hooks?["beforeMCPExecution"] as? [[String: Any]]

        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(stopHooks?.count, 1)
        XCTAssertEqual(stopHooks?.first?["command"] as? String, "./hooks/on-stop.sh")
        XCTAssertEqual(stopHooks?.first?["matcher"] as? String, "Stop")
        XCTAssertEqual(shellHooks?.first?["command"] as? String, "./hooks/on-before-shell.sh")
        XCTAssertEqual(mcpHooks?.first?["command"] as? String, "./hooks/on-before-mcp.sh")
    }

    func testMergeDoesNotDuplicateHooks() throws {
        let existing = """
        {
          "version": 1,
          "hooks": {
            "stop": [
              { "command": "./hooks/on-stop.sh", "matcher": "Stop" }
            ],
            "beforeShellExecution": [
              { "command": "./hooks/on-before-shell.sh" }
            ],
            "beforeMCPExecution": [
              { "command": "./hooks/on-before-mcp.sh" }
            ]
          }
        }
        """.data(using: .utf8)

        let json = try mergeHooks(existingData: existing)
        let hooks = json["hooks"] as? [String: Any]

        XCTAssertEqual((hooks?["stop"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((hooks?["beforeShellExecution"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((hooks?["beforeMCPExecution"] as? [[String: Any]])?.count, 1)
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

        for script in [
            "notify-ntfy.sh",
            "approval-notify.sh",
            "on-stop.sh",
            "on-before-shell.sh",
            "on-before-mcp.sh",
            "notify.env.example",
        ] {
            try FileManager.default.copyItem(
                at: repoHooks.appendingPathComponent(script),
                to: hooksRoot.appendingPathComponent(script)
            )
        }

        let installer = CursorNotifyInstaller(
            fileManager: .default,
            resourceDirectory: hooksRoot,
            cursorDirectory: cursorRoot
        )

        try installer.install(sendTestNotification: false)

        for script in [
            "notify-ntfy.sh",
            "approval-notify.sh",
            "on-stop.sh",
            "on-before-shell.sh",
            "on-before-mcp.sh",
        ] {
            let installedHook = cursorRoot.appendingPathComponent("hooks/\(script)")
            XCTAssertTrue(FileManager.default.fileExists(atPath: installedHook.path))

            let attributes = try FileManager.default.attributesOfItem(atPath: installedHook.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value
            XCTAssertEqual(permissions, 0o755)
        }

        let hooksJSONData = try Data(contentsOf: cursorRoot.appendingPathComponent("hooks.json"))
        let json = try JSONSerialization.jsonObject(with: hooksJSONData) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]
        XCTAssertEqual(
            (hooks?["stop"] as? [[String: Any]])?.first?["command"] as? String,
            "./hooks/on-stop.sh"
        )
        XCTAssertEqual(
            (hooks?["beforeShellExecution"] as? [[String: Any]])?.first?["command"] as? String,
            "./hooks/on-before-shell.sh"
        )
        XCTAssertEqual(
            (hooks?["beforeMCPExecution"] as? [[String: Any]])?.first?["command"] as? String,
            "./hooks/on-before-mcp.sh"
        )
    }
}
