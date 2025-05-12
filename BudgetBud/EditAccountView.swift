//
//  EditAccountView.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 4/30/25.
//


//EditAccountView.swift
//BudgetBud
//Update on April 30, 2025, 15:00

import SwiftUI
import CoreData

struct EditAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var account: Account
    @State private var name: String

    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account Name")) {
                    TextField("Account Name", text: $name)
                }

                Section(header: Text("Initial Balance")) {
                    Text("\(account.balance, specifier: "%.2f")")
                        .foregroundColor(.gray)
                }

                Section(header: Text("Type")) {
                    Text(account.isCredit ? "Credit" : "Debit")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Edit Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        account.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? viewContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
