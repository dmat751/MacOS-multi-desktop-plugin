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

struct CursorNotifyInstaller {
    static let stopHookCommand = "./hooks/on-stop.sh"
    static let bundledResourceDirectory = "CursorHooks"

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
        try installBundledScript(named: "on-stop", destinationName: "on-stop.sh")

        if !fileManager.fileExists(atPath: envFileURL.path) {
            let exampleURL = try bundledResourceURL(name: "notify.env.example")
            try copyReplacingItem(at: exampleURL, to: envFileURL)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: envFileURL.path)
        }

        try mergeStopHookIntoHooksJSON()
        if sendTestNotification {
            try sendTestNotificationIfPossible()
        }
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

    func mergeStopHookIntoHooksJSON() throws {
        if fileManager.fileExists(atPath: hooksJSONURL.path) {
            let backupURL = hooksJSONURL.deletingPathExtension()
                .appendingPathExtension("bak.\(Self.timestampBackupSuffix())")
            try fileManager.copyItem(at: hooksJSONURL, to: backupURL)
        }

        let merged = try Self.mergedHooksJSON(
            existingData: try? Data(contentsOf: hooksJSONURL),
            stopHookCommand: Self.stopHookCommand
        )
        try merged.write(to: hooksJSONURL, options: .atomic)
    }

    static func mergedHooksJSON(existingData: Data?, stopHookCommand: String) throws -> Data {
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
        var stopHooks = hooks["stop"] as? [[String: Any]] ?? []
        let alreadyInstalled = stopHooks.contains { hook in
            hook["command"] as? String == stopHookCommand
        }

        if !alreadyInstalled {
            stopHooks.append([
                "command": stopHookCommand,
                "matcher": "Stop",
            ])
        }

        hooks["stop"] = stopHooks
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
