//
//  TimerViewModel.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/8.
//

import Foundation
import Combine
import AVFoundation
import CoreData
#if canImport(AppKit)
import AppKit
#endif

final class TimerViewModel: ObservableObject {
    // MARK: - Public types
    enum State: String, Equatable {
        case idle
        case running
        case paused
        case finished
    }

    // MARK: - Published outputs for UI binding
    @Published private(set) var state: State = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var totalDuration: TimeInterval = 0
    @Published private(set) var progress: Double = 0 // 0.0 ... 1.0

    // Allow UI to control whether sound should play on completion
    @Published var soundEnabled: Bool = true

    // Theme selection
    @Published var selectSubject: Subject? = nil

    // Subject name for database
    @Published var subjectName: String? = nil

    // An optional callback the view can set to react to completion (play sound, send notification)
    var onComplete: (() -> Void)?

    // MARK: - Private
    private var timer: DispatchSourceTimer?
    private var timerQueue = DispatchQueue(label: "com.swiftbmo.timerviewmodel", qos: .userInitiated)

    /// The absolute target date when the countdown should reach zero. Using an absolute date makes the timer robust to sleep/wake.
    private var targetDate: Date?

    /// When paused, store remaining seconds to allow resume.
    private var pausedRemaining: TimeInterval?

    /// Last tick interval (seconds). Controls UI update frequency. Keep small for smooth UI but not too small to waste CPU.
    private let tickInterval: TimeInterval

    // Optional audio player (lazy) for completion sound
    private lazy var audioPlayer: AVAudioPlayer? = makeAudioPlayer()

    // Database context
    private var context: NSManagedObjectContext

    // MARK: - Init
    init(context: NSManagedObjectContext, tickInterval: TimeInterval = 0.25) {
        self.context = context
        self.tickInterval = tickInterval
    }

    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }

    deinit {
        // Stop timer synchronously without requiring MainActor isolation
        if let t = timer {
            t.setEventHandler {}
            t.cancel()
            timer = nil
        }
    }

    // MARK: - Public control API

    /// Start a countdown for the given duration (seconds). If a timer is already running it will be restarted.
    @MainActor
    func start(duration: TimeInterval) {
        guard duration > 0 else { return }

        stopTimer()

        totalDuration = duration
        remaining = duration
        progress = 0
        state = .running
        pausedRemaining = nil

        targetDate = Date().addingTimeInterval(duration)
        startTimer()
    }

    /// Pause the running timer. Safe to call when not running (no-op).
    @MainActor
    func pause() {
        guard state == .running else { return }
        // Capture remaining and cancel timer
        pausedRemaining = computeRemaining()
        stopTimer()
        state = .paused
    }

    /// Resume a paused timer. If not paused, no-op.
    @MainActor
    func resume() {
        guard state == .paused, let remainingToResume = pausedRemaining, remainingToResume > 0 else { return }
        pausedRemaining = nil
        totalDuration = remainingToResume // keep UI consistent (optional: could preserve original totalDuration)
        remaining = remainingToResume
        progress = 0
        targetDate = Date().addingTimeInterval(remainingToResume)
        state = .running
        startTimer()
    }

    /// Reset the timer to idle and clear progress. Does not change preset totalDuration unless you pass a new duration via start.
    @MainActor
    func reset() {
        stopTimer()
        targetDate = nil
        pausedRemaining = nil
        state = .idle
        remaining = 0
        totalDuration = 0
        progress = 0
    }

    // MARK: - Private timer handling
    private func startTimer() {
        stopTimer() // ensure single timer

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: tickInterval, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        self.timer = timer
        timer.resume()
    }

    private func stopTimer() {
        if let timer = timer {
            timer.setEventHandler {}
            timer.cancel()
            // If the timer was suspended, resuming before cancel is required. We always create resumed timers so safe.
            self.timer = nil
        }
    }

    /// Compute remaining seconds based on targetDate. Uses Date() and is safe across sleep/wake because targetDate is absolute.
    private func computeRemaining() -> TimeInterval {
        guard let target = targetDate else { return 0 }
        let r = target.timeIntervalSinceNow
        return max(0, r)
    }

    @MainActor
    private func handleTick() {
        let r = computeRemaining()
        remaining = r

        if totalDuration > 0 {
            progress = min(1.0, max(0.0, 1 - (remaining / totalDuration)))
        } else {
            progress = 0
        }

        if remaining <= 0 {
            // complete
            stopTimer()
            state = .finished

            // Fire completion callback on main actor
            onComplete?()

            // Save to database
            saveCompletedTask()

            // Play sound if available and enabled
            if soundEnabled {
                audioPlayer?.play()
            }

            // Bounce Dock as a stronger visual cue on macOS
            #if canImport(AppKit)
            DispatchQueue.main.async {
                NSApplication.shared.requestUserAttention(.criticalRequest)
            }
            #endif
        }
    }

    // MARK: - Utilities

    private func makeAudioPlayer() -> AVAudioPlayer? {
        // Look for a bundled ding.mp3 in Resources (project contains Resource/ding.mp3). The exact path may differ depending on asset setup.
        guard let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    // MARK: - Database

    private func saveCompletedTask() {
        guard let selectSubject = selectSubject else { return }
//        let subject = getOrCreateSubject(name: subjectName, context: self.context)
        _ = Tasks(subject: selectSubject, total_time: Int64(totalDuration), finished_at: Date(), context: context)
        do {
            print("开始保存")
            try context.save()
        } catch {
            print("Failed to save task: \(error)")
        }
    }

    private func getOrCreateSubject(name: String, context: NSManagedObjectContext) -> Subject {
        let request = Subject.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        if let existing = try? context.fetch(request).first {
            return existing
        } else {
            return Subject(name: name, context: context)
        }
    }
}
