//
//  BudgetBudApp.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 5/12/25.
//

import SwiftUI

@main
struct BudgetBudApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
