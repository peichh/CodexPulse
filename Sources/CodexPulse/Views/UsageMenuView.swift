import SwiftUI

struct UsageMenuView: View {
    @ObservedObject var store: UsageStore
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @AppStorage("selectedProject") private var selectedProject = "All projects"
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        let now = store.currentTime
        let palette = currentPalette
        let overview = store.overview(for: selectedProject)
        let heatmap = store.heatmapDays(for: selectedProject)
        let projects = store.projectOptions()

        VStack(spacing: 0) {
            header(palette)

            VStack(alignment: .leading, spacing: 16) {
                serviceHeader(palette)
                projectFilter(projects, palette: palette)

                if let limits = store.snapshot.rateLimits {
                    rateCard(limits.primary, fallbackTitle: "5h", now: now, palette: palette)
                    rateCard(limits.secondary, fallbackTitle: "Weekly", now: now, palette: palette)
                } else {
                    emptyLimitCard(palette)
                }

                Divider().overlay(palette.divider)

                heatmapView(heatmap, palette: palette)

                Divider().overlay(palette.divider)

                metricGrid(overview, palette: palette)

                Divider().overlay(palette.divider)

                projectSummary(store.projectUsage(for: selectedProject), palette: palette)

                Divider().overlay(palette.divider)

                modelSummary(overview.models, palette: palette)

                Divider().overlay(palette.divider)

                actions(palette)

                Text("Built with Codex")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
        .frame(width: 420)
        .background(palette.background)
        .preferredColorScheme(currentAppearance.preferredColorScheme)
    }

    private var currentAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    private var currentPalette: PulsePalette {
        let mode = currentAppearance
        let isDark = mode == .dark || (mode == .system && systemColorScheme == .dark)
        return PulsePalette(isDark: isDark)
    }

    private func header(_ palette: PulsePalette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.accent)

            Text("AI Usage")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Last update")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.muted)
                Text(UsageFormatters.lastUpdate(store.snapshot.generatedAt))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(palette.header)
    }

    private func serviceHeader(_ palette: PulsePalette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(palette.accent)
            Text("Codex")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.primary)
            Text("session logs")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.pill, in: Capsule())
            Spacer()
        }
    }

    private func projectFilter(_ projects: [String], palette: PulsePalette) -> some View {
        HStack(spacing: 10) {
            Text("Project")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.muted)

            Picker("", selection: $selectedProject) {
                ForEach(projects, id: \.self) { project in
                    Text(project).tag(project)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Spacer()
        }
    }

    private func rateCard(_ window: RateLimitWindow?, fallbackTitle: String, now: Date, palette: PulsePalette) -> some View {
        let accent = limitAccent(window, palette: palette)

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(window?.title ?? fallbackTitle, systemImage: fallbackTitle == "Weekly" ? "calendar" : "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.primary)

                Spacer()

                if let window {
                    Text("Reset \(UsageFormatters.resetTime(window.resetsAt))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }

            ProgressView(value: (window?.usedPercent ?? 0) / 100)
                .progressViewStyle(.linear)
                .tint(accent)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)

            HStack {
                if let window {
                    Text("\(UsageFormatters.percentValue(window.usedPercent)) used")
                    Spacer()
                    Text("reset in \(UsageFormatters.countdownWithSeconds(window.resetsAt, from: now))")
                } else {
                    Text("No rate limit data")
                    Spacer()
                    Text("--:--:--")
                }
            }
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.secondary)

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
                .foregroundStyle(palette.muted)
            }
        }
    }

    private func limitAccent(_ window: RateLimitWindow?, palette: PulsePalette) -> Color {
        guard let window, window.remainingPercent < 20 else {
            return palette.accent
        }

        return palette.warning
    }

    private func estimateLine(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(UsageFormatters.compact(value))
                .fontDesign(.monospaced)
        }
    }

    private func emptyLimitCard(_ palette: PulsePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage remaining")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(palette.primary)
            ProgressView(value: 0)
                .progressViewStyle(.linear)
            Text("Open Codex once to refresh rate limit data")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondary)
        }
    }

    private func heatmapView(_ days: [DailyUsage], palette: PulsePalette) -> some View {
        let maxTokens = max(days.map(\.totalTokens).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.primary)

            HStack(spacing: 6) {
                ForEach(days) { day in
                    let intensity = Double(day.totalTokens) / Double(maxTokens)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(dayColor(intensity: intensity, palette: palette))
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(palette.divider, lineWidth: 1)
                        )
                        .help("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(UsageFormatters.compact(day.totalTokens)) tokens, \(day.sessionCount) sessions")
                }
            }

            HStack {
                Text("14 days")
                Spacer()
                Text("Today")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.muted)
        }
    }

    private func dayColor(intensity: Double, palette: PulsePalette) -> Color {
        let clamped = min(max(intensity, 0), 1)
        if clamped == 0 {
            return palette.button
        }

        return palette.accent.opacity(0.15 + (clamped * 0.85))
    }

    private func metricGrid(_ overview: UsageOverview, palette: PulsePalette) -> some View {
        VStack(spacing: 8) {
            metricRow("Today total", overview.today.effectiveTotal, palette: palette)
            metricRow("Today input", overview.today.inputTokens, palette: palette)
            metricRow("Today cached", overview.today.cachedInputTokens, palette: palette)
            metricRow("Today output", overview.today.outputTokens, palette: palette)
            metricRow("Today reasoning", overview.today.reasoningOutputTokens, palette: palette)
            metricRow("Sessions today", overview.sessionsToday, palette: palette)
            metricRow("All total", overview.allTime.effectiveTotal, palette: palette)
        }
    }

    private func metricRow(_ label: String, _ value: Int, palette: PulsePalette) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(palette.secondary)
            Spacer()
            Text(UsageFormatters.integer(value))
                .fontDesign(.monospaced)
                .foregroundStyle(palette.primary)
        }
        .font(.system(size: 13, weight: .medium))
    }

    private func projectSummary(_ projects: [ProjectUsage], palette: PulsePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projects")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.primary)

            if projects.isEmpty {
                Text("No project data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.muted)
            } else {
                ForEach(projects.prefix(3)) { project in
                    HStack {
                        Text(UsageFormatters.shortMenuText(project.name, limit: 24))
                        Spacer()
                        Text("\(UsageFormatters.compact(project.usage.effectiveTotal)) · \(project.sessionCount)")
                            .fontDesign(.monospaced)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                }
            }
        }
    }

    private func modelSummary(_ models: [ModelUsage], palette: PulsePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.primary)

            if models.isEmpty {
                Text("No token usage")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.muted)
            } else {
                ForEach(models.prefix(4)) { model in
                    HStack {
                        Text(UsageFormatters.shortMenuText(model.id, limit: 24))
                        Spacer()
                        Text(UsageFormatters.compact(model.usage.effectiveTotal))
                            .fontDesign(.monospaced)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                }
            }
        }
    }

    private func actions(_ palette: PulsePalette) -> some View {
        HStack(spacing: 10) {
            Button("Refresh") {
                store.refresh()
            }
            .buttonStyle(ActionButtonStyle(kind: .accent, palette: palette))

            Button("Open Folder") {
                store.openCodexFolder()
            }
            .buttonStyle(ActionButtonStyle(kind: .accent, palette: palette))

            SettingsLink {
                Text("Settings")
            }
            .buttonStyle(ActionButtonStyle(kind: .accent, palette: palette))

            Button("Quit") {
                store.quit()
            }
            .buttonStyle(ActionButtonStyle(kind: .neutral, palette: palette))
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    enum Kind {
        case accent
        case neutral
    }

    let kind: Kind
    let palette: PulsePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(kind == .accent ? palette.accent : palette.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 8))
    }

    private func background(_ isPressed: Bool) -> Color {
        let base = palette.button
        return isPressed ? base.opacity(0.72) : base
    }
}

private struct PulsePalette {
    let isDark: Bool

    var background: Color {
        isDark ? Color(red: 0.055, green: 0.055, blue: 0.065) : Color(red: 0.965, green: 0.965, blue: 0.955)
    }

    var header: Color {
        isDark ? Color.black.opacity(0.28) : Color.white.opacity(0.72)
    }

    var primary: Color {
        isDark ? .white.opacity(0.88) : .black.opacity(0.82)
    }

    var secondary: Color {
        isDark ? .white.opacity(0.58) : .black.opacity(0.56)
    }

    var muted: Color {
        isDark ? .white.opacity(0.36) : .black.opacity(0.38)
    }

    var divider: Color {
        isDark ? .white.opacity(0.08) : .black.opacity(0.10)
    }

    var pill: Color {
        isDark ? .white.opacity(0.08) : .black.opacity(0.07)
    }

    var button: Color {
        isDark ? .white.opacity(0.08) : .black.opacity(0.06)
    }

    var accent: Color {
        Color(red: 0.95, green: 0.62, blue: 0.18)
    }

    var warning: Color {
        Color(red: 0.88, green: 0.20, blue: 0.18)
    }
}
