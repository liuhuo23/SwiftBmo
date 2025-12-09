// UpdateManager.swift
// SwiftBmo

import Foundation
import Combine
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class UpdateManager: ObservableObject {
    // Shared singleton for app-level checks
    public static let shared = UpdateManager()

    enum State: Equatable {
        case idle
        case checking
        case available(UpdateInfo)
        case upToDate
        case error(String)
    }

    @Published private(set) var state: State = .idle

    // Whether the last initiated check was manual. UI can observe to decide whether to show upToDate/error alerts.
    @Published var lastCheckWasManual: Bool = false

    // Whether to show the update sheet/modal (UI layer may bind to this)
    @Published var isShowingUpdateSheet: Bool = false


    // Download state
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double? = nil
    @Published var downloadedFileURL: URL? = nil
    @Published var downloadError: String? = nil

    // Configurable via Info.plist key `UPDATE_CHECK_URL` (string)
    private let checkURL: URL?

    // Persistence keys
    private let userDefaults = UserDefaults.standard
    private let kLastCheckKey = "update_last_check"
    private let kETagKey = "update_etag"
    private let kIgnoredVersionKey = "update_ignored_version"
    private let kNextRemindKey = "update_next_remind"

    // Rate limiting: default 24h
    private let minInterval: TimeInterval = 60 * 60 * 24

    private var task: Task<Void, Never>?

    init() {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "UPDATE_CHECK_URL") as? String,
           let url = URL(string: urlString) {
            self.checkURL = url
        } else {
            self.checkURL = nil
        }
    }

    deinit {
        task?.cancel()
        // macOS-specific observers/windows removed - nothing else to cleanup here
    }

    /// Public API: check for updates. `manual` bypasses rate limiting.
    func checkForUpdate(manual: Bool = false) {
        // If no url configured, do nothing
        guard let url = checkURL else { return }

        // mark whether caller requested manual check so UI can show results for up-to-date/errors
        lastCheckWasManual = manual

        // When a manual check is requested and UI sheet isn't already visible, we don't automatically present the sheet here; calling code (app menu) should present the sheet first.

        // Respect remind scheduling
        if !manual {
            if let next = userDefaults.object(forKey: kNextRemindKey) as? Date {
                if Date() < next { return }
            }
            if let last = userDefaults.object(forKey: kLastCheckKey) as? Date {
                if Date().timeIntervalSince(last) < minInterval { return }
            }
        }

        state = .checking

        task?.cancel()
        task = Task { [weak self] in
            await self?.performRequest(url: url, manual: manual)
        }
    }

    /// Cancel an in-flight check-for-update operation.
    func cancelCheck() {
        task?.cancel()
        task = nil
        // reflect cancelation in UI
        state = .idle
        // if user had requested manual check, clear that flag so UI doesn't show manual-only alerts
        lastCheckWasManual = false
    }

    /// Present the update UI (sheet) and start a manual check.
    /// NOTE: UpdateManager no longer creates a dedicated NSWindow. The UI layer should present the sheet/window and observe `isShowingUpdateSheet`.
    func presentUpdateUI() {
        lastCheckWasManual = true
        downloadedFileURL = nil
        downloadError = nil
        isShowingUpdateSheet = true
        checkForUpdate(manual: true)
    }

    /// Close the update UI (dismiss sheet) — does not manipulate windows directly.
    func closeUpdateWindow() {
        isShowingUpdateSheet = false
    }

    /// Download the update payload and attempt to open it so the user can install it.
    /// This method downloads the remote file to the user's Downloads directory (macOS) or opens the URL (App Store / iOS).
    func downloadAndInstall(_ info: UpdateInfo) {
        // Reset previous download state
        downloadedFileURL = nil
        downloadError = nil
        downloadProgress = nil
        isDownloading = true

        // If the URL is an App Store link, just open it externally
        if isAppStoreLink(info.url) {
            isDownloading = false
            openURL(info.url)
            return
        }

        Task {
            do {
                // Use async download API (returns a local temporary URL)
                let (tempURL, _) = try await URLSession.shared.download(from: info.url)

                // Move to Caches directory if available (macOS), otherwise keep temp
                let fm = FileManager.default
                var destination = tempURL
                #if os(macOS)
                if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    destination = caches.appendingPathComponent(info.url.lastPathComponent)
                    // Remove existing file if present
                    if fm.fileExists(atPath: destination.path) {
                        try? fm.removeItem(at: destination)
                    }
                    try fm.moveItem(at: tempURL, to: destination)
                }
                #endif

                downloadedFileURL = destination
                isDownloading = false

                // For macOS, if it's a DMG, auto-install; otherwise, open the file
                #if os(macOS)
                if destination.pathExtension.lowercased() == "dmg" {
                    do {
                        let mountPoint = try mountDMG(at: destination)
                        let appURL = try findAppInVolume(at: mountPoint)
                        try installApp(from: appURL)
                        try unmountDMG(at: mountPoint)
                        // Launch the new app and terminate the current one
                        let installedAppURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(appURL.lastPathComponent)
                        NSWorkspace.shared.open(installedAppURL)
                        NSApp.terminate(nil)
                    } catch {
                        // Fallback: open the DMG manually if auto-install fails
                        NSWorkspace.shared.open(destination)
                    }
                } else {
                    NSWorkspace.shared.open(destination)
                }
                #elseif os(iOS)
                DispatchQueue.main.async {
                    UIApplication.shared.open(info.url)
                }
                #endif
            } catch {
                isDownloading = false
                downloadError = error.localizedDescription
            }
        }
    }

    private func isAppStoreLink(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("apps.apple.com") || host.contains("itunes.apple.com")
    }

    private func performRequest(url: URL, manual: Bool) async {
        var request = URLRequest(url: url)
        // Attach ETag if we have one
        if let etag = userDefaults.string(forKey: kETagKey) {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        // Optionally include current app version/build for server analytics (non-identifying)
        if let info = Bundle.main.infoDictionary,
           let appVer = info["CFBundleShortVersionString"] as? String,
           let appBuildStr = info["CFBundleVersion"] as? String {
            request.addValue(appVer, forHTTPHeaderField: "X-App-Version")
            request.addValue(appBuildStr, forHTTPHeaderField: "X-App-Build")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Save last check timestamp
            userDefaults.set(Date(), forKey: kLastCheckKey)

            // ETag handling
            if let http = response as? HTTPURLResponse,
               let newETag = http.value(forHTTPHeaderField: "ETag") {
                userDefaults.set(newETag, forKey: kETagKey)
            }

            // If status code is 304 Not Modified
            if let http = response as? HTTPURLResponse, http.statusCode == 304 {
                state = .upToDate
                return
            }

            // Parse JSON
            let decoder = JSONDecoder()

            // Try decoding our own UpdateInfo manifest
            if let info = try? decoder.decode(UpdateInfo.self, from: data) {
                // Determine app version/build
                let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                let appBuildStr = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
                let appBuild = Int(appBuildStr) ?? 0

                // Respect ignored version
                if let ignored = userDefaults.string(forKey: kIgnoredVersionKey), ignored == info.id {
                    state = .upToDate
                    return
                }

                if info.isNewer(thanAppVersion: appVersion, appBuild: appBuild) {
                    state = .available(info)
                } else {
                    state = .upToDate
                }
                return
            }

            // If decoding our format failed, attempt GitHub Releases API (releases/latest or a specific release JSON)
            // Support both a single release object and an array (some endpoints return array)
            struct GHAsset: Decodable {
                let name: String?
                let browser_download_url: URL
                let content_type: String?
            }
            struct GHRelease: Decodable {
                let tag_name: String
                let body: String?
                let published_at: String?
                let assets: [GHAsset]
                let html_url: URL?
            }

            var ghRelease: GHRelease?
            // Try single object
            if let single = try? decoder.decode(GHRelease.self, from: data) {
                ghRelease = single
            } else if let arr = try? decoder.decode([GHRelease].self, from: data), let first = arr.first {
                ghRelease = first
            }

            if let gh = ghRelease {
                // Normalize version (strip leading v)
                var version = gh.tag_name
                if version.hasPrefix("v") || version.hasPrefix("V") {
                    version.removeFirst()
                }

                // Infer build number from published_at timestamp if available
                var build = 0
                if let pub = gh.published_at, let date = ISO8601DateFormatter().date(from: pub) {
                    build = Int(date.timeIntervalSince1970)
                }

                // Choose the most appropriate asset for the current platform by extension
                func selectAssetURL(from assets: [GHAsset], preferredExtensions: [String]) -> URL? {
                    for ext in preferredExtensions {
                        for asset in assets {
                            let name = (asset.name ?? asset.browser_download_url.lastPathComponent).lowercased()
                            let urlPath = asset.browser_download_url.absoluteString.lowercased()
                            let dotExt = ext.hasPrefix(".") ? ext : ".\(ext)"
                            if name.hasSuffix(dotExt) || urlPath.hasSuffix(dotExt) {
                                return asset.browser_download_url
                            }
                        }
                    }
                    return nil
                }

                #if os(macOS)
                let preferred = ["dmg", "pkg", "tar.gz", "zip"]
                #else
                let preferred = ["zip", "tar.gz"]
                #endif

                let assetURL = selectAssetURL(from: gh.assets, preferredExtensions: preferred) ?? gh.assets.first?.browser_download_url ?? gh.html_url ?? url

                let mapped = UpdateInfo(version: version,
                                         build: build,
                                         url: assetURL,
                                         releaseNotes: gh.body,
                                         mandatory: false,
                                         releaseDate: gh.published_at)

                let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                let appBuildStr = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
                let appBuild = Int(appBuildStr) ?? 0

                if let ignored = userDefaults.string(forKey: kIgnoredVersionKey), ignored == mapped.id {
                    state = .upToDate
                    return
                }

                if mapped.isNewer(thanAppVersion: appVersion, appBuild: appBuild) {
                    state = .available(mapped)
                } else {
                    state = .upToDate
                }
                return
            }

            // If we reach here, we couldn't decode a supported format
            state = .error("Invalid update manifest format")

        } catch {
            // Network or parsing error
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Actions invoked from UI
    func ignoreVersion(_ info: UpdateInfo) {
        userDefaults.set(info.id, forKey: kIgnoredVersionKey)
        state = .upToDate
    }

    func remindLater(after interval: TimeInterval = 60 * 60 * 4) {
        // Default remind after 4 hours
        userDefaults.set(Date().addingTimeInterval(interval), forKey: kNextRemindKey)
        state = .upToDate
    }

    func openURL(_ url: URL) {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    // MARK: - DMG Handling (macOS only)
    private func mountDMG(at url: URL) throws -> URL {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["attach", url.path, "-readonly", "-plist"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw NSError(domain: "HDIUtilError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to mount DMG"])
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]]

        if let mountPoints = plist?.first?["mount-point"] as? [String], let mount = mountPoints.first {
            return URL(fileURLWithPath: mount)
        }

        throw NSError(domain: "MountError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to determine mount point"])
    }

    private func unmountDMG(at url: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", url.path, "-quiet"]

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw NSError(domain: "HDIUtilError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to unmount DMG"])
        }
    }

    private func findAppInVolume(at volumeURL: URL) throws -> URL {
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: volumeURL, includingPropertiesForKeys: nil) else {
            throw NSError(domain: "UpdateManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate volume"])
        }

        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                return url
            }
        }

        throw NSError(domain: "UpdateManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No application bundle found in DMG"])
    }

    private func installApp(from url: URL) throws {
        let fileManager = FileManager.default

        // Copy the app to the Applications folder
        let applicationsDirectory = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first!
        let destinationURL = applicationsDirectory.appendingPathComponent(url.lastPathComponent)

        // Replace existing app if necessary
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: url, to: destinationURL)
    }
}
