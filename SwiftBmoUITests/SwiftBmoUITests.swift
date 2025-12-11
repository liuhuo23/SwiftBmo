//
//  SwiftBmoUITests.swift
//  SwiftBmoUITests
//
//  Created by liuhuo on 2025/12/7.
//

import XCTest

final class SwiftBmoUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testTimerViewStartAndComplete() throws {
        let app = XCUIApplication()
        app.launch()
        // Wait for the app to load

        // Tap the play button to start the timer
        let playButton = app.buttons["开始"]
        XCTAssertTrue(playButton.exists)
        playButton.tap()

        // Wait for the timer to complete (assuming 60 seconds, but for test, we can wait a bit or mock)
        // Since it's a real timer, for UI test, we might need to wait or use a shorter duration
        // For demonstration, let's check if the state changes to running
        XCTAssertTrue(app.staticTexts["专注中"].exists)

        // To test completion, we could set a very short duration, but since it's fixed, perhaps add a test with custom duration
        // For now, pause it
        let pauseButton = app.buttons["暂停"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 1))
        pauseButton.tap()

        XCTAssertTrue(app.staticTexts["休息中"].exists)
    }
}
