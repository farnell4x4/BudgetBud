//AddCategoryView.swift
//BudgetBud
//Update on 2025-04-23, 04:18

import SwiftUI
import CoreData

struct AddCategoryView: View {
    var workspace: Workspace
    var isExpense: Bool
    var defaultName: String
    var onSave: ((Category) -> Void)? = nil

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var monthlyBudget: String = ""
    @State private var initialized: Bool = false

    
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $name)
                    TextField("Monthly Budget", text: $monthlyBudget)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
            .navigationTitle("New Category")
            .onAppear {
                if !initialized {
                    self.name = defaultName
                    initialized = true
                }
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveCategory() }
                }
                #else
                ToolbarItem {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem {
                    Button("Save") { saveCategory() }
                }
                #endif
            }
        }
        .accentColor(Color("AccentColor"))
    }

    private func saveCategory() {
        guard !name.isEmpty, let budget = Double(monthlyBudget) else {
            print("AddCategoryView: Invalid input.")
            return
        }

        let newCategory = Category(context: context)
        newCategory.id = UUID()
        newCategory.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        newCategory.monthlyBudget = budget
        newCategory.isExpense = isExpense
        newCategory.workspace = workspace

        context.insert(newCategory)

        do {
            try context.save()
            DispatchQueue.main.async {
                onSave?(newCategory)
                dismiss()
            }
        } catch {
            print("AddCategoryView: Failed to save category: \(error)")
        }
    }
}

struct AddCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let workspace = Workspace(context: context)
        workspace.id = UUID()
        workspace.name = "Preview Workspace"
        return AddCategoryView(workspace: workspace, isExpense: true, defaultName: "Sample Category")
            .environment(\.managedObjectContext, context)
    }
}
