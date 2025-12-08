//
//  ContentView.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack{
            TimerView()
                .frame(minWidth: 400, minHeight: 600)
                .padding()
        }
        .padding()
        #if !os(macOS)
        .sheet(isPresented: $updateManager.isShowingUpdateSheet) {
            UpdateSheetView(manager: updateManager)
        }
        #endif
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
