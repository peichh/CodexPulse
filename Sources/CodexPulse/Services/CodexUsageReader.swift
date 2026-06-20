import Foundation

final class CodexUsageReader {
    private let calendar = Calendar.current
    private var cache: [URL: CachedSession] = [:]

    private struct CachedSession {
        let modificationDate: Date?
        let fileSize: Int?
        let session: SessionUsage?
    }

    func codexHome() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }

        return FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex")
    }

    func loadSnapshot(resetHour: Int) -> UsageSnapshot {
        let home = codexHome()
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let resetWindow = resetWindow(for: now, resetHour: resetHour)

        var snapshot = UsageSnapshot.empty(codexHome: home)
        var modelTotals: [String: TokenUsage] = [:]
        let files = sessionFiles(in: home)
        let activeFiles = Set(files)
        cache = cache.filter { activeFiles.contains($0.key) }

        let sessions = files.compactMap(latestUsageEvent)
        snapshot.sessions = sessions

        for session in sessions {
            snapshot.allTime.add(session.usage)
            modelTotals[session.model, default: .zero].add(session.usage)

            if let rateLimits = session.rateLimits,
               snapshot.rateLimits == nil || rateLimits.eventDate > snapshot.rateLimits!.eventDate {
                snapshot.rateLimits = rateLimits
            }

            if session.localDay == todayStart {
                snapshot.today.add(session.usage)
                snapshot.sessionsToday += 1
            }

            if session.date >= resetWindow.start && session.date < resetWindow.end {
                snapshot.currentWindow.add(session.usage)
                snapshot.sessionsInWindow += 1
            }
        }

        if let rateLimits = snapshot.rateLimits {
            snapshot.rateLimits = rateLimitsWithTokenEstimates(rateLimits, sessions: sessions)
        }

        snapshot.models = modelTotals
            .map { ModelUsage(id: $0.key, usage: $0.value) }
            .sorted { $0.usage.effectiveTotal > $1.usage.effectiveTotal }
        snapshot.generatedAt = now

        return snapshot
    }

    private func rateLimitsWithTokenEstimates(_ rateLimits: RateLimits, sessions: [SessionUsage]) -> RateLimits {
        RateLimits(
            eventDate: rateLimits.eventDate,
            primary: rateLimits.primary.map { windowWithTokenEstimate($0, sessions: sessions) },
            secondary: rateLimits.secondary.map { windowWithTokenEstimate($0, sessions: sessions) }
        )
    }

    private func windowWithTokenEstimate(_ window: RateLimitWindow, sessions: [SessionUsage]) -> RateLimitWindow {
        let tokens = sessions
            .filter { $0.date >= window.windowStart && $0.date < window.resetsAt }
            .reduce(0) { $0 + $1.usage.effectiveTotal }

        return window.withTokenEstimate(tokens)
    }

    func nextResetDate(resetHour: Int, from now: Date = Date()) -> Date {
        resetWindow(for: now, resetHour: resetHour).end
    }

    private func resetWindow(for now: Date, resetHour: Int) -> (start: Date, end: Date) {
        let safeHour = min(max(resetHour, 0), 23)
        let today = calendar.startOfDay(for: now)
        let todayReset = calendar.date(byAdding: .hour, value: safeHour, to: today) ?? today

        if now >= todayReset {
            let tomorrowReset = calendar.date(byAdding: .day, value: 1, to: todayReset) ?? todayReset
            return (todayReset, tomorrowReset)
        }

        let yesterdayReset = calendar.date(byAdding: .day, value: -1, to: todayReset) ?? todayReset
        return (yesterdayReset, todayReset)
    }

    private func sessionFiles(in home: URL) -> [URL] {
        let roots = [
            home.appending(path: "sessions"),
            home.appending(path: "archived_sessions")
        ]

        return roots.flatMap { root -> [URL] in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return enumerator.compactMap { item -> URL? in
                guard let url = item as? URL else {
                    return nil
                }

                guard url.lastPathComponent.hasPrefix("rollout-"),
                      url.pathExtension == "jsonl" else {
                    return nil
                }

                let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
                return values?.isRegularFile == true ? url : nil
            }
        }
    }

    private func latestUsageEvent(in file: URL) -> SessionUsage? {
        let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modificationDate = values?.contentModificationDate
        let fileSize = values?.fileSize

        if let cached = cache[file],
           cached.modificationDate == modificationDate,
           cached.fileSize == fileSize {
            return cached.session
        }

        guard let content = try? String(contentsOf: file, encoding: .utf8) else {
            cache[file] = CachedSession(
                modificationDate: modificationDate,
                fileSize: fileSize,
                session: nil
            )
            return nil
        }

        var latest: SessionUsage?
        var workingDirectory: String?

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = eventType(object) else {
                continue
            }

            if type == "session_meta" {
                if workingDirectory == nil {
                    workingDirectory = (object["payload"] as? [String: Any])?["cwd"] as? String
                }
                continue
            }

            guard type == "token_count",
                  let info = eventInfo(object),
                  let usageObject = info["total_token_usage"] as? [String: Any] else {
                continue
            }

            let usage = tokenUsage(from: usageObject)
            guard !usage.isEmpty else {
                continue
            }

            let date = eventDate(object)
            let projectPath = workingDirectory
            latest = SessionUsage(
                id: file,
                date: date,
                localDay: calendar.startOfDay(for: date),
                model: eventModel(object, info: info),
                projectName: projectName(for: projectPath, file: file),
                projectPath: projectPath,
                usage: usage,
                rateLimits: eventRateLimits(object, eventDate: date)
            )
        }

        cache[file] = CachedSession(
            modificationDate: modificationDate,
            fileSize: fileSize,
            session: latest
        )

        return latest
    }

    private func projectName(for projectPath: String?, file: URL) -> String {
        if let projectPath, !projectPath.isEmpty {
            let url = URL(fileURLWithPath: projectPath)
            let name = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        return "Codex sessions"
    }

    private func eventType(_ event: [String: Any]) -> String? {
        if let payload = event["payload"] as? [String: Any],
           let payloadType = payload["type"] as? String {
            return payloadType
        }

        return event["type"] as? String
    }

    private func eventInfo(_ event: [String: Any]) -> [String: Any]? {
        if let payload = event["payload"] as? [String: Any],
           let info = payload["info"] as? [String: Any] {
            return info
        }

        return event["info"] as? [String: Any]
    }

    private func eventRateLimits(_ event: [String: Any], eventDate: Date) -> RateLimits? {
        let payload = event["payload"] as? [String: Any]
        let raw = payload?["rate_limits"] as? [String: Any] ?? event["rate_limits"] as? [String: Any]

        guard let raw else {
            return nil
        }

        let primary = rateLimitWindow(
            id: "primary",
            title: shortWindowTitle(raw["primary"] as? [String: Any], fallback: "Short"),
            raw: raw["primary"] as? [String: Any]
        )
        let secondary = rateLimitWindow(
            id: "secondary",
            title: shortWindowTitle(raw["secondary"] as? [String: Any], fallback: "Weekly"),
            raw: raw["secondary"] as? [String: Any]
        )

        if primary == nil && secondary == nil {
            return nil
        }

        return RateLimits(eventDate: eventDate, primary: primary, secondary: secondary)
    }

    private func rateLimitWindow(id: String, title: String, raw: [String: Any]?) -> RateLimitWindow? {
        guard let raw,
              let resetsAt = unixDate(raw["resets_at"]) else {
            return nil
        }

        return RateLimitWindow(
            id: id,
            title: title,
            usedPercent: doubleValue(raw["used_percent"]),
            windowMinutes: intValue(raw["window_minutes"]),
            resetsAt: resetsAt
        )
    }

    private func shortWindowTitle(_ raw: [String: Any]?, fallback: String) -> String {
        guard let minutes = raw?["window_minutes"] else {
            return fallback
        }

        let value = intValue(minutes)
        if value == 300 {
            return "5h"
        }

        if value == 10_080 {
            return "Weekly"
        }

        if value > 0, value % 1_440 == 0 {
            return "\(value / 1_440)d"
        }

        if value > 0, value % 60 == 0 {
            return "\(value / 60)h"
        }

        return fallback
    }

    private func eventModel(_ event: [String: Any], info: [String: Any]) -> String {
        let payload = event["payload"] as? [String: Any]
        let model = info["model"] as? String ??
            info["model_name"] as? String ??
            info["current_model"] as? String ??
            payload?["model"] as? String ??
            payload?["model_name"] as? String ??
            event["model"] as? String ??
            event["model_name"] as? String

        if let model, !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return model.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Codex sessions"
    }

    private func eventDate(_ event: [String: Any]) -> Date {
        let payload = event["payload"] as? [String: Any]
        let rawTimestamp = event["timestamp"] ??
            event["time"] ??
            event["created_at"] ??
            event["createdAt"] ??
            payload?["timestamp"] ??
            payload?["time"] ??
            payload?["created_at"] ??
            payload?["createdAt"]

        return parseDate(rawTimestamp) ?? Date()
    }

    private func parseDate(_ raw: Any?) -> Date? {
        if let seconds = raw as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }

        guard let string = raw as? String, !string.isEmpty else {
            return nil
        }

        let normalized = string.hasSuffix("Z") ? String(string.dropLast()) + "+00:00" : string
        return ISO8601DateFormatter().date(from: normalized) ?? fractionalISO8601Formatter.date(from: normalized)
    }

    private var fractionalISO8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private func tokenUsage(from object: [String: Any]) -> TokenUsage {
        var usage = TokenUsage(
            inputTokens: intValue(object["input_tokens"]),
            cachedInputTokens: intValue(object["cached_input_tokens"]),
            outputTokens: intValue(object["output_tokens"]),
            reasoningOutputTokens: intValue(object["reasoning_output_tokens"]),
            totalTokens: intValue(object["total_tokens"])
        )

        if usage.totalTokens == 0 {
            usage.totalTokens = usage.effectiveTotal
        }

        return usage
    }

    private func intValue(_ value: Any?) -> Int {
        if let int = value as? Int {
            return max(int, 0)
        }

        if let double = value as? Double {
            return max(Int(double), 0)
        }

        if let string = value as? String, let double = Double(string) {
            return max(Int(double), 0)
        }

        return 0
    }

    private func doubleValue(_ value: Any?) -> Double {
        if let double = value as? Double {
            return max(double, 0)
        }

        if let int = value as? Int {
            return max(Double(int), 0)
        }

        if let string = value as? String, let double = Double(string) {
            return max(double, 0)
        }

        return 0
    }

    private func unixDate(_ value: Any?) -> Date? {
        if let double = value as? Double {
            return Date(timeIntervalSince1970: double)
        }

        if let int = value as? Int {
            return Date(timeIntervalSince1970: TimeInterval(int))
        }

        if let string = value as? String, let double = Double(string) {
            return Date(timeIntervalSince1970: double)
        }

        return nil
    }
}
