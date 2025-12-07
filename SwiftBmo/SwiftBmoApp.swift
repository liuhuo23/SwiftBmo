//
//  SwiftBmoApp.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Defer a bit to allow SwiftUI WindowGroup to create the window
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.applyWindowSettings()

            // After a short delay, if no suitable windows were created at all, quit the app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.noVisibleWindowsRemain() {
                    NSApp.terminate(nil)
                }
            }
        }

        // Listen for windows closing so we can automatically quit when there are none left
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // Do the check asynchronously because during the willClose notification the window
        // may still be present in NSApp.windows. Scheduling on the main queue allows the
        // window list to update first.
        DispatchQueue.main.async {
            if self.noVisibleWindowsRemain() {
                NSApp.terminate(nil)
            }
        }
    }

    /// Return true when there are no user-visible windows remaining.
    /// We filter out windows that are not visible, are miniaturized, or are excluded from the
    /// Window menu (panels, helper windows) so the app doesn't quit while utility panels
    /// remain or during transient UI.
    private func noVisibleWindowsRemain() -> Bool {
        let openWindows = NSApp.windows.filter { window in
            return window.isVisible && !window.isMiniaturized && !window.isExcludedFromWindowsMenu
        }
        return openWindows.isEmpty
    }

    private func applyWindowSettings() {
        // Use the first window (main application window). If you have multiple windows,
        // adjust to target the specific one you want.
        guard let window = NSApp.windows.first else { return }

        // --- Window style ---
        // Ensure typical window controls are present and make title bar appear transparent if desired
        window.title = "SwiftBmo"
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true

        // --- Size and position ---
        // Customize width/height here
        let width: CGFloat = 600
        let height: CGFloat = 400

        if let screen = NSScreen.main {
            // Position: center of the main visible screen by default
            let screenFrame = screen.visibleFrame
            let x = screenFrame.origin.x + (screenFrame.size.width - width) / 2
            let y = screenFrame.origin.y + (screenFrame.size.height - height) / 2
            let frame = NSRect(x: x, y: y, width: width, height: height)
            window.setFrame(frame, display: true, animate: true)
        } else {
            // Fallback: set a frame with a reasonable origin
            let frame = NSRect(x: 100, y: 100, width: width, height: height)
            window.setFrame(frame, display: true, animate: true)
        }

        // Optionally: disable resizing if you want a fixed-size window
        // window.styleMask.remove(.resizable)
    }
}
#endif

@main
struct SwiftBmoApp: App {
    let persistenceController = PersistenceController.shared

    #if os(macOS)
    // Wire up the macOS AppDelegate so we can customize the NSWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
