import XCTest
@testable import DesktopNumber

final class CursorNotifyEnvFileTests: XCTestCase {
    func testMissingEnabledKeyDefaultsToEnabled() {
        let env = CursorNotifyEnvFile(contents: "NTFY_TOPIC=Cursor-test\n")
        XCTAssertTrue(env.isEnabled)
        XCTAssertTrue(env.isApproveEnabled)
        XCTAssertEqual(env.topic, "Cursor-test")
    }

    func testParsesApproveEnabledValues() {
        XCTAssertTrue(CursorNotifyEnvFile(contents: "NTFY_APPROVE_ENABLED=1\n").isApproveEnabled)
        XCTAssertFalse(CursorNotifyEnvFile(contents: "NTFY_APPROVE_ENABLED=0\n").isApproveEnabled)
        XCTAssertFalse(CursorNotifyEnvFile(contents: "NTFY_APPROVE_ENABLED=false\n").isApproveEnabled)
    }

    func testSetApproveEnabledUpdatesExistingLine() {
        let original = """
        NTFY_TOPIC=Cursor-test
        NTFY_APPROVE_ENABLED=1

        """
        let updated = CursorNotifyEnvFile(contents: original).settingApproveEnabled(false)
        XCTAssertTrue(updated.contains("NTFY_APPROVE_ENABLED=0"))
        XCTAssertFalse(updated.contains("NTFY_APPROVE_ENABLED=1"))
    }

    func testParsesEnabledValues() {
        XCTAssertTrue(CursorNotifyEnvFile(contents: "NTFY_ENABLED=1\n").isEnabled)
        XCTAssertFalse(CursorNotifyEnvFile(contents: "NTFY_ENABLED=0\n").isEnabled)
        XCTAssertFalse(CursorNotifyEnvFile(contents: "NTFY_ENABLED=false\n").isEnabled)
        XCTAssertFalse(CursorNotifyEnvFile(contents: "NTFY_ENABLED=off\n").isEnabled)
    }

    func testSetEnabledUpdatesExistingLine() {
        let original = """
        NTFY_TOPIC=Cursor-test
        NTFY_ENABLED=1

        """
        let updated = CursorNotifyEnvFile(contents: original).settingEnabled(false)
        XCTAssertTrue(updated.contains("NTFY_ENABLED=0"))
        XCTAssertTrue(updated.contains("NTFY_TOPIC=Cursor-test"))
        XCTAssertFalse(updated.contains("NTFY_ENABLED=1"))
    }

    func testSetEnabledAppendsWhenMissing() {
        let original = "NTFY_TOPIC=Cursor-test\n"
        let updated = CursorNotifyEnvFile(contents: original).settingEnabled(false)
        XCTAssertTrue(updated.contains("NTFY_ENABLED=0"))
        XCTAssertTrue(updated.contains("NTFY_TOPIC=Cursor-test"))
    }

    func testSetEnabledCanReenable() {
        let original = "NTFY_TOPIC=Cursor-test\nNTFY_ENABLED=0\n"
        let updated = CursorNotifyEnvFile(contents: original).settingEnabled(true)
        XCTAssertTrue(updated.contains("NTFY_ENABLED=1"))
        XCTAssertFalse(updated.contains("NTFY_ENABLED=0"))
    }

    func testSetTopicUpdatesExistingLine() {
        let original = """
        NTFY_TOPIC=old-topic
        NTFY_ENABLED=1

        """
        let updated = CursorNotifyEnvFile(contents: original).settingTopic("new-topic")
        XCTAssertTrue(updated.contains("NTFY_TOPIC=new-topic"))
        XCTAssertFalse(updated.contains("NTFY_TOPIC=old-topic"))
        XCTAssertTrue(updated.contains("NTFY_ENABLED=1"))
    }

    func testSetTopicAppendsWhenMissing() {
        let original = "NTFY_ENABLED=1\n"
        let updated = CursorNotifyEnvFile(contents: original).settingTopic("my-topic")
        XCTAssertTrue(updated.contains("NTFY_TOPIC=my-topic"))
    }
}

@MainActor
final class CursorNotifySettingsTests: XCTestCase {
    func testRefreshReadsInstalledStateAndEnvFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberNotifyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let hookURL = directory.appendingPathComponent("on-stop.sh")
        let envURL = directory.appendingPathComponent("notify.env")
        try "# hook".write(to: hookURL, atomically: true, encoding: .utf8)
        try """
        NTFY_TOPIC=Cursor-test
        NTFY_ENABLED=0
        NTFY_APPROVE_ENABLED=0

        """.write(to: envURL, atomically: true, encoding: .utf8)

        let settings = CursorNotifySettings(
            fileManager: .default,
            hookScriptURL: hookURL,
            envFileURL: envURL
        )

        XCTAssertTrue(settings.isInstalled)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.isApproveEnabled)
        XCTAssertEqual(settings.topic, "Cursor-test")
    }

    func testSetApproveEnabledWritesToEnvFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberNotifyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let hookURL = directory.appendingPathComponent("on-stop.sh")
        let envURL = directory.appendingPathComponent("notify.env")
        try "# hook".write(to: hookURL, atomically: true, encoding: .utf8)
        try "NTFY_TOPIC=Cursor-test\nNTFY_APPROVE_ENABLED=1\n".write(to: envURL, atomically: true, encoding: .utf8)

        let settings = CursorNotifySettings(
            fileManager: .default,
            hookScriptURL: hookURL,
            envFileURL: envURL
        )

        settings.setApproveEnabled(false)

        let env = CursorNotifyEnvFile(contents: try String(contentsOf: envURL, encoding: .utf8))
        XCTAssertFalse(env.isApproveEnabled)
        XCTAssertFalse(settings.isApproveEnabled)
    }

    func testSetEnabledWritesToEnvFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberNotifyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let hookURL = directory.appendingPathComponent("on-stop.sh")
        let envURL = directory.appendingPathComponent("notify.env")
        try "# hook".write(to: hookURL, atomically: true, encoding: .utf8)
        try "NTFY_TOPIC=Cursor-test\nNTFY_ENABLED=1\n".write(to: envURL, atomically: true, encoding: .utf8)

        let settings = CursorNotifySettings(
            fileManager: .default,
            hookScriptURL: hookURL,
            envFileURL: envURL
        )

        settings.setEnabled(false)

        let env = CursorNotifyEnvFile(contents: try String(contentsOf: envURL, encoding: .utf8))
        XCTAssertFalse(env.isEnabled)
        XCTAssertEqual(env.topic, "Cursor-test")
        XCTAssertFalse(settings.isEnabled)
    }

    func testSetTopicWritesToEnvFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberNotifyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let hookURL = directory.appendingPathComponent("on-stop.sh")
        let envURL = directory.appendingPathComponent("notify.env")
        try "# hook".write(to: hookURL, atomically: true, encoding: .utf8)
        try "NTFY_TOPIC=old-topic\nNTFY_ENABLED=1\n".write(to: envURL, atomically: true, encoding: .utf8)

        let settings = CursorNotifySettings(
            fileManager: .default,
            hookScriptURL: hookURL,
            envFileURL: envURL
        )

        settings.setTopic("Cursor-1234")

        let env = CursorNotifyEnvFile(contents: try String(contentsOf: envURL, encoding: .utf8))
        XCTAssertEqual(env.topic, "Cursor-1234")
        XCTAssertEqual(settings.topic, "Cursor-1234")
    }

    func testSendTestPushRequiresTopic() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberNotifyTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let hookURL = directory.appendingPathComponent("on-stop.sh")
        let envURL = directory.appendingPathComponent("notify.env")
        try? "# hook".write(to: hookURL, atomically: true, encoding: .utf8)
        try? "NTFY_TOPIC=your-topic-name\nNTFY_ENABLED=1\n".write(to: envURL, atomically: true, encoding: .utf8)

        let settings = CursorNotifySettings(
            fileManager: .default,
            hookScriptURL: hookURL,
            envFileURL: envURL
        )

        await settings.sendTestPush()

        XCTAssertEqual(settings.testPushStatus, "Set an ntfy topic first.")
    }
}
