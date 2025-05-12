// WorkspaceSharingHelper.swift
// BudgetBud

import SwiftUI
import CoreData
import CloudKit

struct WorkspaceSharingHelper: UIViewControllerRepresentable {
    let workspace: Workspace
    let context: NSManagedObjectContext

    func makeCoordinator() -> Coordinator {
        Coordinator(workspace: workspace, context: context)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            context.coordinator.createShare { result in
                switch result {
                case .success((let share, let container)):
                    completion(share, container, nil)
                case .failure(let error):
                    print("❌ Share creation failed: \(error)")
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
            do {
                try context.save()
                let container = PersistenceController.shared.container

                container.share([workspace], to: nil) { share, container, error in
                    if let error = error {
                        completion(.failure(error))
                    } else if let share = share, let container = container {
                        share[CKShare.SystemFieldKey.title] = self.workspace.name as CKRecordValue?
                        completion(.success((share, container)))
                    } else {
                        completion(.failure(NSError(domain: "ShareError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown error."])))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }

        func itemTitle(for controller: UICloudSharingController) -> String? {
            workspace.name ?? "BudgetBud Workspace"
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            print("🛑 Sharing stopped.")
        }

        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ Failed to save share: \(error)")
        }

        func cloudSharingController(_ controller: UICloudSharingController, didSave share: CKShare) {
            print("✅ Share saved: \(share.recordID)")
        }
    }
}
