import AppKit
import Combine
import Foundation

final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot
    @Published private(set) var nextResetDate = Date()
    @Published private(set) var currentTime = Date()

    private let reader = CodexUsageReader()
    private var scanTimer: Timer?
    private var clockTimer: Timer?
    private var isRefreshing = false
    private let heatmapDays = 14
    private var derivedCache: [String: DerivedUsage] = [:]

    private struct DerivedUsage {
        let overview: UsageOverview
        let heatmap: [DailyUsage]
        let projects: [ProjectUsage]
    }

    init() {
        let home = reader.codexHome()
        snapshot = UsageSnapshot.empty(codexHome: home)
    }

    var menuTitle: String {
        if let window = snapshot.rateLimits?.preferredWindow {
            let percent = UsageFormatters.percentValue(window.usedPercent)
            let reset = UsageFormatters.countdownWithSeconds(window.resetsAt, from: currentTime)
            return "use \(percent) | \(reset)"
        }

        return "use --% | --:--:--"
    }

    func start() {
        refresh()

        if scanTimer == nil {
            scanTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                self?.refresh()
            }
        }

        if clockTimer == nil {
            clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.currentTime = Date()
            }
        }
    }

    func refresh() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true

        DispatchQueue.global(qos: .utility).async {
            let loaded = self.reader.loadSnapshot(resetHour: 0)
            let nextReset = self.reader.nextResetDate(resetHour: 0)

            DispatchQueue.main.async {
                self.snapshot = loaded
                self.nextResetDate = nextReset
                self.currentTime = Date()
                self.derivedCache.removeAll()
                self.isRefreshing = false
            }
        }
    }

    func openCodexFolder() {
        NSWorkspace.shared.open(snapshot.codexHome)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func projectOptions() -> [String] {
        let names = Set(snapshot.sessions.map(\.projectName))
        return ["All projects"] + names.sorted()
    }

    func overview(for selectedProject: String) -> UsageOverview {
        derivedUsage(for: selectedProject).overview
    }

    func heatmapDays(for selectedProject: String) -> [DailyUsage] {
        derivedUsage(for: selectedProject).heatmap
    }

    func projectUsage(for selectedProject: String) -> [ProjectUsage] {
        derivedUsage(for: selectedProject).projects
    }

    private func filteredSessions(for selectedProject: String) -> [SessionUsage] {
        if selectedProject == "All projects" {
            return snapshot.sessions
        }

        return snapshot.sessions.filter { $0.projectName == selectedProject }
    }

    private func derivedUsage(for selectedProject: String) -> DerivedUsage {
        if let cached = derivedCache[selectedProject] {
            return cached
        }

        let sessions = filteredSessions(for: selectedProject)
        let now = Date()
        let todayStart = Calendar.current.startOfDay(for: now)
        let windowStart = snapshot.rateLimits?.preferredWindow?.windowStart
        let calendar = Calendar.current
        let heatmapStart = calendar.date(byAdding: .day, value: -(heatmapDays - 1), to: todayStart) ?? todayStart

        var overview = UsageOverview()
        var modelTotals: [String: TokenUsage] = [:]
        var projectBuckets: [String: (usage: TokenUsage, count: Int)] = [:]
        var dayBuckets: [Date: (tokens: Int, sessions: Int)] = [:]

        for session in sessions {
            overview.allTime.add(session.usage)
            modelTotals[session.model, default: .zero].add(session.usage)

            var projectBucket = projectBuckets[session.projectName] ?? (usage: .zero, count: 0)
            projectBucket.usage.add(session.usage)
            projectBucket.count += 1
            projectBuckets[session.projectName] = projectBucket

            if session.localDay == todayStart {
                overview.today.add(session.usage)
                overview.sessionsToday += 1
            }

            if let windowStart, session.date >= windowStart {
                overview.currentWindow.add(session.usage)
                overview.sessionsInWindow += 1
            }

            if session.date >= heatmapStart {
                let day = calendar.startOfDay(for: session.date)
                var bucket = dayBuckets[day] ?? (tokens: 0, sessions: 0)
                bucket.tokens += session.usage.effectiveTotal
                bucket.sessions += 1
                dayBuckets[day] = bucket
            }
        }

        overview.models = modelTotals
            .map { ModelUsage(id: $0.key, usage: $0.value) }
            .sorted { $0.usage.effectiveTotal > $1.usage.effectiveTotal }

        let heatmap: [DailyUsage] = (0..<heatmapDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: heatmapStart) else { return nil }
            let bucket = dayBuckets[date] ?? (0, 0)
            return DailyUsage(
                id: date,
                date: date,
                totalTokens: bucket.tokens,
                sessionCount: bucket.sessions
            )
        }

        let projects = projectBuckets
            .map { key, value in
                ProjectUsage(id: key, name: key, sessionCount: value.count, usage: value.usage)
            }
            .sorted { $0.usage.effectiveTotal > $1.usage.effectiveTotal }

        let bundle = DerivedUsage(overview: overview, heatmap: heatmap, projects: projects)
        derivedCache[selectedProject] = bundle
        return bundle
    }
}
