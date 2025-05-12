//BudgetView.swift
//BudgetBud
//Update on April 22, 2025, 15:55
import SwiftUI
import CoreData

struct BudgetView: View {
    @State private var selectedCategoryToEdit: Category? = nil
    var workspace: Workspace
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest var categories: FetchedResults<Category>
    @State private var transactions: [Transaction] = []
    
    @State private var selectedMonth: Date = Date()
    @State private var isShowingAddCategorySheet: Bool = false
    
    init(workspace: Workspace) {
        self.workspace = workspace
        _categories = FetchRequest<Category>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
    }
    
    func loadTransactionsForMonth() {
        _ = Calendar.current
        let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "workspace == %@", workspace)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: true)]
        do {
            transactions = try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch transactions: \(error)")
            transactions = []
        }
    }
    
    var categorySpendingMap: [UUID: Double] {
        let calendar = Calendar.current
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return [:]
        }
        var map: [UUID: Double] = [:]
        for tx in transactions {
            guard let date = tx.date, date >= start && date < end,
                  let category = tx.category, category.isExpense, let id = category.id else { continue }
            map[id, default: 0.0] += tx.amount
        }
        return map
    }
    
    
    var totalBudget: Double { categories.reduce(0) { $0 + $1.monthlyBudget } }
    var totalSpent: Double { categorySpendingMap.values.reduce(0, +) }
    var totalRemaining: Double { totalBudget - totalSpent }
    var visibleCategories: [Category] {
        categories.filter { cat in
            let spent = cat.id.flatMap { categorySpendingMap[$0] } ?? 0.0
            return cat.monthlyBudget != 0 || spent != 0
        }
    }
    
    var monthPicker: some View {
        HStack(spacing: 12) {
            Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Text(selectedMonth, format: Date.FormatStyle().month().year())
                .font(.headline)
            Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newDate
            loadTransactionsForMonth()
        }
    }
    
    func categoryRow(for category: Category) -> some View {
        let id = category.id ?? UUID()
        let spent = categorySpendingMap[id] ?? 0.0
        let remaining = category.monthlyBudget - spent
        
        return NavigationLink(destination: TransactionsListView(workspace: workspace, filterCategory: category)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name ?? "Unnamed").font(.headline)
                    Spacer()
                    Image(systemName: remaining >= 0 ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(remaining >= 0 ? .green : .red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text("Budgeted:"); Spacer(); Text("Rollover:"); Spacer(); Text("Spent:"); Spacer(); Text("Remaining:") }
                        .font(.subheadline)
                    HStack {
                        Text(category.monthlyBudget, format: .currency(code: "USD")); Spacer()
                        Text(spent, format: .currency(code: "USD")); Spacer()
                        Text(remaining, format: .currency(code: "USD"))
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(8)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthPicker
                    .background(Color(.systemGray6))
                ZStack {
                    Color(.systemGray6).ignoresSafeArea()
                    List {
                        Section {
                            VStack(spacing: 4) {
                                HStack { Text("Total Monthly Budget:"); Spacer(); Text(totalBudget, format: .currency(code: "USD")).fontWeight(.bold) }
                                HStack { Text("Total Spent:"); Spacer(); Text(totalSpent, format: .currency(code: "USD")).fontWeight(.bold) }
                                HStack { Text("Total Remaining:"); Spacer(); Text(totalRemaining, format: .currency(code: "USD")).fontWeight(.bold) }
                            }
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        Section {
                            if visibleCategories.isEmpty {
                                Text("No categories yet. Add one!")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(visibleCategories) { category in
                                    categoryRow(for: category)
                                        .swipeActions(edge: .leading) {
                                            Button { selectedCategoryToEdit = category } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                }
                                .onDelete { offsets in
                                    offsets.forEach { idx in
                                        viewContext.delete(visibleCategories[idx])
                                    }
                                    try? viewContext.save()
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Monthly Budget")
    #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
    #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { isShowingAddCategorySheet = true }
                        .foregroundColor(.accentColor)
                }
            }
            .toolbarBackground(Color(.systemGray6), for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { loadTransactionsForMonth() }
            .sheet(isPresented: $isShowingAddCategorySheet) {
                AddCategoryView(workspace: workspace, isExpense: true, defaultName: "") { _ in }
            }
            .sheet(item: $selectedCategoryToEdit) { category in
                NavigationStack {
                    EditCategoryView(category: category)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
        .accentColor(Color("AccentColor"))
    }
}

extension Array where Element == DateComponents {
    func removingDuplicates() -> [DateComponents] {
        var seen: Set<String> = []
        return self.filter {
            let key = "\($0.year ?? 0)-\($0.month ?? 0)"
            return seen.insert(key).inserted
        }
    }
}

struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let previewWorkspace = Workspace(context: context)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"
        return NavigationStack {
            BudgetView(workspace: previewWorkspace)
                .environment(\.managedObjectContext, context)
        }
    }
}
