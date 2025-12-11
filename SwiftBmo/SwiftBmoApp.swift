//xi
//  SwiftBmoApp.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI
import CoreData
import Combine

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var updateWindow: NSWindow?
    private var updateWindowCancellable: AnyCancellable?

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
        updateWindowCancellable?.cancel()
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
        for window in NSApp.windows {
            if window.title == "SwiftBmo" || window.title == "mainWindow" {
                // --- Window style ---
                // Ensure typical window controls are present and make title bar appear transparent if desired
                window.title = "SwiftBmo"
                window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
                window.titleVisibility = .visible
                window.titlebarAppearsTransparent = false
                window.isMovableByWindowBackground = true

                // --- Size and position ---
                // Customize width/height here
                let width: CGFloat = 400
                let height: CGFloat = 620

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
            } else if window.title == "about" {
                // Disable maximize and minimize
                window.styleMask = [.titled, .closable]
                window.titleVisibility = .visible
                window.titlebarAppearsTransparent = false
                window.isMovableByWindowBackground = true

                // Size for about window
                let width: CGFloat = 300
                let height: CGFloat = 400

                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let x = screenFrame.origin.x + (screenFrame.size.width - width) / 2
                    let y = screenFrame.origin.y + (screenFrame.size.height - height) / 2
                    let frame = NSRect(x: x, y: y, width: width, height: height)
                    window.setFrame(frame, display: true, animate: true)
                }
            }
        }
    }

}
#endif

@main
struct SwiftBmoApp: App {
    @Environment(\.openWindow) private var openWindow
    let persistenceController = PersistenceController.shared

    #if os(macOS)
    // Wire up the macOS AppDelegate so we can customize the NSWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        // Trigger a background update check on app launch
        Task { @MainActor in
            UpdateManager.shared.checkForUpdate(manual: false)
        }
    }

    var body: some Scene {
        WindowGroup("mainWindow", id: "main"){
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .defaultSize(CGSize(width: 400, height: 600))
        .defaultPosition(.center)       // Add an app menu command for checking updates
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(action: {
                    UpdateManager.shared.presentUpdateUI()
                    openWindow(id: "updateWindow")
                }) {
                    Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
            CommandGroup(before: .appInfo){
                Button(action:{
                    openWindow(id: "about")
                }){
                    Label("关于 SwiftBmo", systemImage: "info.circle")
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button(action:{
                    openWindow(id: "settings")
                }){
                    Label("设置", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
                
        }
        
        WindowGroup("更新", id: "updateWindow") {
            UpdateView(manager: UpdateManager.shared)
                .windowResizeBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
        }
        .defaultSize(width: 500, height: 600)
        .defaultPosition(.center)
        
        WindowGroup("关于", id: "about"){
            AboutView()
                .windowResizeBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
        }
        .defaultSize(width: 400, height: 250)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        
        WindowGroup("设置", id: "settings") {
            SettingView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .windowResizeBehavior(.disabled)
                .windowMinimizeBehavior(.disabled)
        }
        .defaultSize(width: 600, height: 300)
        .defaultPosition(.center)
        
//        Settings {
//            SettingView()
//        }
    }
}
