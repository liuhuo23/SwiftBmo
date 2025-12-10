//
//  Tasks+Ext.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/11.
//
import CoreData
import Foundation


extension Tasks {
    convenience init(subject: Subject?, total_time: Int64, finished_at: Date, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.subject = subject
        self.total_time = total_time
        self.finished_at = finished_at
    }
    
    var formattedTotalTime: String {
        let totalSeconds = Int(total_time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
