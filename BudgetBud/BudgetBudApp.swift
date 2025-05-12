// BudgetBudApp.swift
// BudgetBud
// Fixed on 2025-05-12

import SwiftUI
import CoreData

@main
struct BudgetBudApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("isSignedIn") var isSignedIn: Bool = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
