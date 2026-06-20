import Foundation

enum UsageFormatters {
    static func compact(_ value: Int) -> String {
        let number = Double(value)

        if value >= 1_000_000_000 {
            return String(format: "%.1fb", number / 1_000_000_000)
        }

        if value >= 1_000_000 {
            return String(format: "%.1fm", number / 1_000_000)
        }

        if value >= 1_000 {
            return String(format: "%.1fk", number / 1_000)
        }

        return "\(value)"
    }

    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func percent(used: Int, budget: Int) -> String {
        guard budget > 0 else {
            return "0%"
        }

        let percent = min((Double(used) / Double(budget)) * 100, 999)
        if percent >= 10 {
            return String(format: "%.0f%%", percent)
        }

        return String(format: "%.1f%%", percent)
    }

    static func hoursUntil(_ date: Date, from now: Date = Date()) -> String {
        let hours = max(date.timeIntervalSince(now) / 3600, 0)

        if hours >= 10 {
            return String(format: "%.0fh", hours)
        }

        return String(format: "%.1fh", hours)
    }

    static func countdown(_ date: Date, from now: Date = Date()) -> String {
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    static func percentValue(_ value: Double) -> String {
        if value >= 10 {
            return String(format: "%.0f%%", value)
        }

        return String(format: "%.1f%%", value)
    }

    static func resetTime(_ date: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: Date()) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func lastUpdate(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    static func shortMenuText(_ text: String, limit: Int = 30) -> String {
        guard text.count > limit else {
            return text
        }

        return String(text.prefix(max(limit - 1, 1))) + "…"
    }
}
