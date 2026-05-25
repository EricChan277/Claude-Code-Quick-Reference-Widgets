// UsageScanner.swift
// Reads ~/.claude/projects/**/*.jsonl, tallies token counts within
// the 5-hour session window and 7-day weekly window.
// Also reads ~/.claude/context.json for the context-window IPC.
// Spec § Data sources

import Foundation

// MARK: - UsageScanner

actor UsageScanner {

    // MARK: - Scan entry point

    func scan() async -> (
        session: PeriodUsage,
        weekly: PeriodUsage,
        context: ContextUsage,
        model: String,
        sparkline: [Int],
        permissionDenied: Bool
    ) {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        var entries: [(timestamp: Date, tokens: Int, model: String)] = []
        var permissionDenied = false

        do {
            entries = try await readAllJSONL(in: projectsDir)
        } catch let err as NSError {
            if err.domain == NSCocoaErrorDomain && err.code == NSFileReadNoPermissionError {
                permissionDenied = true
            }
        }

        let now = Date.now
        let sessionCutoff = now.addingTimeInterval(-5 * 3600)
        let weeklyCutoff  = now.addingTimeInterval(-7 * 24 * 3600)

        // Session: messages within the last 5 hours
        let sessionEntries = entries.filter { $0.timestamp >= sessionCutoff }
        // Session resets 5h after the *first* message of the current session
        let sessionStart   = sessionEntries.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let sessionResetAt = sessionStart.map { $0.addingTimeInterval(5 * 3600) } ?? now.addingTimeInterval(5 * 3600)

        // Weekly: messages within the rolling 7-day window
        let weeklyEntries = entries.filter { $0.timestamp >= weeklyCutoff }
        let weeklyStart   = weeklyEntries.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let weeklyResetAt = weeklyStart.map { $0.addingTimeInterval(7 * 24 * 3600) } ?? now.addingTimeInterval(7 * 24 * 3600)

        // Token totals (use output_tokens as the primary usage signal)
        let sessionTokens = sessionEntries.reduce(0) { $0 + $1.tokens }
        let weeklyTokens  = weeklyEntries.reduce(0) { $0 + $1.tokens }

        // Known limits (approximate; the spec doesn't mandate exact caps).
        // 5h session ≈ 88k tokens (based on community observations).
        // 7d weekly: not publicly documented — use 500k as a reasonable cap.
        let sessionLimit = 88_000.0
        let weeklyLimit  = 500_000.0

        let sessionPct = min(Double(sessionTokens) / sessionLimit, 1.0)
        let weeklyPct  = min(Double(weeklyTokens)  / weeklyLimit,  1.0)

        let latestModel = entries.sorted { $0.timestamp > $1.timestamp }.first?.model ?? "Sonnet 4.6"

        let sparkline = buildSparkline(from: entries, now: now)

        let context = await readContext()

        return (
            session: PeriodUsage(
                percent: sessionPct,
                resetAt: sessionResetAt,
                hasData: !sessionEntries.isEmpty
            ),
            weekly: PeriodUsage(
                percent: weeklyPct,
                resetAt: weeklyResetAt,
                hasData: !weeklyEntries.isEmpty
            ),
            context: context,
            model: latestModel,
            sparkline: sparkline,
            permissionDenied: permissionDenied
        )
    }

    // MARK: - JSONL reading

    private func readAllJSONL(
        in dir: URL
    ) async throws -> [(timestamp: Date, tokens: Int, model: String)] {
        var results: [(timestamp: Date, tokens: Int, model: String)] = []
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else { return results }

        let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            let fileEntries = try parseJSONL(at: url)
            results.append(contentsOf: fileEntries)
        }

        return results
    }

    private func parseJSONL(
        at url: URL
    ) throws -> [(timestamp: Date, tokens: Int, model: String)] {
        let raw = try String(contentsOf: url, encoding: .utf8)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter() // without fractional seconds
        iso2.formatOptions = [.withInternetDateTime]

        return raw.components(separatedBy: .newlines).compactMap { line -> (Date, Int, String)? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }

            // Timestamp field
            guard let tsString = obj["timestamp"] as? String,
                  let date = iso.date(from: tsString) ?? iso2.date(from: tsString)
            else { return nil }

            // Tokens: prefer output_tokens, fall back to usage dict
            let tokens: Int
            if let usage = obj["usage"] as? [String: Any],
               let out = usage["output_tokens"] as? Int {
                tokens = out
            } else if let out = obj["output_tokens"] as? Int {
                tokens = out
            } else {
                tokens = 0
            }

            let model = (obj["model"] as? String) ?? "unknown"
            return (date, tokens, model)
        }
    }

    // MARK: - Sparkline (24 hourly buckets)

    private func buildSparkline(
        from entries: [(timestamp: Date, tokens: Int, model: String)],
        now: Date
    ) -> [Int] {
        var buckets = Array(repeating: 0, count: 24)
        let cutoff = now.addingTimeInterval(-24 * 3600)
        for entry in entries where entry.timestamp >= cutoff {
            let hoursAgo = Int(now.timeIntervalSince(entry.timestamp) / 3600)
            let idx = min(max(23 - hoursAgo, 0), 23)
            buckets[idx] += entry.tokens
        }
        // Convert to tokens-per-minute (approximate rate for display)
        return buckets.map { $0 / 60 }
    }

    // MARK: - Context window IPC

    /// Reads ~/.claude/context.json and evaluates staleness (120s threshold).
    /// Spec § Data sources → Context window.
    func readContext() async -> ContextUsage {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/context.json")

        guard let data = try? Data(contentsOf: url),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = obj["schema"] as? Int, schema == 1
        else {
            return .stale
        }

        let usedTokens  = obj["used_tokens"]  as? Int
        let totalTokens = (obj["total_tokens"] as? Int) ?? 200_000

        // Staleness check: written_at > 120s ago → stale
        var isStale = true
        if let writtenAtStr = obj["written_at"] as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            if let writtenAt = iso.date(from: writtenAtStr) ?? iso2.date(from: writtenAtStr) {
                isStale = Date.now.timeIntervalSince(writtenAt) > 120
            }
        }

        return ContextUsage(
            usedTokens: isStale ? nil : usedTokens,
            totalTokens: totalTokens,
            isStale: isStale
        )
    }
}
