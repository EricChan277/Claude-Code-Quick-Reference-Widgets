// Models.swift
// All shared data model types, app-group UserDefaults keys, and the
// canonical agent → category mapping from spec § Categories.

import Foundation

// MARK: - App Group

/// Shared app group used for UserDefaults and cross-process coordination.
let appGroupID = "group.dev.claudewidget"

/// UserDefaults backed by the shared app group.
var sharedDefaults: UserDefaults {
    UserDefaults(suiteName: appGroupID) ?? .standard
}

// MARK: - UserDefaults keys

enum DefaultsKey {
    static let committedQuery  = "committedQuery"
    static let agentsCollapsed = "agentsCollapsed"
    static let lastCopiedSlug  = "lastCopiedSlug"
    static let lastCopiedAt    = "lastCopiedAt"
}

// MARK: - UsageEntry (timeline entry data)

/// The data snapshot produced by `TimelineProvider` and consumed by widget views.
struct UsageEntry: Codable {
    var date: Date = .now
    var lastRefreshedAt: Date = .now
    var model: String = "Sonnet 4.6"
    var session: PeriodUsage = .empty
    var weekly: PeriodUsage = .empty
    var context: ContextUsage = .stale
    var agents: [AgentInfo] = []
    var sparkline: [Int] = Array(repeating: 0, count: 24)
    var dataState: DataStateFlags = .init()

    static let placeholder = UsageEntry()
}

// MARK: - PeriodUsage

struct PeriodUsage: Codable {
    var percent: Double        // 0.0 … 1.0
    var resetAt: Date
    var hasData: Bool

    static let empty = PeriodUsage(percent: 0, resetAt: .distantFuture, hasData: false)
}

// MARK: - ContextUsage

struct ContextUsage: Codable {
    var usedTokens: Int?
    var totalTokens: Int
    var isStale: Bool

    static let stale = ContextUsage(usedTokens: nil, totalTokens: 200_000, isStale: true)
}

// MARK: - DataStateFlags

struct DataStateFlags: Codable {
    var isLoading: Bool = true
    var permissionsDenied: Bool = false
    var agentsEmpty: Bool = false
}

// MARK: - AgentInfo

struct AgentInfo: Codable, Identifiable, Equatable {
    var slug: String
    var category: AgentCategory

    var id: String { slug }

    /// Display name derived from slug (replace hyphens with spaces, but keep slug as canonical key).
    var displaySlug: String { slug }
}

// MARK: - AgentCategory

enum AgentCategory: String, Codable, CaseIterable {
    case aiML             = "AI & ML"
    case frontendUI       = "FRONTEND & UI"
    case backendAPI       = "BACKEND & API"
    case mobileDesktop    = "MOBILE & DESKTOP"
    case languages        = "LANGUAGES"
    case qualitySecurity  = "QUALITY & SECURITY"
    case opsPerformance   = "OPS & PERFORMANCE"
    case coordinationPM   = "COORDINATION & PM"
    case other            = "OTHER"

    /// Short label used in V4's 3-column grid. Spec § Categories table.
    var shortLabel: String {
        switch self {
        case .aiML:            return "AI/ML"
        case .frontendUI:      return "FRONTEND"
        case .backendAPI:      return "BACKEND"
        case .mobileDesktop:   return "MOBILE"
        case .languages:       return "LANGUAGES"
        case .qualitySecurity: return "QUALITY"
        case .opsPerformance:  return "OPS"
        case .coordinationPM:  return "COORD"
        case .other:           return "OTHER"
        }
    }

    /// Full display label (V6). Spec § Categories table.
    var fullLabel: String { rawValue }

    // MARK: Default agent → category mapping
    // Canonical mapping from spec § Categories.

    static func defaultCategory(for slug: String) -> AgentCategory {
        switch slug {
        case "ai-engineer", "llm-architect", "machine-learning-engineer",
             "ml-engineer", "mlops-engineer", "nlp-engineer",
             "prompt-engineer", "reinforcement-learning-engineer":
            return .aiML

        case "design-bridge", "frontend-developer", "react-specialist", "ui-designer":
            return .frontendUI

        case "api-designer", "backend-developer", "fullstack-developer", "websocket-engineer":
            return .backendAPI

        case "electron-pro", "expo-react-native-expert", "game-developer",
             "iot-engineer", "mobile-app-developer", "mobile-developer", "swift-expert":
            return .mobileDesktop

        case "javascript-pro", "powershell-7-expert", "powershell-ui-architect", "typescript-pro":
            return .languages

        case "debugger", "error-detective", "qa-expert", "security-auditor",
             "test-automator", "ui-ux-tester":
            return .qualitySecurity

        case "git-workflow-manager", "performance-monitor":
            return .opsPerformance

        case "agent-installer", "multi-agent-coordinator", "product-manager",
             "project-manager", "task-distributor":
            return .coordinationPM

        default:
            return .other
        }
    }
}

// MARK: - Grouped agents helper

extension Array where Element == AgentInfo {
    /// Returns agents grouped by category in the canonical display order.
    func grouped() -> [(category: AgentCategory, agents: [AgentInfo])] {
        let dict = Dictionary(grouping: self, by: \.category)
        return AgentCategory.allCases.compactMap { cat in
            guard let agents = dict[cat], !agents.isEmpty else { return nil }
            return (category: cat, agents: agents.sorted { $0.slug < $1.slug })
        }
    }

    /// Flat search results: case-insensitive substring match, ordered by
    /// canonical category then alpha within category.
    func matching(query: String) -> [AgentInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return self }
        return AgentCategory.allCases.flatMap { cat in
            self.filter { $0.category == cat && $0.slug.lowercased().contains(q) }
                .sorted { $0.slug < $1.slug }
        }
    }
}

// MARK: - Duration formatting

extension TimeInterval {
    /// "3h 28m", "45m", "< 1m" etc. Used in reset countdown hints.
    var compactDuration: String {
        let total = Int(self)
        let hours = total / 3600
        let mins  = (total % 3600) / 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0              { return "\(hours)h" }
        if mins  > 0              { return "\(mins)m" }
        return "< 1m"
    }
}

extension Date {
    /// "updated 3m ago" string, refreshed from `lastRefreshedAt`.
    func updatedAgoString(relativeTo now: Date = .now) -> String {
        let diff = Int(now.timeIntervalSince(self))
        if diff < 60  { return "just now" }
        if diff < 3600 { return "updated \(diff / 60)m ago" }
        return "updated \(diff / 3600)h ago"
    }

    /// "Mon 1:00 AM" format for reset-time display.
    var resetTimeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE h:mm a"
        return fmt.string(from: self)
    }
}

// MARK: - Token formatting

extension Int {
    var kFormatted: String {
        if self >= 1_000_000 {
            let v = Double(self) / 1_000_000
            return String(format: "%.1fM", v)
        }
        if self >= 1_000 {
            let v = Double(self) / 1_000
            return String(format: "%.0fk", v)
        }
        return "\(self)"
    }
}
