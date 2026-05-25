// Paths.swift
// Real home-directory resolution that works inside a sandboxed app extension.
// FileManager.default.homeDirectoryForCurrentUser returns the sandbox container
// path inside an extension; getpwuid() always returns the real home directory.

import Darwin
import Foundation

// MARK: - Paths

enum Paths {
    /// The real home directory for the current user, bypassing sandbox container
    /// redirection. Falls back to FileManager if getpwuid fails.
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let cstr = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: cstr))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
