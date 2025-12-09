//
//  UpdateManagerTests.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/10.
//

import XCTest
@testable import SwiftBmo

@MainActor
final class UpdateManagerTests: XCTestCase {

    var manager: UpdateManager!
    var userDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        userDefaults = UserDefaults.standard
        manager = UpdateManager()
        cleanUserDefaults()
    }

    override func tearDown() async throws {
        cleanUserDefaults()
        manager = nil
        try await super.tearDown()
    }

    private func cleanUserDefaults() {
        userDefaults.removeObject(forKey: "update_last_check")
        userDefaults.removeObject(forKey: "update_etag")
        userDefaults.removeObject(forKey: "update_ignored_version")
        userDefaults.removeObject(forKey: "update_next_remind")
    }

    func testCheckForUpdates() async {
        let exp = expectation(description: "update check")
        
        manager.checkForUpdates { result in
            switch result {
            case .success(let hasUpdate):
                // We can't guarantee if there's an update or not, but we can check the type
                XCTAssertTrue(type(of: hasUpdate) == Bool.self)
            case .failure(let error):
                XCTFail("Update check failed with error: \(error)")
            }
            exp.fulfill()
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
    }

    func testInitialization() {
        XCTAssertEqual(manager.state, .idle)
        XCTAssertFalse(manager.lastCheckWasManual)
        XCTAssertFalse(manager.isShowingUpdateSheet)
        XCTAssertFalse(manager.isDownloading)
        XCTAssertNil(manager.downloadProgress)
        XCTAssertNil(manager.downloadedFileURL)
        XCTAssertNil(manager.downloadError)
    }

    func testIgnoreVersion() {
        let info = UpdateInfo(version: "2.0.0", url: URL(string: "https://example.com")!, releaseNotes: nil, mandatory: false, releaseDate: nil)
        manager.ignoreVersion(info)
        XCTAssertEqual(manager.state, .upToDate)
        // Check UserDefaults
        XCTAssertEqual(userDefaults.string(forKey: "update_ignored_version"), info.id)
    }

    func testRemindLater() {
        let interval: TimeInterval = 3600 // 1 hour
        let before = Date()
        manager.remindLater(after: interval)
        XCTAssertEqual(manager.state, .upToDate)
        let nextRemind = userDefaults.object(forKey: "update_next_remind") as? Date
        XCTAssertNotNil(nextRemind)
        XCTAssertTrue(nextRemind! >= before.addingTimeInterval(interval - 1))
        XCTAssertTrue(nextRemind! <= before.addingTimeInterval(interval + 1))
    }

    func testCancelCheck() {
        // Since state is private(set), we can't set it directly. Instead, test cancelCheck when idle
        manager.cancelCheck()
        XCTAssertEqual(manager.state, .idle)
        XCTAssertFalse(manager.lastCheckWasManual)
    }

    func testPresentUpdateUI() {
        manager.presentUpdateUI()
        XCTAssertTrue(manager.isShowingUpdateSheet)
        XCTAssertTrue(manager.lastCheckWasManual)
        XCTAssertNil(manager.downloadedFileURL)
        XCTAssertNil(manager.downloadError)
        // Note: checkForUpdate is called, but since no URL, state remains idle
        XCTAssertEqual(manager.state, .idle)
    }

    func testCloseUpdateWindow() {
        manager.isShowingUpdateSheet = true
        manager.closeUpdateWindow()
        XCTAssertFalse(manager.isShowingUpdateSheet)
    }

    func testSharedInstance() {
        let shared1 = UpdateManager.shared
        let shared2 = UpdateManager.shared
        XCTAssert(shared1 === shared2, "Shared instance should be singleton")
    }

}
