//
//  PersistenceController.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 5/12/25.
//


// PersistenceController.swift
// BudgetBud

import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "BudgetBud")

        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }

        storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.BudgetBud.Clean"
        )
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if inMemory {
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        let previewWorkspace = Workspace(context: viewContext)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"

        let account = Account(context: viewContext)
        account.id = UUID()
        account.name = "Checking"
        account.balance = 1500.00
        account.isCredit = false
        account.workspace = previewWorkspace

        do {
            try viewContext.save()
        } catch {
            fatalError("Unresolved error \(error)")
        }

        return controller
    }()
}
