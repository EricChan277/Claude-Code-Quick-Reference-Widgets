// AgentScanner.swift
// Reads ~/.claude/agents/*.md, derives category from YAML front-matter
// or falls back to the canonical slug → category mapping.
// Spec § Data sources – "Installed agents list"

import Foundation

// MARK: - AgentScanner

actor AgentScanner {

    // MARK: - Public API

    /// Reads all agent .md files from ~/.claude/agents/ and returns the list.
    /// Returns (agents, permissionDenied).
    func scan() async -> (agents: [AgentInfo], permissionDenied: Bool) {
        let dir = agentsDirectory()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
            return ([], false)
        }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "md" }

            let agents = urls.compactMap { url -> AgentInfo? in
                let slug = url.deletingPathExtension().lastPathComponent
                guard !slug.isEmpty else { return nil }
                let category = categoryFromFile(at: url) ?? AgentCategory.defaultCategory(for: slug)
                return AgentInfo(slug: slug, category: category)
            }.sorted { $0.slug < $1.slug }

            return (agents, false)
        } catch let err as NSError {
            if err.domain == NSCocoaErrorDomain &&
               (err.code == NSFileReadNoPermissionError || err.code == NSFileNoSuchFileError) {
                return ([], err.code == NSFileReadNoPermissionError)
            }
            return ([], false)
        }
    }

    // MARK: - Private helpers

    private func agentsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/agents")
    }

    /// Parses minimal YAML front-matter to extract the `category:` field.
    /// Returns nil if the file has no front-matter or no category field.
    private func categoryFromFile(at url: URL) -> AgentCategory? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        // Front-matter delimited by lines with exactly "---"
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var insideFrontMatter = false
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if i == 0 && trimmed == "---" { insideFrontMatter = true; continue }
            if insideFrontMatter && trimmed == "---" { break }
            guard insideFrontMatter else { continue }

            // Match "category: <value>"
            if trimmed.lowercased().hasPrefix("category:") {
                let value = trimmed
                    .dropFirst("category:".count)
                    .trimmingCharacters(in: .init(charactersIn: " \t\"'"))
                    .uppercased()
                // Try to match by rawValue (case-insensitive)
                return AgentCategory.allCases.first {
                    $0.rawValue.uppercased() == value || $0.shortLabel.uppercased() == value
                }
            }
        }
        return nil
    }
}
