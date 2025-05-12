
//WorkspaceOnboardingView.swift
//BudgetBud
//Update on 2025-04-23, 04:18

import SwiftUI
import CoreData

struct WorkspaceOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var workspaceName: String = ""
    var onWorkspaceCreated: (Workspace) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to BudgetBud")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("You need to create a workspace to begin. All your budgets, accounts, and transactions will live inside a workspace. This allows syncing, sharing, and keeps your data organized.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Form {
                Section(header: Text("Create Your First Workspace")) {
                    TextField("Workspace Name", text: $workspaceName)
                        .textInputAutocapitalization(.words)
                }
                Button("Create Workspace") {
                    let newWorkspace = Workspace(context: viewContext)
                    newWorkspace.id = UUID()
                    newWorkspace.name = workspaceName.trimmingCharacters(in: .whitespaces)
                    do {
                        try viewContext.save()
                        onWorkspaceCreated(newWorkspace)
                    } catch {
                        print("Failed to create workspace: \(error)")
                    }
                }
                .disabled(workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .frame(maxWidth: 400)
        }
        .padding()
    }
}
