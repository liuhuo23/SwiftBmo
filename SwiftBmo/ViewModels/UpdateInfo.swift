// UpdateInfo.swift
// SwiftBmo

import Foundation

/// Model describing a remote update manifest returned by the update endpoint.
public struct UpdateInfo: Decodable, Identifiable, Equatable {
    public let version: String
    public let build: Int
    public let url: URL
    public let releaseNotes: String?
    public let mandatory: Bool
    public let releaseDate: String?

    // Identifiable conformance: unique by version+build
    public var id: String { "\(version)-\(build)" }

    // Compare semantic versions and build numbers. Returns true when `self` represents a newer release
    // than the provided app version/build.
    public func isNewer(thanAppVersion appVersion: String, appBuild: Int) -> Bool {
        // First compare build numbers
        if build > appBuild { return true }
        if build < appBuild { return false }

        // Builds equal: compare semantic version components numerically
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
