import SwiftUI
import AVFoundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct TimerView: View {
    // Use the view model to hold timer/audio logic
    @StateObject private var viewModel = TimerViewModel()

    // Local preset duration (seconds) to mirror the previous `totalTimer` behavior
    @State private var presetDuration: Int = 60

    // Text backing for manual duration input
    @State private var durationText: String = "60"

    // Show completion alert when timer finishes
    @State private var showCompleteAlert: Bool = false

    // Toggle for system notifications
    @State private var notificationsEnabled: Bool = false

    var progress: Double {
        viewModel.progress
    }

    // Common presets the user can tap quickly
    private let presets: [Int] = [30, 60, 120, 300]

    var body: some View{
        VStack(spacing: 18){
            CircularProgressView(progress: progress){
                VStack(alignment: .center){
                    // Status label: placed above the timer with clearer color distinction
                    

                    ZStack {
                        // Soft rounded background card
    #if canImport(UIKit)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(UIColor.systemBackground).opacity(0.06))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    #else
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.06))
                            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    #endif
                        VStack{
                            // Gradient masked text for a modern look
                            Text(int2timer(Int(viewModel.remaining)))
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
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
                                    // keep an empty spacer when idle/finished to avoid layout jumps
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

            // Preset selection row
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

            // Sound + notification toggles row
            HStack(spacing: 12) {
                Toggle(isOn: $viewModel.soundEnabled) {
                    Label("声音", systemImage: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .toggleStyle(.button)

                Toggle(isOn: $notificationsEnabled) {
                    Label("通知", systemImage: notificationsEnabled ? "bell.fill" : "bell.slash")
                }
                .toggleStyle(.button)
                .onChange(of: notificationsEnabled) { _oldVal, newVal in
                    if newVal {
                        requestNotificationPermission()
                    }
                }
            }

            HStack{
                HStack(spacing: 20) {
                    // Start / Pause icon button
                    Button {
                        switch viewModel.state {
                        case .running:
                            viewModel.pause()
                        case .paused:
                            viewModel.resume()
                        default:
                            // idle or finished -> start with presetDuration
                            viewModel.start(duration: TimeInterval(presetDuration))
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
        .padding()
        .onAppear{
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
        .onDisappear{
            viewModel.reset()
        }
        .alert("计时结束", isPresented: $showCompleteAlert, actions: {
            Button("确定") { showCompleteAlert = false }
        }, message: {
            Text("已完成 \(int2timer(presetDuration))")
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

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let err = error {
                print("通知权限请求失败: \(err)")
            }
            if !granted {
                DispatchQueue.main.async {
                    notificationsEnabled = false
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

}

#Preview {
    TimerView().frame(width: 400, height: 600)
}
