// UsageScanner.swift
// Reads ~/.claude/usage.txt — a KEY=VALUE snapshot written by the Claude Code
// statusline script on every tick. Pre-computed percentages are used directly;
// no local token tallying is performed.
// Also reads ~/.claude/context.json for the context-window IPC (fallback when
// usage.txt does not supply CONTEXT_USED/CONTEXT_TOTAL).
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
        let usageTxtURL = Paths.realHome
            .appendingPathComponent(".claude/usage.txt")

        // Parse usage.txt into a [String: String] dictionary.
        let kv = parseKeyValue(at: usageTxtURL)

        // Determine freshness: if the file is missing or older than 5 minutes,
        // treat all rate-limit fields as absent.
        let fileAge: TimeInterval
        if let epoch = kv["UPDATED_EPOCH"].flatMap({ Double($0) }) {
            fileAge = Date.now.timeIntervalSince1970 - epoch
        } else if let attrs = try? FileManager.default.attributesOfItem(atPath: usageTxtURL.path),
                  let mod = attrs[.modificationDate] as? Date {
            fileAge = Date.now.timeIntervalSince(mod)
        } else {
            fileAge = .greatestFiniteMagnitude   // file absent → stale
        }

        let isStale = fileAge > 300   // 5-minute threshold

        // Model: use value directly — statusline already emits a friendly name.
        let model: String = kv["MODEL"] ?? "Claude"

        // Session percentage (FIVEH_PCT: 0-100 from Claude Code).
        let sessionPct: Double?
        let sessionHasData: Bool
        if !isStale, let raw = kv["FIVEH_PCT"], let parsed = Double(raw) {
            sessionPct = min(max(parsed / 100.0, 0.0), 1.0)
            sessionHasData = true
        } else {
            sessionPct = nil
            sessionHasData = false
        }

        // Weekly percentage (WEEK_ALL_PCT: 0-100 from Claude Code).
        let weeklyPct: Double?
        let weeklyHasData: Bool
        if !isStale, let raw = kv["WEEK_ALL_PCT"], let parsed = Double(raw) {
            weeklyPct = min(max(parsed / 100.0, 0.0), 1.0)
            weeklyHasData = true
        } else {
            weeklyPct = nil
            weeklyHasData = false
        }

        // Context: prefer usage.txt fields; fall back to context.json.
        let context: ContextUsage
        if !isStale,
           let usedStr  = kv["CONTEXT_USED"],
           let totalStr = kv["CONTEXT_TOTAL"],
           let used     = Int(usedStr),
           let total    = Int(totalStr) {
            context = ContextUsage(usedTokens: used, totalTokens: total, isStale: false)
        } else {
            context = await readContext()
        }

        // lastRefreshedAt from UPDATED_EPOCH (used by the header "updated N ago" label).
        // The scanner return tuple doesn't include lastRefreshedAt directly; TimelineProvider
        // sets UsageEntry.lastRefreshedAt from Date.now after the scan, which is fine.

        return (
            session: PeriodUsage(
                percent: sessionPct ?? 0,
                resetAt: nil,
                hasData: sessionHasData
            ),
            weekly: PeriodUsage(
                percent: weeklyPct ?? 0,
                resetAt: nil,
                hasData: weeklyHasData
            ),
            context: context,
            model: model,
            sparkline: Array(repeating: 0, count: 24),
            permissionDenied: false
        )
    }

    // MARK: - usage.txt parser

    /// Reads a KEY=VALUE text file and returns a dictionary.
    /// Splits only on the first `=` so values may contain `=`.
    private func parseKeyValue(at url: URL) -> [String: String] {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let eqRange = trimmed.range(of: "=") else { continue }
            let key   = String(trimmed[..<eqRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[eqRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    // MARK: - Context window IPC

    /// Reads ~/.claude/context.json and evaluates staleness (24h threshold).
    /// context.json is only written during an active conversation, so outside
    /// of one it is always "stale" — we still return the last known values and
    /// mark isStale=true so views can dim rather than blank them.
    /// Spec § Data sources → Context window.
    func readContext() async -> ContextUsage {
        let url = Paths.realHome
            .appendingPathComponent(".claude/context.json")

        guard let data = try? Data(contentsOf: url),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = obj["schema"] as? Int, schema == 1
        else {
            return .stale
        }

        let usedTokens  = obj["used_tokens"]  as? Int
        let totalTokens = (obj["total_tokens"] as? Int) ?? 200_000

        // Staleness check: written_at > 24h ago → stale.
        // context.json is only written during an active conversation; outside
        // of one, the file is always old. We still surface the last-known token
        // values with isStale=true so views can dim them rather than show "—".
        var isStale = true
        if let writtenAtStr = obj["written_at"] as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            if let writtenAt = iso.date(from: writtenAtStr) ?? iso2.date(from: writtenAtStr) {
                isStale = Date.now.timeIntervalSince(writtenAt) > 86_400
            }
        }

        // Always return the last-known token values regardless of staleness.
        // Callers use isStale to dim the display; nil usedTokens means no data
        // ever, not that the file is old.
        return ContextUsage(
            usedTokens: usedTokens,
            totalTokens: totalTokens,
            isStale: isStale
        )
    }
}
