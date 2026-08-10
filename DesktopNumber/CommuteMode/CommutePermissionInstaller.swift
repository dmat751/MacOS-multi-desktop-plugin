import AppKit
import Foundation

enum CommutePermissionInstallError: LocalizedError {
    case missingBundleResource
    case cancelled
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBundleResource:
            return "Missing bundled commute permission installer script."
        case .cancelled:
            return "Permission installation was cancelled."
        case .scriptFailed(let message):
            return message
        }
    }
}

protocol PrivilegedScriptRunner {
    func runPrivilegedShellScript(_ shellCommand: String) throws -> String
}

struct NSAppleScriptPrivilegedRunner: PrivilegedScriptRunner {
    func runPrivilegedShellScript(_ shellCommand: String) throws -> String {
        let source =
            "do shell script \"\(AppleScriptShellEscaping.escapeForAppleScriptShell(shellCommand))\" with administrator privileges"
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)
        guard let result = script?.executeAndReturnError(&errorInfo) else {
            if let errorInfo {
                let number = errorInfo[NSAppleScript.errorNumber] as? Int
                if number == -128 {
                    throw CommutePermissionInstallError.cancelled
                }
                let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                throw CommutePermissionInstallError.scriptFailed(message)
            }
            throw CommutePermissionInstallError.scriptFailed("AppleScript execution failed.")
        }

        return result.stringValue ?? ""
    }
}

enum AppleScriptShellEscaping {
    static func escapeForAppleScriptShell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func escapeForSingleQuotedShell(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

struct CommutePermissionInstaller {
    static let bundledResourceDirectory = "CommuteScripts"
    static let scriptName = "install-commute-permission.sh"

    private let bundle: Bundle
    private let runner: PrivilegedScriptRunner

    init(
        bundle: Bundle = .main,
        runner: PrivilegedScriptRunner = NSAppleScriptPrivilegedRunner()
    ) {
        self.bundle = bundle
        self.runner = runner
    }

    func install(username: String) throws {
        let scriptURL = try bundledScriptURL()
        let shellCommand = Self.installShellCommand(
            username: username,
            scriptPath: scriptURL.path
        )
        _ = try runner.runPrivilegedShellScript(shellCommand)
    }

    static func installShellCommand(username: String, scriptPath: String) -> String {
        let escapedUser = AppleScriptShellEscaping.escapeForSingleQuotedShell(username)
        let escapedPath = AppleScriptShellEscaping.escapeForSingleQuotedShell(scriptPath)
        return "export SUDO_USER=\(escapedUser); /bin/bash \(escapedPath)"
    }

    private func bundledScriptURL() throws -> URL {
        if let url = bundle.url(
            forResource: "install-commute-permission",
            withExtension: "sh",
            subdirectory: Self.bundledResourceDirectory
        ) {
            return url
        }

        throw CommutePermissionInstallError.missingBundleResource
    }
}
