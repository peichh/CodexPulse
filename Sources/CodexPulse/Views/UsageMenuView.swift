import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        let snapshot = store.snapshot
        let now = store.currentTime

        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 16) {
                serviceHeader

                if let limits = snapshot.rateLimits {
                    rateCard(limits.primary, fallbackTitle: "5h", now: now)
                    rateCard(limits.secondary, fallbackTitle: "Weekly", now: now)
                } else {
                    emptyLimitCard
                }

                Divider().overlay(.white.opacity(0.08))

                metricGrid(snapshot)

                Divider().overlay(.white.opacity(0.08))

                modelSummary(snapshot)

                Divider().overlay(.white.opacity(0.08))

                actions

                Text("Made by Codex")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.32))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
        .frame(width: 420)
        .background(Color(red: 0.055, green: 0.055, blue: 0.065))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)

            Text("AI Usage")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Last update")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
                Text(UsageFormatters.lastUpdate(store.snapshot.generatedAt))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.28))
    }

    private var serviceHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.orange)
            Text("Codex")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("session logs")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.08), in: Capsule())
            Spacer()
        }
    }

    private func rateCard(_ window: RateLimitWindow?, fallbackTitle: String, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(window?.title ?? fallbackTitle, systemImage: fallbackTitle == "Weekly" ? "calendar" : "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                if let window {
                    Text("Resets \(UsageFormatters.resetTime(window.resetsAt))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }

            ProgressView(value: (window?.usedPercent ?? 0) / 100)
                .progressViewStyle(.linear)
                .tint(.orange)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)

            HStack {
                if let window {
                    Text("\(UsageFormatters.percentValue(window.usedPercent)) used")
                    Spacer()
                    Text("reset \(UsageFormatters.countdown(window.resetsAt, from: now))")
                } else {
                    Text("No rate limit data")
                    Spacer()
                    Text("--:--")
                }
            }
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.48))

            if let window {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(UsageFormatters.percentValue(window.remainingPercent)) remaining")
                    estimateLine("Used tokens", window.windowTokens)

                    if let remaining = window.estimatedRemainingTokens {
                        estimateLine("Est. left", remaining)
                    }

                    if let limit = window.estimatedLimitTokens {
                        estimateLine("Est. limit", limit)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
            }
        }
    }

    private func estimateLine(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(UsageFormatters.compact(value))
                .fontDesign(.monospaced)
        }
    }

    private var emptyLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage remaining")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
            ProgressView(value: 0)
                .progressViewStyle(.linear)
            Text("Open Codex once to refresh rate limit data")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
    }

    private func metricGrid(_ snapshot: UsageSnapshot) -> some View {
        VStack(spacing: 8) {
            metricRow("Today total", snapshot.today.effectiveTotal)
            metricRow("Today input", snapshot.today.inputTokens)
            metricRow("Today cached", snapshot.today.cachedInputTokens)
            metricRow("Today output", snapshot.today.outputTokens)
            metricRow("Today reasoning", snapshot.today.reasoningOutputTokens)
            metricRow("Sessions today", snapshot.sessionsToday)
            metricRow("All total", snapshot.allTime.effectiveTotal)
        }
    }

    private func metricRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(UsageFormatters.integer(value))
                .fontDesign(.monospaced)
                .foregroundStyle(.white.opacity(0.84))
        }
        .font(.system(size: 13, weight: .medium))
    }

    private func modelSummary(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.74))

            if snapshot.models.isEmpty {
                Text("No token usage")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.44))
            } else {
                ForEach(snapshot.models.prefix(4)) { model in
                    HStack {
                        Text(UsageFormatters.shortMenuText(model.id, limit: 24))
                        Spacer()
                        Text(UsageFormatters.compact(model.usage.effectiveTotal))
                            .fontDesign(.monospaced)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Refresh") {
                store.refresh()
            }
            .buttonStyle(ActionButtonStyle(kind: .secondary))

            Button("Open Folder") {
                store.openCodexFolder()
            }
            .buttonStyle(ActionButtonStyle(kind: .secondary))

            SettingsLink {
                Text("Settings")
            }
            .buttonStyle(ActionButtonStyle(kind: .secondary))

            Button("Quit") {
                store.quit()
            }
            .buttonStyle(ActionButtonStyle(kind: .primary))
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(kind == .primary ? Color.black : Color.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 8))
    }

    private func background(_ isPressed: Bool) -> Color {
        let base = kind == .primary ? Color.orange : Color.white.opacity(0.08)
        return isPressed ? base.opacity(0.72) : base
    }
}
