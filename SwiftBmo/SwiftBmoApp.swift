//
//  SwiftBmoApp.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI
import CoreData

@main
struct SwiftBmoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
