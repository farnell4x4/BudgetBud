//
//  EditCategoryView.swift
//  BudgetBud49,3
//
//  Created by Joshua     on 4/21/25.
//


//EditCategoryView.swift
//BudgetBud
//Update on 2025-04-09, 21:05
import SwiftUI
import CoreData

struct EditCategoryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var category: Category
    
    @State private var name: String
    @State private var baseBudget: String
    // Removed budgetResetDay as it is managed globally via settings.

    init(category: Category) {
        self.category = category
        self.name = category.name ?? ""
        self.baseBudget = String(format: "%.2f", category.monthlyBudget)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Category Details")) {
                    TextField("Category Name", text: $name)
                    TextField("Base Monthly Budget", text: $baseBudget)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
            .navigationTitle("Edit Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEdits() }
                }
            }
        }
        .accentColor(Color("AccentColor"))
    }
    
    private func saveEdits() {
        guard !name.isEmpty, let budget = Double(baseBudget) else {
            print("EditCategoryView: Invalid input.")
            return
        }
        category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        category.monthlyBudget = budget
  
        do {
            try context.save()
            dismiss()
        } catch {
            print("EditCategoryView: Failed to save category: \(error)")
        }
    }
}

struct EditCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let category = Category(context: context)
        category.id = UUID()
        category.name = "Sample Category"

        category.actualSpent = 100
        return NavigationStack {
            EditCategoryView(category: category)
                .environment(\.managedObjectContext, context)
        }
    }
}
