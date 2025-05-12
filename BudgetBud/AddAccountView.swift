//AddAccountView.swift
//BudgetBud
//Update on 2025-04-09, 10:30
import SwiftUI
import CoreData

struct AddAccountView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // New onSave closure property so the new account can be passed back.
    var onSave: ((Account) -> Void)? = nil

    @State private var name: String
    @State private var balance: String = "0.00"
    @State private var lastFourDigits: String = ""
    @State private var isCredit: Bool = false

    var workspace: Workspace

    // defaultName pre-fills the Account Name; onSave is optional.
    init(workspace: Workspace, defaultName: String = "", onSave: ((Account) -> Void)? = nil) {
        self.workspace = workspace
        _name = State(initialValue: defaultName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("IMPORTANT! Make sure to properly set whether this account is credit or debit. Also make sure not to include pending payments in the initial balance.")
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                }
                Section(header: Text("Account Details")) {
                    TextField("Account Name", text: $name)
                    TextField("Initial Balance", text: $balance)
                        .keyboardType(.decimalPad)
                        .onChange(of: balance) { oldValue, newValue in
                            let formatted = formatCurrencyInput(newValue)
                            if formatted != newValue {
                                balance = formatted
                            }
                        }
                    TextField("Payment Method Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                    Toggle("Credit Account", isOn: $isCredit)
                }
            }
            .navigationTitle("New Account")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveAccount() }
                }
                #else
                ToolbarItem {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem {
                    Button("Save") { saveAccount() }
                }
                #endif
            }
        }
        .accentColor(Color("AccentColor"))
    }

    private func saveAccount() {
        guard let balanceValue = Double(balance), !name.isEmpty else {
            print("Invalid input.")
            return
        }

        let adjustedBalance = isCredit ? -abs(balanceValue) : abs(balanceValue)
        let newAccount = Account(context: viewContext)
        newAccount.id = UUID()
        newAccount.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        newAccount.balance = adjustedBalance
        newAccount.isCredit = isCredit
        newAccount.lastFourDigits = lastFourDigits
        newAccount.workspace = workspace  // assign workspace explicitly
        // Add the new account to the workspace's relationship.
        workspace.addToAccount(newAccount)
        
        
        newAccount.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try viewContext.save()
            DispatchQueue.main.async {
                onSave?(newAccount)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    dismiss()
                }
            }

        }

        catch {
            print("Failed to save account: \(error)")
        }
    }

    private func formatCurrencyInput(_ input: String) -> String {
        let digits = input.filter { "0123456789".contains($0) }
        guard let number = Double(digits) else { return "0.00" }
        let value = number / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let previewWorkspace = Workspace(context: context)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"
        return AddAccountView(workspace: previewWorkspace, defaultName: "Sample Account")
            .environment(\.managedObjectContext, context)
    }
}
