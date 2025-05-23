// SettingsView.swift
// BudgetBud
// Updated on 2025-05-12 with revised sharing view

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

    @State private var isShowingShareSheet = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workspace.name, ascending: true)],
        animation: .default
    ) private var workspaces: FetchedResults<Workspace>

    private var currentWorkspace: Workspace? {
        guard let id = selectedWorkspaceID,
              let uuid = UUID(uuidString: id),
              let ws = workspaces.first(where: { $0.id == uuid })
        else { return nil }
        return ws
    }

    var body: some View {
        NavigationStack {
            List {
                GroupBox(label: Label("Current Workspace", systemImage: "person.3.fill").font(.headline)) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let workspace = currentWorkspace {
                            Text(workspace.name ?? "Unnamed Workspace")
                                .font(.title3)
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
                        if currentWorkspace != nil {
                            Button {
                                isShowingShareSheet = true
                            } label: {
                                Label("Share Workspace", systemImage: "person.crop.circle.badge.plus")
                            }
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
                        Button("Sign Out") { isSignedIn = false }
                            .foregroundColor(Color("AccentColor"))
                        Button("Delete My Account") { showDeleteAccountAlert = true }
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .accentColor(Color("AccentColor"))
            .sheet(isPresented: $isShowingShareSheet) {
                if let workspace = currentWorkspace {
                    WorkspaceSharingView(workspace: workspace, context: viewContext)
                }
            }
            .alert("Restore Successful", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage)
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete", role: .destructive) { deleteUserAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your data. This action cannot be undone.")
            }
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
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: nil)//'nil' requires a contextual type
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
