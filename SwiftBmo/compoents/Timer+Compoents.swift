import SwiftUI
import AVFoundation
import UserNotifications
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct TimerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openWindow) private var openWindow
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subject.name, ascending: true)],
        animation: .default)
    private var subjects: FetchedResults<Subject>
    
    // Use the view model to hold timer/audio logic
    @StateObject private var viewModel = TimerViewModel(context: PersistenceController.shared.container.viewContext)
    
    // Local preset duration (seconds) to mirror the previous `totalTimer` behavior
    @State private var presetDuration: Int = 60

    // Text backing for manual duration input
    @State private var durationText: String = "60"

    // Show completion alert when timer finishes
    @State private var showCompleteAlert: Bool = false

    // Toggle for system notifications
    @State private var notificationsEnabled: Bool = false

    // Show notification permission error alert
    @State private var showNotificationErrorAlert: Bool = false

    // Sheet for adding a new subject
    @State private var showingAddSubjectSheet: Bool = false
    @State private var newSubjectName: String = ""
    @State private var showSelectSubject:Bool = false
    // Focus state for the new subject text field — used so the Character Viewer inserts into the field
    @FocusState private var newSubjectNameFocused: Bool

    var progress: Double {
        viewModel.progress
    }

    // Common presets the user can tap quickly
    @StateObject private var appInfo = AppInfo.shared
    private var presets: [Int] { appInfo.presets }

    var body: some View {
        VStack(spacing: 10){
            HStack(spacing: 8) {
                Picker("选择主题", selection: $viewModel.selectSubject) {
                    ForEach(subjects, id: \.self) { theme in
                        Text(theme.name ?? "默认主题").tag(theme as Subject?)
                    }
                }
            }
            CircularProgressView(progress: progress){
                centerCard
            }
            // Manual duration input (seconds) with a small stepper
            HStack(spacing: 8) {
                Text("自定义秒数:")
                    .font(.subheadline)
                TextField("秒数", text: $durationText, onCommit: applyDurationText)
                    .frame(width: 80)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.trailing)
                Stepper(value: Binding(get: { presetDuration }, set: { newVal in
                    presetDuration = newVal
                    durationText = "\(newVal)"
                    // Update display immediately
                    viewModel.reset()
                    viewModel.start(duration: TimeInterval(newVal))
                    viewModel.pause()
                }), in: 1...36000, step: 1) {
                    EmptyView()
                }
                .labelsHidden()
            }
            
            HStack{
                HStack(spacing: 20) {
                    // Start / Pause icon button
                    Button {
                        switch viewModel.state {
                        case .running:
                            viewModel.pause()
                        case .paused:
                            resume()
                        default:
                            start()
                            
                        }
                    } label: {
                        Image(systemName: viewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 52, height: 52)
                            .foregroundColor(.white)
                            .background(Circle().fill(viewModel.state == .running ? Color.orange : Color.green))
                    }
                    .accessibilityLabel(viewModel.state == .running ? "暂停" : "开始")
                    .buttonStyle(PlainButtonStyle())
                    // 秒数
                    // Preset selection row
                    // Preset selection row — horizontally scrollable for many presets
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 12) {
                            ForEach(presets, id: \.self) { val in
                                Button {
                                    presetDuration = val
                                    durationText = "\(val)"
                                    // Show the selected preset immediately in UI by starting then pausing
                                    viewModel.reset()
                                    viewModel.start(duration: TimeInterval(val))
                                    viewModel.pause()
                                } label: {
                                    Text("\(val)s")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(presetDuration == val ? Color.accentColor : Color.gray.opacity(0.16)))
                                        .foregroundColor(presetDuration == val ? Color.white : Color.primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    // Reset icon button
                    Button {
                        // Reset to preset: stop timer and set remaining to preset by starting then pausing
                        viewModel.reset()
                        // Start then pause to set remaining to presetDuration without running
                        viewModel.start(duration: TimeInterval(presetDuration))
                        viewModel.pause()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.blue))
                    }
                    .accessibilityLabel("重置")
                    .buttonStyle(PlainButtonStyle())
                }
             }
        }
        .toolbar(){
            ToolbarItem(placement: .automatic){
                Button {
                    openWindow(id: "chart")
                } label: {
                    Label("统计", systemImage: "chart.bar.fill")
                }
            }
            // Replace the Picker with a Menu so toolbar shows a compact, reliable selection UI.
            ToolbarItem(placement: .automatic){
                Menu {
                    if subjects.isEmpty {
                        Button("添加主题") {
                            // Open sheet to allow user to enter a name for the new subject
                            newSubjectName = ""
                            showingAddSubjectSheet = true
                        }
                    } else {
                        ForEach(subjects, id: \.self) { theme in
                            Button {
                                viewModel.selectSubject = theme
                            } label: {
                                HStack {
                                    Text(theme.name ?? "Unknown")
                                    Spacer()
                                    if viewModel.selectSubject?.objectID == theme.objectID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("添加主题") {
                            newSubjectName = ""
                            showingAddSubjectSheet = true
                        }
                    }
                } label: {
                    Label(viewModel.selectSubject?.name ?? "选择主题", systemImage: "tag")
                }
            }

            ToolbarItemGroup(placement: .automatic){
                Toggle(isOn: $viewModel.soundEnabled) {
                    Label("声音", systemImage: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .toggleStyle(.button)
                
                Toggle(isOn: $notificationsEnabled) {
                    Label("通知", systemImage: notificationsEnabled ? "bell.fill" : "bell.slash")
                }
                .toggleStyle(.button)
                .onChange(of: notificationsEnabled) { newVal, _ in
                    if newVal {
                        requestNotificationPermission()
                    }
                }
            }
        }
        .padding()
        // Sheet for entering a new subject name
        .sheet(isPresented: $showingAddSubjectSheet) {
            VStack(spacing: 16) {
                Text("添加主题")
                    .font(.headline)
                // Arrange the text field and an emoji/character picker button on the same row.
                HStack(spacing: 8) {
                    TextField("主题名称", text: $newSubjectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .focused($newSubjectNameFocused)

                    // macOS: open the Character Viewer so users can insert emoji/symbols directly into the text field.
                    #if canImport(AppKit)
                    Button {
                        openCharacterPalette()
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("打开表情和符号面板")
                    #endif
                }

                HStack {
                    Button("取消") {
                        showingAddSubjectSheet = false
                        newSubjectName = ""
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("保存") {
                        let name = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        let newSubject = Subject(name: name, context: viewContext)
                        do {
                            try viewContext.save()
                            viewModel.selectSubject = newSubject
                        } catch {
                            print("Failed to create subject: \(error)")
                        }
                        showingAddSubjectSheet = false
                        newSubjectName = ""
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(minWidth: 300)
        }
        
        // Helper to present the system character/emoji picker. On macOS this calls AppKit's API.
        .onChange(of: showingAddSubjectSheet) { showing,_ in
            // When sheet appears, focus the text field so emoji insertion lands there immediately.
            if showing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    newSubjectNameFocused = true
                }
            }
        }
        .onAppear{
            viewModel.setContext(viewContext)

            // If no subject is selected yet, default to the first available subject
            if viewModel.selectSubject == nil, let first = subjects.first {
                viewModel.selectSubject = first
            }

            // Allow the view to present an alert when the timer completes
            viewModel.onComplete = {
                // Present the alert on the main actor
                Task { @MainActor in
                    showCompleteAlert = true
                }
                
                // Post a user notification if enabled
                if notificationsEnabled {
                    postNotification()
                }
            }

            // Initialize display to presetDuration
            durationText = "\(presetDuration)"
            viewModel.reset()
            viewModel.start(duration: TimeInterval(presetDuration))
            viewModel.pause()
        }
        // If subjects list changes (new subject added), ensure a default selection exists
        .onChange(of: subjects.count) { _, _ in
            if viewModel.selectSubject == nil, let first = subjects.first {
                viewModel.selectSubject = first
            }
        }
        .onDisappear{
            viewModel.reset()
        }
        .alert("计时结束", isPresented: $showCompleteAlert, actions: {
            Button("确定") { showCompleteAlert = false }
        }, message: {
            Text("已完成 \(int2timer(presetDuration))")
        })
        .alert("警告", isPresented: $showSelectSubject, actions: {
            Button("确定") { showSelectSubject = false }
        }, message: {
            Text("主题未选择")
        })
        .alert("通知权限被拒绝", isPresented: $showNotificationErrorAlert, actions: {
            Button("确定") { showNotificationErrorAlert = false }
        }, message: {
#if canImport(UIKit)
            Text("请在设置 > 通知中启用通知权限，以便应用可以发送通知。")
#else
            Text("请在系统偏好设置 > 通知中启用通知权限，以便应用可以发送通知。")
#endif
        })
    }

    // Apply and validate the durationText, syncing to presetDuration and updating the viewModel display.
    private func applyDurationText() {
        if let v = Int(durationText), v > 0 {
            presetDuration = v
            // Update the viewModel display without starting the timer
            viewModel.reset()
            viewModel.start(duration: TimeInterval(v))
            viewModel.pause()
        } else {
            // Revert invalid input
            durationText = "\(presetDuration)"
        }
    }
    
    private func resume(){
        guard let _ = viewModel.selectSubject else {
            showSelectSubject = true
            return
        }
        viewModel.resume()
    }
    
    private func start(){
        // idle or finished -> start with presetDuration
        guard let _ = viewModel.selectSubject else {
            showSelectSubject = true
            return
        }
        viewModel.start(duration: TimeInterval(presetDuration))
    }
    // macOS-only: open the system Character/Emoji viewer and ensure the subject text field is first responder
    private func openCharacterPalette() {
        #if canImport(AppKit)
        // Focus the text field first so the character viewer inserts into it
        newSubjectNameFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.orderFrontCharacterPalette(nil)
        }
        #endif
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let err = error {
                    print("通知权限请求失败: \(err)")
                    notificationsEnabled = false
                    showNotificationErrorAlert = true
                } else if !granted {
                    notificationsEnabled = false
                    showNotificationErrorAlert = true
                }
            }
        }
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "计时完成"
        content.body = "计时 \(int2timer(presetDuration)) 已完成。"
        content.sound = UNNotificationSound.default

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let err = error {
                print("通知发布失败: \(err)")
            }
        }
    }

    // Convert seconds into HH:mm:ss using the provided seconds parameter.
    func int2timer(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    // Extracted center card to reduce complexity in the main body for the compiler.
    private var centerCard: some View {
        VStack(alignment: .center) {
            ZStack {
    #if canImport(UIKit)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.systemBackground).opacity(0.06))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    #else
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.06))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    #endif
                VStack(spacing: 8){
                    Text(int2timer(Int(viewModel.remaining)))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [Color.green, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text(int2timer(Int(viewModel.remaining)))
                                        .font(.system(size: 44, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                )
                        )
                        .animation(.easeInOut(duration: 0.18), value: viewModel.remaining)

                    Group {
                        if viewModel.state == .running {
                            Text("专注中")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else if viewModel.state == .paused {
                            Text("休息中")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Text("")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .animation(.easeInOut, value: viewModel.state)
                }
            }
        }
    }
}

#Preview {
    TimerView().frame(width: 600, height: 600)
}
