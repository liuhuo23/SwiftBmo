//
//  Timer+Compoents.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct TimerView: View {
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var totalTimer = 60; // 秒数
    @State private var currentTimer = 0; // 当前秒数
    @State private var audioPlayer: AVAudioPlayer?
    var progress: Double {
        if totalTimer == 0 {
            return 0.0
        }
        return Double(totalTimer - currentTimer) / Double(totalTimer)
    }
    var body: some View{
        VStack{
            CircularProgressView(progress: progress){
                // Modern timer label: gradient, monospaced digits, rounded background
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

                    // Gradient masked text for a modern look
                    Text(int2timer(currentTimer))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [Color.green, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                .mask(
                                    Text(int2timer(currentTimer))
                                        .font(.system(size: 44, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                )
                        )
                        .animation(.easeInOut(duration: 0.18), value: currentTimer)
                }
            }
           
            HStack{
                HStack(spacing: 20) {
                    // Start / Pause icon button
                    Button {
                        if isRunning {
                            pauseTimer()
                        } else {
                            startTimer()
                        }
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 52, height: 52)
                            .foregroundColor(.white)
                            .background(Circle().fill(isRunning ? Color.orange : Color.green))
                    }
                    .accessibilityLabel(isRunning ? "暂停" : "开始")
                    .buttonStyle(PlainButtonStyle())

                    // Reset icon button
                    Button {
                        resetTimer()
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
        .onAppear{
            preloadNotificationSound()
        }
        .onDisappear{
            stopTimer()
            audioPlayer = nil
        }
    }

    func startTimer() {
        isRunning = true
        currentTimer = totalTimer;
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTimer -= 1
            if currentTimer <= 0 {
                isRunning = false
                playNotificationSound()
                stopTimer()
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
    
    func pauseTimer(){
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentTimer = 0
    }
    
    func resetTimer(){
        isRunning = false
        timer = nil
        currentTimer  = totalTimer
    }
    
    // 预加载音效（可选，提升用户体验）
    private func preloadNotificationSound() {
       guard let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") else {
           return
       }
       
       do {
           audioPlayer = try AVAudioPlayer(contentsOf: url)
           // 设置为准备好播放状态
           audioPlayer?.prepareToPlay()
       } catch {
           
       }
    }
    
    // 播放通知音
    private func playNotificationSound() {
        guard let player = audioPlayer else {
            print("音频播放器未初始化")
            return
        }
        // 重置播放位置到开头（确保每次都是从头开始播放）
        player.currentTime = 0
        player.play()
    }
}


#Preview {
    TimerView()
}
