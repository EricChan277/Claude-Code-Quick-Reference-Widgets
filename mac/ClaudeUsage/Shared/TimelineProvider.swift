// TimelineProvider.swift
// WidgetKit TimelineProvider: polls every 60s, feeds UsageEntry to views.
// Spec § Data sources → Polling cadence, § State management.

import WidgetKit
import SwiftUI

// MARK: - ClaudeUsageEntry

/// The concrete WidgetKit `TimelineEntry`.
struct ClaudeUsageEntry: TimelineEntry {
    var date: Date
    var usage: UsageEntry
}

// MARK: - ClaudeUsageProvider

struct ClaudeUsageProvider: TimelineProvider {
    typealias Entry = ClaudeUsageEntry

    // MARK: Placeholder

    func placeholder(in context: Context) -> ClaudeUsageEntry {
        ClaudeUsageEntry(date: .now, usage: .placeholder)
    }

    // MARK: Snapshot

    func getSnapshot(in context: Context, completion: @escaping (ClaudeUsageEntry) -> Void) {
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    // MARK: Timeline

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeUsageEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            // Refresh every 60 seconds. Spec § Interactions → Refresh.
            let nextRefresh = Date.now.addingTimeInterval(60)
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }

    // MARK: - Entry construction

    private func buildEntry() async -> ClaudeUsageEntry {
        let usageScanner = UsageScanner()
        let agentScanner = AgentScanner()

        async let usageResult = usageScanner.scan()
        async let agentResult = agentScanner.scan()

        let (usage, agents) = await (usageResult, agentResult)

        // Determine copied state freshness (1400ms window)
        let lastCopiedSlug = sharedDefaults.string(forKey: DefaultsKey.lastCopiedSlug)
        let lastCopiedAt   = sharedDefaults.object(forKey: DefaultsKey.lastCopiedAt) as? Date
        let isCopiedFresh  = lastCopiedAt.map { Date.now.timeIntervalSince($0) < 1.4 } ?? false

        var flags = DataStateFlags()
        flags.isLoading          = false
        flags.permissionsDenied  = usage.permissionDenied || agents.permissionDenied
        flags.agentsEmpty        = agents.agents.isEmpty && !agents.permissionDenied

        _ = isCopiedFresh  // copied state is read at view layer via sharedDefaults

        let entry = UsageEntry(
            date: .now,
            lastRefreshedAt: .now,
            model: usage.model,
            session: usage.session,
            weekly: usage.weekly,
            context: usage.context,
            agents: agents.agents,
            sparkline: usage.sparkline,
            dataState: flags
        )

        return ClaudeUsageEntry(date: .now, usage: entry)
    }
}

