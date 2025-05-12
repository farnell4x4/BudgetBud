// PersistenceController.swift
// BudgetBud

import CoreData
import CloudKit

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "BudgetBud")

        guard let storeDesc = container.persistentStoreDescriptions.first else {
            fatalError("⚠️ Missing store description.")
        }

        storeDesc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.BudgetBud.2"
        )
        storeDesc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDesc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if inMemory {
            storeDesc.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let err = error {
                fatalError("💥 Failed to load store: \(err.localizedDescription)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let workspace = Workspace(context: context)
        workspace.id = UUID()
        workspace.name = "Preview Workspace"

        let account = Account(context: context)
        account.id = UUID()
        account.name = "Checking"
        account.balance = 1000.0
        account.isCredit = false
        account.workspace = workspace

        try? context.save()
        return controller
    }()
}
