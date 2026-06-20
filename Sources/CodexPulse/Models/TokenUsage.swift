import Foundation

struct TokenUsage: Equatable {
    var inputTokens: Int = 0
    var cachedInputTokens: Int = 0
    var outputTokens: Int = 0
    var reasoningOutputTokens: Int = 0
    var totalTokens: Int = 0

    static let zero = TokenUsage()

    var effectiveTotal: Int {
        if totalTokens > 0 {
            return totalTokens
        }

        return inputTokens + cachedInputTokens + outputTokens + reasoningOutputTokens
    }

    var isEmpty: Bool {
        inputTokens == 0 &&
            cachedInputTokens == 0 &&
            outputTokens == 0 &&
            reasoningOutputTokens == 0 &&
            totalTokens == 0
    }

    mutating func add(_ other: TokenUsage) {
        inputTokens += other.inputTokens
        cachedInputTokens += other.cachedInputTokens
        outputTokens += other.outputTokens
        reasoningOutputTokens += other.reasoningOutputTokens
        totalTokens += other.effectiveTotal
    }
}

struct SessionUsage: Identifiable {
    let id: URL
    let date: Date
    let localDay: Date
    let model: String
    let usage: TokenUsage
    let rateLimits: RateLimits?
}

struct ModelUsage: Identifiable {
    let id: String
    let usage: TokenUsage
}

struct RateLimitWindow: Equatable {
    let id: String
    let title: String
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date
    var windowTokens: Int = 0
    var estimatedLimitTokens: Int?
    var estimatedRemainingTokens: Int?

    var remainingPercent: Double {
        min(max(100 - usedPercent, 0), 100)
    }

    var windowStart: Date {
        resetsAt.addingTimeInterval(-TimeInterval(windowMinutes * 60))
    }

    func withTokenEstimate(_ tokens: Int) -> RateLimitWindow {
        var copy = self
        copy.windowTokens = tokens

        if usedPercent > 0 {
            let estimatedLimit = Int((Double(tokens) / (usedPercent / 100)).rounded())
            copy.estimatedLimitTokens = max(estimatedLimit, tokens)
            copy.estimatedRemainingTokens = max((copy.estimatedLimitTokens ?? tokens) - tokens, 0)
        }

        return copy
    }
}

struct RateLimits: Equatable {
    let eventDate: Date
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    var preferredWindow: RateLimitWindow? {
        primary ?? secondary
    }
}

struct UsageSnapshot {
    var today = TokenUsage.zero
    var currentWindow = TokenUsage.zero
    var allTime = TokenUsage.zero
    var sessionsToday = 0
    var sessionsInWindow = 0
    var models: [ModelUsage] = []
    var rateLimits: RateLimits?
    var codexHome: URL
    var generatedAt = Date()

    static func empty(codexHome: URL) -> UsageSnapshot {
        UsageSnapshot(codexHome: codexHome)
    }
}
