import XCTest
@testable import DesktopNumber

final class CursorApprovalLogParserTests: XCTestCase {
    func testParsesStructuredShellApproval() {
        let line = """
        2026-08-07 12:40:47.496 [info] {"level":"info","key":"agent_exec","message":"Shell permissions: requesting shell approval","metadata":{"toolCallId":"tool_15788fea-0b0a-4b80-9777-df179daae47","hookForcesPrompt":"false","requestedPolicyType":"insecure_none","commandCount":"3"}}
        """

        let event = CursorApprovalLogParser.parse(line: line)

        XCTAssertEqual(event?.kind, .shell)
        XCTAssertEqual(event?.dedupeKey, "shell:tool_15788fea-0b0a-4b80-9777-df179daae47")
        XCTAssertEqual(event?.title, "Cursor: approve")
        XCTAssertTrue(event?.body.contains("Shell approval needed") == true)
    }

    func testIgnoresShellApprovalForcedByHook() {
        let line = """
        {"message":"Shell permissions: requesting shell approval","metadata":{"toolCallId":"tool_hook","hookForcesPrompt":"true"}}
        """

        XCTAssertNil(CursorApprovalLogParser.parse(line: line))
    }

    func testIgnoresAutoApprovedShellLines() {
        let line = """
        {"message":"Shell permissions: auto-approved shell command","metadata":{"toolCallId":"tool_auto"}}
        """

        XCTAssertNil(CursorApprovalLogParser.parse(line: line))
    }

    func testParsesMCPAllowlistApproval() {
        let line = """
        2026-07-27 14:50:45.474 [info] [permissions-service] shouldBlockMcp: needsApproval (not in allowlist) toolName="cursor_dialog", providerIdentifier="cursor-app-control", approvalMode="allowlist"
        """

        let event = CursorApprovalLogParser.parse(line: line)

        XCTAssertEqual(event?.kind, .mcp)
        XCTAssertEqual(event?.title, "Cursor: approve")
        XCTAssertEqual(event?.body, "MCP approval needed: cursor_dialog (cursor-app-control)")
        XCTAssertTrue(event?.dedupeKey.hasPrefix("mcp:cursor-app-control:cursor_dialog:") == true)
    }
}

final class CursorApprovalLogTailerTests: XCTestCase {
    func testReadsOnlyNewLinesAndHandlesPartialLine() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberApprovalTailer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("Structured Logs.test.log")
        try "line one\nline two\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let tailer = CursorApprovalLogTailer(fileManager: .default, logsRoot: root)
        try tailer.initializeAtEnd(of: fileURL)

        try "line three\npartial".append(to: fileURL)
        let firstRead = try tailer.readNewLines(from: fileURL)
        XCTAssertEqual(firstRead, ["line three"])

        try " tail\nline four\n".append(to: fileURL)
        let secondRead = try tailer.readNewLines(from: fileURL)
        XCTAssertEqual(secondRead, ["partial tail", "line four"])
    }

    func testDiscoversStructuredAndAllowlistLogs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberApprovalTailer-\(UUID().uuidString)", isDirectory: true)
        let nested = root.appendingPathComponent("window/exthost", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "#".write(
            to: nested.appendingPathComponent("Cursor Structured Logs.workspace.log"),
            atomically: true,
            encoding: .utf8
        )
        try "#".write(
            to: root.appendingPathComponent("workbench.mcp.allowlist.log"),
            atomically: true,
            encoding: .utf8
        )

        let tailer = CursorApprovalLogTailer(fileManager: .default, logsRoot: root)
        let files = tailer.discoverLogFiles()

        XCTAssertEqual(files.count, 2)
    }
}

private extension String {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        if let data = self.data(using: .utf8) {
            try handle.write(contentsOf: data)
        }
    }
}
