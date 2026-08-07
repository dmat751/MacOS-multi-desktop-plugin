import Foundation

struct CursorNotifyEnvFile {
    static let enabledKey = "NTFY_ENABLED"
    static let approveEnabledKey = "NTFY_APPROVE_ENABLED"
    static let topicKey = "NTFY_TOPIC"

    let lines: [String]

    init(contents: String) {
        lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func value(for key: String) -> String? {
        let prefix = "\(key)="
        for line in lines {
            guard !line.hasPrefix("#"), line.hasPrefix(prefix) else { continue }
            let value = String(line.dropFirst(prefix.count))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    var isEnabled: Bool {
        Self.isTruthy(value(for: Self.enabledKey), defaultValue: true)
    }

    var isApproveEnabled: Bool {
        Self.isTruthy(value(for: Self.approveEnabledKey), defaultValue: true)
    }

    var topic: String? {
        value(for: Self.topicKey)
    }

    private static func isTruthy(_ raw: String?, defaultValue: Bool) -> Bool {
        guard let raw else { return defaultValue }
        switch raw.lowercased() {
        case "0", "false", "no", "off":
            return false
        default:
            return true
        }
    }

    func settingEnabled(_ enabled: Bool) -> String {
        settingKey(Self.enabledKey, enabled: enabled)
    }

    func settingApproveEnabled(_ enabled: Bool) -> String {
        settingKey(Self.approveEnabledKey, enabled: enabled)
    }

    private func settingKey(_ key: String, enabled: Bool) -> String {
        let newValue = enabled ? "1" : "0"
        var updated = false
        var output: [String] = []

        for line in lines {
            if !line.hasPrefix("#"), line.hasPrefix("\(key)=") {
                output.append("\(key)=\(newValue)")
                updated = true
            } else {
                output.append(line)
            }
        }

        if !updated {
            if !output.isEmpty, output.last?.isEmpty == false {
                output.append("")
            }
            output.append("\(key)=\(newValue)")
        }

        while output.last == "" {
            output.removeLast()
        }

        return output.joined(separator: "\n") + "\n"
    }

    func settingTopic(_ topic: String) -> String {
        var updated = false
        var output: [String] = []

        for line in lines {
            if !line.hasPrefix("#"), line.hasPrefix("\(Self.topicKey)=") {
                output.append("\(Self.topicKey)=\(topic)")
                updated = true
            } else {
                output.append(line)
            }
        }

        if !updated {
            if !output.isEmpty, output.last?.isEmpty == false {
                output.append("")
            }
            output.append("\(Self.topicKey)=\(topic)")
        }

        while output.last == "" {
            output.removeLast()
        }

        return output.joined(separator: "\n") + "\n"
    }
}

@MainActor
final class CursorNotifySettings: ObservableObject {
    @Published private(set) var isInstalled = false
    @Published private(set) var isEnabled = true
    @Published private(set) var isApproveEnabled = true
    @Published private(set) var topic: String?
    @Published private(set) var isInstalling = false
    @Published private(set) var installError: String?
    @Published private(set) var isSendingTestPush = false
    @Published private(set) var testPushStatus: String?

    static let placeholderTopic = "your-topic-name"

    private let fileManager: FileManager
    private let bundle: Bundle
    private let hookScriptURL: URL
    private let envFileURL: URL

    init(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        hookScriptURL: URL? = nil,
        envFileURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        let home = fileManager.homeDirectoryForCurrentUser
        let hooksDirectory = home.appendingPathComponent(".cursor/hooks", isDirectory: true)
        self.hookScriptURL = hookScriptURL ?? hooksDirectory.appendingPathComponent("on-stop.sh")
        self.envFileURL = envFileURL ?? hooksDirectory.appendingPathComponent("notify.env")
        refresh()
    }

    func refresh() {
        isInstalled = fileManager.fileExists(atPath: hookScriptURL.path)

        guard let contents = try? String(contentsOf: envFileURL, encoding: .utf8) else {
            isEnabled = true
            isApproveEnabled = true
            topic = nil
            return
        }

        let env = CursorNotifyEnvFile(contents: contents)
        isEnabled = env.isEnabled
        isApproveEnabled = env.isApproveEnabled
        topic = env.topic
    }

    func install() async {
        guard !isInstalling else { return }

        isInstalling = true
        installError = nil

        do {
            let installer = CursorNotifyInstaller(fileManager: fileManager, bundle: bundle)
            try installer.install()
            refresh()
        } catch {
            installError = error.localizedDescription
            refresh()
        }

        isInstalling = false
    }

    func setEnabled(_ enabled: Bool) {
        guard isInstalled else { return }

        let contents: String
        if let existing = try? String(contentsOf: envFileURL, encoding: .utf8) {
            contents = CursorNotifyEnvFile(contents: existing).settingEnabled(enabled)
        } else {
            contents = """
            NTFY_TOPIC=your-topic-name
            NTFY_ENABLED=\(enabled ? "1" : "0")
            NTFY_APPROVE_ENABLED=\(isApproveEnabled ? "1" : "0")

            """
        }

        do {
            try contents.write(to: envFileURL, atomically: true, encoding: .utf8)
            isEnabled = enabled
            refresh()
        } catch {
            refresh()
        }
    }

    func setApproveEnabled(_ enabled: Bool) {
        guard isInstalled else { return }

        let contents: String
        if let existing = try? String(contentsOf: envFileURL, encoding: .utf8) {
            contents = CursorNotifyEnvFile(contents: existing).settingApproveEnabled(enabled)
        } else {
            contents = """
            NTFY_TOPIC=your-topic-name
            NTFY_ENABLED=\(isEnabled ? "1" : "0")
            NTFY_APPROVE_ENABLED=\(enabled ? "1" : "0")

            """
        }

        do {
            try contents.write(to: envFileURL, atomically: true, encoding: .utf8)
            isApproveEnabled = enabled
            refresh()
        } catch {
            refresh()
        }
    }

    func setTopic(_ topic: String) {
        guard isInstalled else { return }

        let contents: String
        if let existing = try? String(contentsOf: envFileURL, encoding: .utf8) {
            contents = CursorNotifyEnvFile(contents: existing).settingTopic(topic)
        } else {
            contents = """
            NTFY_TOPIC=\(topic)
            NTFY_ENABLED=\(isEnabled ? "1" : "0")
            NTFY_APPROVE_ENABLED=\(isApproveEnabled ? "1" : "0")

            """
        }

        do {
            try contents.write(to: envFileURL, atomically: true, encoding: .utf8)
            self.topic = topic
            refresh()
        } catch {
            refresh()
        }
    }

    func sendTestPush() async {
        guard isInstalled, !isSendingTestPush else { return }

        guard let topic,
              !topic.isEmpty,
              topic != Self.placeholderTopic,
              let url = URL(string: "https://ntfy.sh/\(topic)") else {
            testPushStatus = "Set an ntfy topic first."
            return
        }

        isSendingTestPush = true
        testPushStatus = nil

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "DesktopNumber: test push".data(using: .utf8)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                testPushStatus = "Test push failed with status \(http.statusCode)."
            } else {
                testPushStatus = "Test push sent."
            }
        } catch {
            testPushStatus = error.localizedDescription
        }

        isSendingTestPush = false
    }
}
