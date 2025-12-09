// UpdateInfo.swift
// SwiftBmo

import Foundation

/// Model describing a remote update manifest returned by the update endpoint.
public struct UpdateInfo: Decodable, Identifiable, Equatable {
    public let version: String
    public let url: URL
    public let releaseNotes: String?
    public let mandatory: Bool
    public let releaseDate: String?

    // Identifiable conformance: unique by version
    public var id: String { version }

    // Compare semantic versions. Returns true when `self` represents a newer release
    // than the provided app version.
    public func isNewer(thanAppVersion appVersion: String) -> Bool {
        // Compare semantic version components numerically
        let lhs = version.split(separator: ".").compactMap { Int($0) }
        let rhs = appVersion.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(lhs.count, rhs.count)

        for i in 0..<maxLen {
            let a = i < lhs.count ? lhs[i] : 0
            let b = i < rhs.count ? rhs[i] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }
}
