//AccountsView.swift
//BudgetBud
//Update on 2025-04-07, 23:00
import SwiftUI
import CoreData

struct AccountsView: View {
    var workspace: Workspace
    @Environment(\.managedObjectContext) private var viewContext

    // Fetch only accounts for this workspace.
    @FetchRequest var accounts: FetchedResults<Account>
    
    @State private var showAddAccount = false
    @State private var isEditingAccounts = false
    @State private var showTutorial = false
    
    // State for deletion alert.
    @State private var accountToDelete: Account?
    @State private var showDeleteAccountAlert: Bool = false
    
    @State private var selectedAccountToEdit: Account? = nil
    @State private var showEditAccountSheet = false


    init(workspace: Workspace) {
        self.workspace = workspace
        _accounts = FetchRequest<Account>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
    }

    var totalAvailable: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    var body: some View {
        ZStack {
            Color("AccentColor1").ignoresSafeArea()  // updated background

            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Available:")
                                .font(.headline)
                            Text(totalAvailable, format: .currency(code: "USD"))
                                .font(.title2)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                if accounts.isEmpty {
                    Text("No accounts yet. Add one!")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(accounts, id: \.objectID) { account in
                        if isEditingAccounts {
                            Button {
                                // Placeholder for edit action if needed.
                            } label: {
                                accountRow(account)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let trans = account.transactions, trans.count > 0 {
                                        accountToDelete = account
                                        showDeleteAccountAlert = true
                                    } else {
                                        deleteAccount(account)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } else {
                            NavigationLink(destination: TransactionsListView(workspace: workspace, prefilledSearch: account.name ?? "")) {
                                accountRow(account)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    selectedAccountToEdit = account
                                    showEditAccountSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }

                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    if let trans = account.transactions, trans.count > 0 {
                                        accountToDelete = account
                                        showDeleteAccountAlert = true
                                    } else {
                                        deleteAccount(account)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
        
            
            
            
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAddAccount = true
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
                .foregroundColor(Color("AccentColor"))
                
                Button {
                    showTutorial = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .foregroundColor(Color("AccentColor"))
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView(workspace: workspace)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showTutorial) {
            Text("Tutorial / Info Screen")
                .padding()
        }
        .sheet(isPresented: $showEditAccountSheet) {
            if let account = selectedAccountToEdit {
                EditAccountView(account: account)
                    .environment(\.managedObjectContext, viewContext)
            }
        }

        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Delete", role: .destructive) {
                if let accountToDelete = accountToDelete {
                    deleteAccount(accountToDelete)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This account has related transactions which will also be deleted. Are you sure you want to continue?")
        }
    }
    
    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name ?? "Unnamed")
                    .font(.headline)
                    .foregroundColor(account.isCredit ? .red : .primary)
                Text("Balance: \(account.balance, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
            Spacer()
            if account.isCredit {
                Text("Credit")
                    .foregroundColor(.red)
            } else {
                Text("Debit")
                    .foregroundColor(.accent)
            }
        }
    }
    
    private func deleteAccount(_ account: Account) {
        viewContext.delete(account)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete account: \(error)")
        }
    }
}

struct AccountsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext//Type 'PersistenceController' has no member 'preview'
        let previewWorkspace = Workspace(context: context)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"
        return NavigationView {
            AccountsView(workspace: previewWorkspace)
                .environment(\.managedObjectContext, context)
        }
    }
}

