//
//  TimerViewModelTests.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/8.
//

import XCTest
@testable import SwiftBmo

final class TimerViewModelTests: XCTestCase {
    func testStartCompletes() async {
        let vm = await MainActor.run { TimerViewModel(tickInterval: 0.01) }
        let exp = expectation(description: "completion")
        await MainActor.run { vm.onComplete = { exp.fulfill() } }

        await MainActor.run { vm.start(duration: 0.05) }

        await fulfillment(of: [exp], timeout: 1.0)
        await MainActor.run {
            XCTAssertEqual(vm.state, .finished)
            XCTAssertEqual(vm.remaining, 0, accuracy: 0.01)
            XCTAssertGreaterThanOrEqual(vm.progress, 1.0)
        }
    }

    func testPauseResume() async {
        let vm = await MainActor.run { TimerViewModel(tickInterval: 0.01) }
        await MainActor.run { vm.start(duration: 0.2) }
        // sleep a bit
        try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
        await MainActor.run { vm.pause() }
        let remainingAfterPause = await MainActor.run { vm.remaining }
        await MainActor.run { XCTAssertEqual(vm.state, .paused) }
        // resume
        await MainActor.run { vm.resume() }
        await MainActor.run { XCTAssertEqual(vm.state, .running) }
        // wait for completion
        let exp = expectation(description: "completion2")
        await MainActor.run { vm.onComplete = { exp.fulfill() } }
        await fulfillment(of: [exp], timeout: 2.0)
        await MainActor.run {
            XCTAssertEqual(vm.state, .finished)
            XCTAssertEqual(vm.remaining, 0, accuracy: 0.05)
            XCTAssertGreaterThanOrEqual(vm.progress, 1.0)
            XCTAssertLessThanOrEqual(remainingAfterPause, 0.2)
        }
    }
}
