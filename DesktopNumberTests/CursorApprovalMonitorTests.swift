import XCTest
@testable import DesktopNumber

@MainActor
final class CursorApprovalMonitorTests: XCTestCase {
    func testSendsPushForApprovalEvent() async {
        let sender = MockNtfySender()
        let monitor = CursorApprovalMonitor(
            ntfyClient: sender,
            pollInterval: 60,
            dedupeWindow: 120
        )

        let line = """
        {"message":"Shell permissions: requesting shell approval","metadata":{"toolCallId":"tool_123","hookForcesPrompt":"false","requestedPolicyType":"insecure_none","commandCount":"1"}}
        """
        monitor.handle(line: line)

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sender.sent.count, 1)
        XCTAssertEqual(sender.sent.first?.title, "Cursor: approve")
    }

    func testDedupesRepeatedApprovalEvents() async {
        let sender = MockNtfySender()
        let monitor = CursorApprovalMonitor(
            ntfyClient: sender,
            pollInterval: 60,
            dedupeWindow: 120
        )

        let line = """
        {"message":"Shell permissions: requesting shell approval","metadata":{"toolCallId":"tool_dup","hookForcesPrompt":"false"}}
        """
        monitor.handle(line: line)
        monitor.handle(line: line)

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sender.sent.count, 1)
    }

    func testPollReadsNewApprovalLinesFromLogFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopNumberApprovalMonitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("Cursor Structured Logs.test.log")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let tailer = CursorApprovalLogTailer(fileManager: .default, logsRoot: root)
        let sender = MockNtfySender()
        let monitor = CursorApprovalMonitor(
            tailer: tailer,
            ntfyClient: sender,
            pollInterval: 60,
            dedupeWindow: 120
        )

        monitor.start()
        let approvalLine = "{\"message\":\"Shell permissions: requesting shell approval\",\"metadata\":{\"toolCallId\":\"tool_poll\",\"hookForcesPrompt\":\"false\"}}\n"
        try approvalLine.append(to: fileURL)

        monitor.poll()

        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(sender.sent.count, 1)
        monitor.stop()
    }
}

private final class MockNtfySender: CursorNtfySending {
    struct SentMessage {
        let title: String
        let body: String
    }

    private(set) var sent: [SentMessage] = []

    func sendApprovalPush(title: String, body: String) async throws {
        sent.append(SentMessage(title: title, body: body))
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
