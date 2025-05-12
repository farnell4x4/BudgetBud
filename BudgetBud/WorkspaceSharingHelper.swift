//
//  WorkspaceSharingHelper.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 5/12/25.
//


// WorkspaceSharingHelper.swift
// BudgetBud
// Created 2025-05-12

import SwiftUI
import CoreData
import CloudKit

/// Handles creation of CKShare and presentation of the CloudKit share sheet.
struct WorkspaceSharingHelper: UIViewControllerRepresentable {
    let workspace: Workspace
    let context: NSManagedObjectContext

    func makeCoordinator() -> Coordinator {
        Coordinator(workspace: workspace, context: context)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { shareController, completion in
            context.coordinator.createShare { result in
                switch result {
                case .success(let (share, container)):
                    completion(share, container, nil)
                case .failure(let error):
                    completion(nil, nil, error)
                }
            }
        }

        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let workspace: Workspace
        let context: NSManagedObjectContext

        init(workspace: Workspace, context: NSManagedObjectContext) {
            self.workspace = workspace
            self.context = context
        }

        func createShare(completion: @escaping (Result<(CKShare, CKContainer), Error>) -> Void) {
            Task {
                do {
                    try context.save()
                    let container = NSPersistentCloudKitContainer.defaultDirectoryURL()
                    let sharedContainer = PersistenceController.shared.container

                    let (existingShare, newShare, cloudContainer) = try await sharedContainer.share([workspace], to: nil)
                    newShare[CKShare.SystemFieldKey.title] = workspace.name as CKRecordValue?

                    let store = sharedContainer.persistentStoreCoordinator.persistentStores.first!
                    try await sharedContainer.persistUpdatedShare(newShare, in: store)

                    completion(.success((newShare, cloudContainer)))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        func itemTitle(for controller: UICloudSharingController) -> String? {
            workspace.name ?? "Shared Workspace"
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            print("🛑 Sharing stopped")
        }

        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ Failed to save share: \(error.localizedDescription)")
        }

        func cloudSharingController(_ controller: UICloudSharingController, didSave share: CKShare) {
            print("✅ Share saved")
        }
    }
}
