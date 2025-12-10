//
//  SubjectTests.swift
//  SwiftBmoTests
//
//  Created by Assistant on 2025/12/11.
//

import XCTest
@testable import SwiftBmo

class SubjectTests: XCTestCase {
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }
    
    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }
    
    func testTotalTime() {
        let context = persistenceController.container.viewContext
        let subject = Subject(context: context)
        subject.name = "History"
        let task1 = Tasks(context: context) // 1 hour
        task1.subject = subject
        task1.total_time = 3600
        let task2 = Tasks( context: context) // 30 min
        task2.subject = subject
        task2.total_time = 1800
        XCTAssertEqual(subject.totalTime, 5400)
    }
    
    
    // CRUD 操作示例
    
    // Create: 创建新实体
    func testCreateSubject() {
        let context = persistenceController.container.viewContext
        let subject = Subject(context: context)
        subject.name = "Math"
        subject.id = UUID()
        XCTAssertEqual(subject.name, "Math")
        XCTAssertNotNil(subject.id)
        
        // 保存到持久化存储
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
    }
    
    // Read: 查询实体
    func testReadSubjects() {
        let context = persistenceController.container.viewContext
        
        // 创建一些测试数据
        let _ = Subject(name: "Math", context: context)
        let _ = Subject(name: "Science", context: context)
        try? context.save()
        
        // 查询所有Subject
        let fetchRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        do {
            let subjects = try context.fetch(fetchRequest)
            XCTAssertEqual(subjects.count, 2)
        } catch {
            XCTFail("Failed to fetch subjects: \(error)")
        }
        
        // 根据条件查询
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Math")
        do {
            let mathSubjects = try context.fetch(fetchRequest)
            XCTAssertEqual(mathSubjects.count, 1)
            XCTAssertEqual(mathSubjects.first?.name, "Math")
        } catch {
            XCTFail("Failed to fetch math subjects: \(error)")
        }
    }
    
    // Update: 更新实体
    func testUpdateSubject() {
        let context = persistenceController.container.viewContext
        let subject = Subject(name: "Old Name", context: context)
        try? context.save()
        
        // 更新名称
        subject.name = "New Name"
        
        // 保存更改
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // 验证更新
        let fetchRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", subject.id! as CVarArg)
        do {
            let updatedSubjects = try context.fetch(fetchRequest)
            XCTAssertEqual(updatedSubjects.first?.name, "New Name")
        } catch {
            XCTFail("Failed to fetch updated subject: \(error)")
        }
    }
    
    // Delete: 删除实体
    func testDeleteSubject() {
        let context = persistenceController.container.viewContext
        let subject = Subject(name: "To Delete", context: context)
        try? context.save()
        
        // 验证存在
        let fetchRequest: NSFetchRequest<Subject> = Subject.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", subject.id! as CVarArg)
        do {
            var subjects = try context.fetch(fetchRequest)
            XCTAssertEqual(subjects.count, 1)
            
            // 删除
            context.delete(subject)
            try context.save()
            
            // 验证删除
            subjects = try context.fetch(fetchRequest)
            XCTAssertEqual(subjects.count, 0)
        } catch {
            XCTFail("Failed to delete subject: \(error)")
        }
    }
}
