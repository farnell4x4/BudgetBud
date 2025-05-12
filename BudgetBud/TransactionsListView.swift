// TransactionsListView.swift
// BudgetBud
// FINAL — Rebuilt for perfect tap-to-edit behavior (per-row NavigationLink), with swipe and select fixed on 2025-05-01, 17:15

import SwiftUI
import CoreData

enum TransactionType: String, CaseIterable, Identifiable {
    case income
    case expense
    case refund
    case transfer

    var id: String { self.rawValue }
    var displayName: String { self.rawValue.capitalized }
}

struct TransactionsListView: View {
    var workspace: Workspace
    let filterCategory: Category?

    @FetchRequest var transactions: FetchedResults<Transaction>
    @FetchRequest var accounts: FetchedResults<Account>
    @FetchRequest var categories: FetchedResults<Category>
    @FetchRequest var merchants: FetchedResults<Merchant>

    @Environment(\.managedObjectContext) private var viewContext

    @State private var searchText: String
    @State private var matchAll: Bool = true
    @State private var exactFilter: Bool
    @State private var showingAddTransactionSheet = false

    @State private var isSelecting: Bool = false
    @State private var selectedTransactionIDs: Set<NSManagedObjectID> = []

    @State private var showBulkActionDialog: Bool = false
    @State private var showBulkDeleteAlert: Bool = false

    @FocusState private var isSearchFocused: Bool

    init(workspace: Workspace, prefilledSearch: String = "", filterCategory: Category? = nil) {
        self.workspace = workspace
        self.filterCategory = filterCategory
        _searchText = State(initialValue: filterCategory?.name ?? prefilledSearch)
        _exactFilter = State(initialValue: filterCategory != nil)

        _transactions = FetchRequest<Transaction>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
        _accounts = FetchRequest<Account>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
        _categories = FetchRequest<Category>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
        _merchants = FetchRequest<Merchant>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Merchant.name, ascending: true)]
        )
    }

    private var filteredTransactions: [Transaction] {
        if exactFilter, let categoryFilter = filterCategory, let catID = categoryFilter.id {
            return transactions.filter { $0.category?.id == catID }
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(transactions)
        } else {
            let terms = searchText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return transactions.filter { tx in
                let typeString = (TransactionType(rawValue: tx.typeRaw ?? "")?.displayName.lowercased()) ?? ""
                let amountStr = String(tx.amount)
                let formattedAmount = String(format: "%.2f", tx.amount)
                let textComponents = [
                    (tx.merchant ?? "").lowercased(),
                    (tx.payer ?? "").lowercased(),
                    (tx.note ?? "").lowercased(),
                    (tx.category?.name ?? "").lowercased(),
                    (tx.account?.name ?? "").lowercased(),
                    typeString,
                    amountStr,
                    formattedAmount
                ]
                let termMatches = terms.map { term -> Bool in
                    if term.hasPrefix(">"), let threshold = Double(term.dropFirst()) {
                        return tx.amount > threshold
                    } else if term.hasPrefix("<"), let threshold = Double(term.dropFirst()) {
                        return tx.amount < threshold
                    } else {
                        return textComponents.contains { $0.contains(term.lowercased()) }
                    }
                }
                return matchAll ? termMatches.allSatisfy({ $0 }) : termMatches.contains(true)
            }
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { tx in
            Calendar.current.startOfDay(for: tx.date ?? Date())
        }
    }

    private var sortedSectionKeys: [Date] {
        groupedTransactions.keys.sorted(by: { $0 > $1 })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ZStack {
                    List {
                        ForEach(sortedSectionKeys, id: \.self) { sectionDate in
                            Section(header: Text(formattedDate(sectionDate))) {
                                ForEach(groupedTransactions[sectionDate] ?? []) { transaction in
                                    if isSelecting {
                                        Button(action: {
                                            let id = transaction.objectID
                                            if selectedTransactionIDs.contains(id) {
                                                selectedTransactionIDs.remove(id)
                                            } else {
                                                selectedTransactionIDs.insert(id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: selectedTransactionIDs.contains(transaction.objectID)
                                                      ? "checkmark.circle.fill"
                                                      : "circle")
                                                .foregroundColor(.accentColor)
                                                TransactionRow(transaction: transaction)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    } else {
                                        NavigationLink(destination: EditTransactionView(transaction: transaction)) {
                                            TransactionRow(transaction: transaction)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteTransaction(transaction)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .opacity(filteredTransactions.isEmpty ? 0 : 1)
                    .zIndex(0)

                    if isSearchFocused {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                UIApplication.shared.dismissKeyboard()
                                isSearchFocused = false
                            }
                            .zIndex(1)
                    }
                }
            }
            .background(Color(.systemGray6))

            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelecting {
                        Button("Cancel") {
                            isSelecting = false
                            selectedTransactionIDs.removeAll()
                        }
                        .foregroundColor(Color("AccentColor"))
                    } else if !searchText.isEmpty {
                        Button("Select All") {
                            isSelecting = true
                            selectedTransactionIDs = Set(filteredTransactions.map { $0.objectID })
                        }
                        .foregroundColor(Color("AccentColor"))
                    } else {
                        Button("Select") {
                            isSelecting = true
                        }
                        .foregroundColor(Color("AccentColor"))
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isSelecting {
                        Button(action: {
                            showBulkActionDialog = true
                        }) {
                            Image(systemName: "ellipsis.circle")
                        }
                        .foregroundColor(Color("AccentColor"))
                    }

                    Button("Add") {
                        showingAddTransactionSheet = true
                    }
                    .foregroundColor(Color("AccentColor"))
                }
            }
            .toolbarBackground(Color(.systemGray6), for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddTransactionSheet) {
                AddTransactionView(workspace: workspace)
                    .environment(\.managedObjectContext, viewContext)
            }
            .confirmationDialog("Bulk Actions", isPresented: $showBulkActionDialog, titleVisibility: .visible) {
                Button("Delete Selected", role: .destructive) {
                    showBulkDeleteAlert = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert(
                "Delete \(selectedTransactionIDs.count) transactions?",
                isPresented: $showBulkDeleteAlert
            ) {
                Button("Delete", role: .destructive) {
                    let selectedTxs = selectedTransactionIDs
                        .compactMap { viewContext.object(with: $0) as? Transaction }
                    isSelecting = false
                    selectedTransactionIDs.removeAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete the selected transactions and update balances accordingly.")
            }
        }
        .accentColor(Color("AccentColor"))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func deleteTransaction(_ tx: Transaction) {
        if let sending = tx.account {
            let txType = TransactionType(rawValue: tx.typeRaw ?? "expense") ?? .expense
            switch txType {
            case .transfer:
                sending.balance += tx.amount
                tx.receivingAccount?.balance -= tx.amount
            case .expense:
                sending.balance += tx.amount
                tx.category?.actualSpent -= tx.amount
            case .refund:
                sending.balance -= tx.amount
                tx.category?.actualSpent += tx.amount
            case .income:
                sending.balance -= tx.amount
            }
        }
        viewContext.delete(tx)
        try? viewContext.save()
    }
}

struct TransactionRow: View {
    @ObservedObject var transaction: Transaction

    private var txType: TransactionType {
        TransactionType(rawValue: transaction.typeRaw ?? "expense") ?? .expense
    }

    private var titleText: String {
        switch txType {
        case .income:
            return transaction.payer ?? "Income"
        case .transfer:
            let fromName = transaction.account?.name ?? "Unknown"
            let toName = transaction.receivingAccount?.name ?? "Unknown"
            return "\(fromName) to \(toName)"
        default:
            return transaction.merchant ?? "Transaction"
        }
    }

    private var subtitleText: String? {
        switch txType {
        case .income, .transfer:
            return nil
        default:
            return transaction.category?.name
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(titleText)
                        .font(.headline)
                    Text("(\(txType.displayName))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}
