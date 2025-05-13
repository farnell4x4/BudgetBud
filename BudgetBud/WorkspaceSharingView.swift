//
//  WorkspaceSharingView.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 5/12/25.
//


// WorkspaceSharingView.swift
// BudgetBud
// Created on 2025-05-13 — Updated for iOS 17+ sharing API

import SwiftUI
import CoreData
import CloudKit
import UIKit

struct WorkspaceSharingView: UIViewControllerRepresentable {
    let workspace: Workspace
    let context: NSManagedObjectContext

    func makeCoordinator() -> Coordinator {
        Coordinator(workspace: workspace, context: context)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ShareWrapperViewController(
            workspace: workspace,
            managedObjectContext: self.context,
            coordinator: makeCoordinator()
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // no updates needed
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let workspace: Workspace
        let context: NSManagedObjectContext

        init(workspace: Workspace, context: NSManagedObjectContext) {
            self.workspace = workspace
            self.context = context
        }

        func itemTitle(for controller: UICloudSharingController) -> String? {
            workspace.name
        }

        func cloudSharingController(_ controller: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            print("❌ Failed to save share: \(error)")
        }

        func cloudSharingController(_ controller: UICloudSharingController,
                                    didSave share: CKShare) {
            print("✅ Share saved: \(share.recordID.recordName)")
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            print("🛑 Sharing stopped for workspace \(workspace.name ?? "")")
        }
    }
}

private class ShareWrapperViewController: UIViewController {
    let workspace: Workspace
    let managedObjectContext: NSManagedObjectContext
    let coordinator: WorkspaceSharingView.Coordinator
    private var didPresentShare = false

    init(workspace: Workspace,
         managedObjectContext: NSManagedObjectContext,
         coordinator: WorkspaceSharingView.Coordinator) {
        self.workspace = workspace
        self.managedObjectContext = managedObjectContext
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresentShare else { return }
        didPresentShare = true

        // 1️⃣ Save local changes so workspace has permanent ID
        if managedObjectContext.hasChanges {
            try? managedObjectContext.save()
        }

        // 2️⃣ Create and prepare the CKShare
        let container = PersistenceController.shared.container
        guard let store = container.persistentStoreCoordinator.persistentStores.first else {
            return
        }

        container.share([workspace], to: nil) { _, share, ckContainer, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error creating share: \(error)")
                    return
                }
                guard let share = share, let ckContainer = ckContainer else { return }

                // 3️⃣ Title the share record
                share[CKShare.SystemFieldKey.title] = self.workspace.name as CKRecordValue?

                // 4️⃣ Persist with retry-on-serverRecordChanged
                container.persistUpdatedShare(share, in: store) { persistedShare, persistError in
                    DispatchQueue.main.async {
                        if let ckErr = persistError as? CKError,
                           ckErr.code == .serverRecordChanged,
                           let serverShare = ckErr.serverRecord as? CKShare {
                            // Retry with server’s version
                            container.persistUpdatedShare(serverShare, in: store) { retryShare, retryError in
                                DispatchQueue.main.async {
                                    let toPresent = retryShare ?? serverShare
                                    self.presentShareController(toPresent, container: ckContainer)
                                }
                            }
                        } else if let persistedShare = persistedShare {
                            // Success on first try
                            self.presentShareController(persistedShare, container: ckContainer)
                        }
                    }
                }
            }
        }
    }

    private func presentShareController(_ share: CKShare, container: CKContainer) {
        let shareController: UICloudSharingController
        if #available(iOS 17, *) {
            // New iOS 17+ initializer
            shareController = UICloudSharingController(share: share, container: container)
        } else {
            // Fallback for earlier
            shareController = UICloudSharingController(preparationHandler: { _, completion in
                completion(share, container, nil)
            })
        }

        shareController.delegate = coordinator
        shareController.availablePermissions = [.allowPrivate, .allowReadWrite]
        shareController.modalPresentationStyle = .formSheet
        present(shareController, animated: true)
    }
}
