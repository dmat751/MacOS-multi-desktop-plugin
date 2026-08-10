import Foundation

enum CursorNotifyInstallError: LocalizedError {
    case missingBundleResource(String)
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBundleResource(let name):
            return "Missing bundled hook resource: \(name)."
        case .fileOperationFailed(let message):
            return message
        }
    }
}

struct CursorNotifyInstallationStatus: Equatable {
    let missingScripts: [String]
    let missingHookEntries: [String]
    let envNeedsMigration: Bool

    var isFullyInstalled: Bool {
        missingScripts.isEmpty && missingHookEntries.isEmpty
    }

    var needsMigration: Bool {
        !missingScripts.isEmpty || !missingHookEntries.isEmpty || envNeedsMigration
    }
}

struct CursorNotifyInstaller {
    static let stopHookCommand = "./hooks/on-stop.sh"
    static let shellHookCommand = "./hooks/on-before-shell.sh"
    static let mcpHookCommand = "./hooks/on-before-mcp.sh"
    static let bundledResourceDirectory = "CursorHooks"
    static let requiredHookScripts = [
        "notify-ntfy.sh",
        "approval-notify.sh",
        "on-stop.sh",
        "on-before-shell.sh",
        "on-before-mcp.sh",
    ]

    private let fileManager: FileManager
    private let bundle: Bundle
    private let resourceDirectory: URL?
    private let cursorDirectory: URL
    private let hooksDirectory: URL
    private let hooksJSONURL: URL
    private let envFileURL: URL

    init(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        resourceDirectory: URL? = nil,
        cursorDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.resourceDirectory = resourceDirectory
        let home = fileManager.homeDirectoryForCurrentUser
        self.cursorDirectory = cursorDirectory ?? home.appendingPathComponent(".cursor", isDirectory: true)
        hooksDirectory = self.cursorDirectory.appendingPathComponent("hooks", isDirectory: true)
        hooksJSONURL = self.cursorDirectory.appendingPathComponent("hooks.json")
        envFileURL = hooksDirectory.appendingPathComponent("notify.env")
    }

    func install(sendTestNotification: Bool = true) throws {
        try fileManager.createDirectory(at: cursorDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)

        try installBundledScript(named: "notify-ntfy", destinationName: "notify-ntfy.sh")
        try installBundledScript(named: "approval-notify", destinationName: "approval-notify.sh")
        try installBundledScript(named: "on-stop", destinationName: "on-stop.sh")
        try installBundledScript(named: "on-before-shell", destinationName: "on-before-shell.sh")
        try installBundledScript(named: "on-before-mcp", destinationName: "on-before-mcp.sh")

        if !fileManager.fileExists(atPath: envFileURL.path) {
            let exampleURL = try bundledResourceURL(name: "notify.env.example")
            try copyReplacingItem(at: exampleURL, to: envFileURL)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: envFileURL.path)
        } else {
            try migrateEnvFileIfNeeded()
        }

        try mergeHooksIntoHooksJSON()
        if sendTestNotification {
            try sendTestNotificationIfPossible()
        }
    }

    func installationStatus() -> CursorNotifyInstallationStatus {
        let missingScripts = Self.requiredHookScripts.filter { script in
            !fileManager.fileExists(atPath: hooksDirectory.appendingPathComponent(script).path)
        }

        let hooksJSONStatus = Self.hooksJSONStatus(data: try? Data(contentsOf: hooksJSONURL))
        let envNeedsMigration = envFileNeedsMigration()

        return CursorNotifyInstallationStatus(
            missingScripts: missingScripts,
            missingHookEntries: hooksJSONStatus,
            envNeedsMigration: envNeedsMigration
        )
    }

    func migrateIfNeeded(sendTestNotification: Bool = false) throws {
        let status = installationStatus()
        guard status.needsMigration else { return }

        try fileManager.createDirectory(at: cursorDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)

        for script in status.missingScripts {
            let resourceName = (script as NSString).deletingPathExtension
            try installBundledScript(named: resourceName, destinationName: script)
        }

        if !status.missingHookEntries.isEmpty {
            try mergeHooksIntoHooksJSON()
        }

        if status.envNeedsMigration {
            try migrateEnvFileIfNeeded()
        }

        if sendTestNotification {
            try sendTestNotificationIfPossible()
        }
    }

    private func migrateEnvFileIfNeeded() throws {
        guard let contents = try? String(contentsOf: envFileURL, encoding: .utf8) else { return }
        let env = CursorNotifyEnvFile(contents: contents)
        guard env.value(for: CursorNotifyEnvFile.approveEnabledKey) == nil else { return }

        let updated = env.settingApproveEnabled(env.isApproveEnabled)
        try updated.write(to: envFileURL, atomically: true, encoding: .utf8)
    }

    private func envFileNeedsMigration() -> Bool {
        guard let contents = try? String(contentsOf: envFileURL, encoding: .utf8) else {
            return false
        }
        let env = CursorNotifyEnvFile(contents: contents)
        return env.value(for: CursorNotifyEnvFile.approveEnabledKey) == nil
    }

    static func hooksJSONStatus(data: Data?) -> [String] {
        guard let data,
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = parsed["hooks"] as? [String: Any] else {
            return ["stop", "beforeShellExecution", "beforeMCPExecution"]
        }

        var missing: [String] = []
        if !hookEntries(hooks["stop"]).contains(where: { $0["command"] as? String == stopHookCommand }) {
            missing.append("stop")
        }
        if !hookEntries(hooks["beforeShellExecution"]).contains(where: { $0["command"] as? String == shellHookCommand }) {
            missing.append("beforeShellExecution")
        }
        if !hookEntries(hooks["beforeMCPExecution"]).contains(where: { $0["command"] as? String == mcpHookCommand }) {
            missing.append("beforeMCPExecution")
        }
        return missing
    }

    private static func hookEntries(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private func installBundledScript(named resourceName: String, destinationName: String) throws {
        let sourceURL = try bundledResourceURL(name: "\(resourceName).sh")
        let destinationURL = hooksDirectory.appendingPathComponent(destinationName)
        try copyReplacingItem(at: sourceURL, to: destinationURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
    }

    private func bundledResourceURL(name: String) throws -> URL {
        if let resourceDirectory {
            let url = resourceDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
            throw CursorNotifyInstallError.missingBundleResource(name)
        }

        let fileName = (name as NSString).deletingPathExtension
        let fileExtension = (name as NSString).pathExtension
        let resourceExtension = fileExtension.isEmpty ? nil : fileExtension

        if let url = bundle.url(
            forResource: fileName,
            withExtension: resourceExtension,
            subdirectory: Self.bundledResourceDirectory
        ) {
            return url
        }

        if let url = bundle.url(forResource: fileName, withExtension: resourceExtension) {
            return url
        }

        throw CursorNotifyInstallError.missingBundleResource(name)
    }

    private func copyReplacingItem(at sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func mergeHooksIntoHooksJSON() throws {
        if fileManager.fileExists(atPath: hooksJSONURL.path) {
            let backupURL = hooksJSONURL.deletingPathExtension()
                .appendingPathExtension("bak.\(Self.timestampBackupSuffix())")
            try fileManager.copyItem(at: hooksJSONURL, to: backupURL)
        }

        let merged = try Self.mergedHooksJSON(
            existingData: try? Data(contentsOf: hooksJSONURL),
            stopHookCommand: Self.stopHookCommand,
            shellHookCommand: Self.shellHookCommand,
            mcpHookCommand: Self.mcpHookCommand
        )
        try merged.write(to: hooksJSONURL, options: .atomic)
    }

    static func mergedHooksJSON(
        existingData: Data?,
        stopHookCommand: String,
        shellHookCommand: String,
        mcpHookCommand: String
    ) throws -> Data {
        var root: [String: Any]
        if let existingData,
           let parsed = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
            root = parsed
        } else {
            root = [:]
        }

        if root["version"] == nil {
            root["version"] = 1
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]

        hooks["stop"] = Self.mergedHookEntries(
            existing: hooks["stop"] as? [[String: Any]] ?? [],
            command: stopHookCommand,
            matcher: "Stop"
        )
        hooks["beforeShellExecution"] = Self.mergedHookEntries(
            existing: hooks["beforeShellExecution"] as? [[String: Any]] ?? [],
            command: shellHookCommand
        )
        hooks["beforeMCPExecution"] = Self.mergedHookEntries(
            existing: hooks["beforeMCPExecution"] as? [[String: Any]] ?? [],
            command: mcpHookCommand
        )

        root["hooks"] = hooks

        guard JSONSerialization.isValidJSONObject(root) else {
            throw CursorNotifyInstallError.fileOperationFailed("Generated hooks.json is invalid.")
        }

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        if let string = String(data: data, encoding: .utf8) {
            return (string + "\n").data(using: .utf8) ?? data
        }
        return data
    }

    private static func mergedHookEntries(
        existing: [[String: Any]],
        command: String,
        matcher: String? = nil
    ) -> [[String: Any]] {
        var entries = existing
        let alreadyInstalled = entries.contains { hook in
            hook["command"] as? String == command
        }

        guard !alreadyInstalled else { return entries }

        var entry: [String: Any] = ["command": command]
        if let matcher {
            entry["matcher"] = matcher
        }
        entries.append(entry)
        return entries
    }

    private func sendTestNotificationIfPossible() throws {
        guard let contents = try? String(contentsOf: envFileURL, encoding: .utf8) else { return }
        guard let topic = CursorNotifyEnvFile(contents: contents).topic,
              !topic.isEmpty,
              topic != "your-topic-name",
              let url = URL(string: "https://ntfy.sh/\(topic)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "DesktopNumber: Cursor notify hooks installed".data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        var requestError: Error?
        URLSession.shared.dataTask(with: request) { _, response, error in
            requestError = error
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                requestError = CursorNotifyInstallError.fileOperationFailed(
                    "Test notification failed with status \(http.statusCode)."
                )
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let requestError {
            throw requestError
        }
    }

    private static func timestampBackupSuffix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }
}
