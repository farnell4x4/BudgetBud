// SettingsView.swift
// BudgetBud
// Updated with async CloudKit sharing logic on 2025-05-09

import SwiftUI
import CoreData
import CloudKit

struct SettingsView: View {
    @AppStorage("selectedWorkspaceID") private var selectedWorkspaceID: String?
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var safariURL: URL?
    @AppStorage("isSignedIn") private var isSignedIn: Bool = true
    @State private var showDeleteAccountAlert = false

    @State private var share: CKShare? = nil
    @State private var isShowingShareSheet: Bool = false
    @State private var shareContainer: CKContainer? = nil

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workspace.name, ascending: true)],
        animation: .default
    ) private var workspaces: FetchedResults<Workspace>

    var currentWorkspace: Workspace? {
        workspaces.first(where: { $0.id?.uuidString == selectedWorkspaceID })
    }

    var body: some View {
        NavigationStack {
            List {
                GroupBox(label: Label("Current Workspace", systemImage: "person.3.fill").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let workspace = currentWorkspace {
                            Text(workspace.name ?? "Unnamed Workspace")
                                .foregroundColor(.primary)
                        } else {
                            Text("No workspace selected.")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 5)
                }

                GroupBox(label: Label("Workspace Actions", systemImage: "arrow.2.squarepath").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        NavigationLink(destination: ManageWorkspacesView(selectedWorkspaceID: $selectedWorkspaceID)) {
                            Label("Manage Workspaces", systemImage: "rectangle.stack")
                        }
                        if let workspace = currentWorkspace {
                            Button {
                                print("***🔁 Share button tapped")
                                Task { await shareWorkspace(workspace) }
                            } label: {
                                Label("Share Workspace", systemImage: "square.and.arrow.up")
                            }

                            Text("Note: Tap this after creating a workspace and waiting ~5s for it to sync.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 5)
                }

                GroupBox(label: Label("Reports", systemImage: "doc.text.magnifyingglass").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let workspace = currentWorkspace {
                            NavigationLink(destination: ReportView(workspace: workspace)) {
                                Label("Export Report", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Text("Select a workspace to export reports.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }


                GroupBox(label: Label("User Settings", systemImage: "person.crop.circle").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Sign Out") {
                            isSignedIn = false
                        }
                        .foregroundColor(Color("AccentColor"))

                        Button("Delete My Account") {
                            showDeleteAccountAlert = true
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.vertical, 5)
                }

             

                
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .accentColor(Color("AccentColor"))

            .sheet(isPresented: $isShowingShareSheet) {
                if let share = share, let container = shareContainer {
                    WorkspaceSharingView(share: share, container: container)//
                }
            }
        }
        .alert("Restore Successful", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                deleteUserAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete your account, workspace, and all data associated with it. This action cannot be undone.")
        }
    }

    private func shareWorkspace(_ workspace: Workspace) async {
        do {
            try viewContext.save()
            let (_, newShare, container) = try await PersistenceController.shared.container.share([workspace], to: nil)
            newShare[CKShare.SystemFieldKey.title] = workspace.name as CKRecordValue?
            let store = PersistenceController.shared.container.persistentStoreCoordinator.persistentStores.first!
            try await PersistenceController.shared.container.persistUpdatedShare(newShare, in: store)
            self.share = newShare
            self.shareContainer = container
            self.isShowingShareSheet = true
            print("***✅ Successfully created share")
        } catch {
            print("***❌ Failed to share workspace: \(error)")
        }
    }

    private func deleteUserAccount() {
        let container = PersistenceController.shared.container
        let context = container.viewContext

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Workspace.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs], into: [context])
            }
            try context.save()
        } catch {
            print("***❌ Failed deleting local data: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            container.persistentStoreCoordinator.persistentStores.forEach { store in
                do {
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: nil)
                } catch {
                    print("***❌ Failed to destroy store: \(error)")
                }
            }

            container.loadPersistentStores { _, error in
                if let error = error {
                    print("***❌ Failed to reload store: \(error)")
                } else {
                    selectedWorkspaceID = nil
                    isSignedIn = false
                }
            }
        }
    }
}
