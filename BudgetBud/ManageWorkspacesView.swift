// ManageWorkspacesView.swift
// BudgetBud
// Updated on 2025-04-05, 23:00

import SwiftUI
import CoreData

struct ManageWorkspacesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Workspace.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Workspace.name, ascending: true)],
        predicate: nil,
        animation: .default
    ) private var workspaces: FetchedResults<Workspace>


    @Binding var selectedWorkspaceID: String?
    @State private var newWorkspaceName: String = ""

    var body: some View {
        Form {
            switchSection
            createSection
            deleteSection
                .onAppear {
                    print("***🧭 onAppear: workspaces.count = \(workspaces.count)")
                    for w in workspaces {
                        print("***🔍 Workspace: \(w.name ?? "Unnamed") | id: \(w.id?.uuidString ?? "nil")")
                        print("***    workspace object: \(w)")                    }
                }

        }
        .navigationTitle("Manage Workspaces")
        .accentColor(Color("AccentColor"))
    }

    private var switchSection: some View {
        Section(header: Text("Switch Workspace")) {
            ForEach(workspaces, id: \.self) { workspace in
                Button(action: {
                    selectedWorkspaceID = workspace.id?.uuidString
                }) {
                    HStack {
                        Text(workspace.name ?? "Unnamed Workspace")

                        // 🟦 Optional badge for shared workspace
                        if workspace.objectID.uriRepresentation().absoluteString.contains("private") == false {
                            Text("Shared")
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }


                        Spacer()

                        if selectedWorkspaceID == workspace.id?.uuidString {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private var createSection: some View {
        Section(header: Text("Create New Workspace")) {
            TextField("Workspace Name", text: $newWorkspaceName)
            Button("Add") {
                let newWorkspace = Workspace(context: viewContext)
                newWorkspace.id = UUID()
                newWorkspace.name = newWorkspaceName
                do {
                    try viewContext.save()
                    selectedWorkspaceID = newWorkspace.id?.uuidString
                    newWorkspaceName = ""
                } catch {
                    print("***Failed to save new workspace: \(error)")
                }
            }
            .disabled(newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var deleteSection: some View {
        Section(header: Text("Delete Workspace")) {
            ForEach(workspaces, id: \.self) { workspace in
                if workspace.id?.uuidString != selectedWorkspaceID {
                    Button(role: .destructive) {
                        viewContext.delete(workspace)
                        try? viewContext.save()
                    } label: {
                        Text("Delete \(workspace.name ?? "Unnamed")")
                    }
                }
            }
        }
    }
}
