import Foundation
import Combine
import SwiftUI

@MainActor
final class AppInfo: ObservableObject {
    static let shared = AppInfo()

    // Use AppStorage to persist the presets as a comma-separated string.
    @AppStorage("AppInfo.customPresets") private var presetsString: String = ""

    @Published var presets: [Int]

    // Keep observer token so we can remove it if needed
    private var defaultsObserver: NSObjectProtocol?

    private init() {
        // Initialize presets to satisfy property initialization rules before accessing other properties
        self.presets = []

        // Load from UserDefaults directly to avoid referencing @AppStorage wrapper before init completes
        let raw = UserDefaults.standard.string(forKey: "AppInfo.customPresets") ?? presetsString
        if !raw.isEmpty {
            let values = raw.split(separator: ",").compactMap { Int($0) }
            if !values.isEmpty {
                self.presets = values
            } else {
                self.presets = [30, 60, 120, 300]
                save()
            }
        } else {
            self.presets = [30, 60, 120, 300]
            save()
        }

        // Observe UserDefaults changes and update `presets` when the key changes elsewhere.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            // Read the latest value directly from UserDefaults to avoid referencing @AppStorage in a Sendable closure
            let str = UserDefaults.standard.string(forKey: "AppInfo.customPresets") ?? ""
            let values = str.isEmpty ? [] : str.split(separator: ",").compactMap { Int($0) }
            // Update on main actor to safely access actor-isolated properties
            Task { @MainActor in
                if values != self.presets {
                    self.presets = values
                }
            }
        }
    }

    deinit {
        if let obs = defaultsObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func addPreset(_ seconds: Int) {
        guard seconds > 0 else { return }
        if !presets.contains(seconds) {
            presets.append(seconds)
            presets.sort()
            save()
        }
    }

    func removePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save()
    }

    func removePreset(_ seconds: Int) {
        if let idx = presets.firstIndex(of: seconds) {
            presets.remove(at: idx)
            save()
        }
    }

    private func save() {
        // Persist as comma-separated string for simple storage via AppStorage
        presetsString = presets.map(String.init).joined(separator: ",")
    }
}
