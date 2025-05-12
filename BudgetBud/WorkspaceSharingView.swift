//
//  WorkspaceSharingView.swift
//  BudgetBud
//
//  Created by Joshua     on 5/9/25.
//


// WorkspaceSharingView.swift
// BudgetBud
// Regenerated on 2025-05-09 for compatibility with updated SettingsView

import SwiftUI
import CloudKit

struct WorkspaceSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ UICloudSharingController failed to save share: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            return "BudgetBud Workspace"
        }

        func cloudSharingController(_ csc: UICloudSharingController, didSave share: CKShare) {
            print("✅ Share saved successfully.")
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("ℹ️ User stopped sharing.")
        }
    }
}
