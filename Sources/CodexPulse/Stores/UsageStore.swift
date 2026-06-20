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

    init() {
        let home = reader.codexHome()
        snapshot = UsageSnapshot.empty(codexHome: home)
    }

    var menuTitle: String {
        if let window = snapshot.rateLimits?.preferredWindow {
            let percent = UsageFormatters.percentValue(window.usedPercent)
            let reset = UsageFormatters.countdown(window.resetsAt, from: currentTime)
            return "use \(percent) | \(reset)"
        }

        return "use --% | --:--"
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
}
