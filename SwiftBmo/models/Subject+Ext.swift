//
//  Subject+Ext.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/11.
//
import CoreData


extension Subject{
    convenience init(name: String, context: NSManagedObjectContext) {
        self.init(context: context)
        self.name = name
        self.id = UUID()
    }
    
    var totalTime: Int64 {
        (self.tasks?.allObjects as? [Tasks])?.reduce(into: Int64(0)) { $0 += $1.total_time } ?? 0
    }

    var taskCound: Int {
        self.tasks?.count ?? 0
    }
}
