import Foundation

enum UsageFormatting {
    static func formatDollars(cents: Int) -> String {
        let dollars = Double(cents) / 100.0

        if dollars > 0 && dollars < 0.01 {
            return String(format: "$%.4f", dollars)
        }

        return String(format: "$%.2f", dollars)
    }

    static func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000.0)
        }

        if tokens >= 1_000 {
            return "\(tokens / 1_000)k"
        }

        return String(tokens)
    }

    static func formatRelativeTime(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))

        if seconds < 60 {
            return "just now"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60
        return "\(hours)h ago"
    }
}
