//
//  TasksTests.swift
//  SwiftBmoTests
//
//  Created by Assistant on 2025/12/11.
//

import XCTest
@testable import SwiftBmo

class TasksTests: XCTestCase {
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testFormattedTotalTime() {
        let context = persistenceController.container.viewContext
        let task = Tasks(subject: nil, total_time: 3600, finished_at: .now, context: context) // 1h 1m 1s
        XCTAssertEqual(task.formattedTotalTime, "01:00:00")
    }
    
    func testConvenienceInit() {
        let context = persistenceController.container.viewContext
        let subject = Subject(name: "Test", context: context)
        let task = Tasks(subject: subject, total_time: 120, finished_at: .now, context: context)
        XCTAssertEqual(task.total_time, 120)
        XCTAssertEqual(task.subject, subject)
        XCTAssertNotNil(task.id)
    }
}
