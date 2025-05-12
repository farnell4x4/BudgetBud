//
//  ReportView.swift
//  BudgetBud49,3
//
//  Created by Joshua Farnell on 4/21/25.
//


//ReportView.swift
//BudgetBud
//Update on 2025-04-11, 12:30
import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

// Removed PDF export option so that all exports are in CSV format.
enum ExportType: String, CaseIterable, Identifiable {
    case csv = "CSV"
    
    var id: String { self.rawValue }
}

struct ReportView: View {
    var workspace: Workspace
    @Environment(\.managedObjectContext) private var viewContext
    
    // Default dates: start date is one month ago; end date is today.
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    // Holds fetched transactions for the report.
    @State private var transactions: [Transaction] = []
    
    // Export share sheet state.
    @State private var exportedURL: URL?
    @State private var isShowingReportShareSheet: Bool = false
    
    // New state variable for export progress.
    @State private var isExporting: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Form {
                        Section(header: Text("Select Report Date Range")
                                    .font(.headline)
                                    .foregroundColor(.primary)) {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                            DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                        }
                        
                        Button("Generate Report") {
                            loadTransactions()
                        }
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if transactions.isEmpty {
                        Spacer()
                        Text("No records found for the selected date range.")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        // Display the detailed report in a horizontally scrollable table-like view.
                        ScrollView([.vertical, .horizontal]) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Header row.
                                HStack(spacing: 8) {
                                    Text("Date").fontWeight(.bold).frame(minWidth: 80, alignment: .leading)
                                    Divider()
                                    Text("Merchant/Payer").fontWeight(.bold).frame(minWidth: 120, alignment: .leading)
                                    Divider()
                                    Text("Account").fontWeight(.bold).frame(minWidth: 100, alignment: .leading)
                                    Divider()
                                    Text("Category").fontWeight(.bold).frame(minWidth: 100, alignment: .leading)
                                    Divider()
                                    Text("Type").fontWeight(.bold).frame(minWidth: 80, alignment: .leading)
                                    Divider()
                                    Text("Amount").fontWeight(.bold).frame(minWidth: 80, alignment: .trailing)
                                    Divider()
                                    Text("Note").fontWeight(.bold).frame(minWidth: 150, alignment: .leading)
                                    Divider()
                                    Text("Receiving").fontWeight(.bold).frame(minWidth: 120, alignment: .leading)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray5))
                                
                                Divider()
                                
                                // Data rows.
                                ForEach(transactions, id: \.objectID) { transaction in
                                    HStack(spacing: 8) {
                                        if let date = transaction.date {
                                            Text(date, style: .date)
                                                .frame(minWidth: 80, alignment: .leading)
                                        } else {
                                            Text("N/A").frame(minWidth: 80, alignment: .leading)
                                        }
                                        
                                        Divider()
                                        
                                        Text((transaction.typeRaw == TransactionType.income.rawValue ? (transaction.payer ?? "") : (transaction.merchant ?? "")) == "" ? "N/A" : (transaction.typeRaw == TransactionType.income.rawValue ? (transaction.payer ?? "") : (transaction.merchant ?? "N/A")))
                                            .frame(minWidth: 120, alignment: .leading)
                                        
                                        Divider()
                                        
                                        Text(transaction.account?.name ?? "N/A")
                                            .frame(minWidth: 100, alignment: .leading)
                                        
                                        Divider()
                                        
                                        Text(transaction.category?.name ?? "N/A")
                                            .frame(minWidth: 100, alignment: .leading)
                                        
                                        Divider()
                                        
                                        Text((transaction.typeRaw ?? "N/A").capitalized)
                                            .frame(minWidth: 80, alignment: .leading)
                                        
                                        Divider()
                                        
                                        Text(transaction.amount, format: .currency(code: "USD"))
                                            .frame(minWidth: 80, alignment: .trailing)
                                        
                                        Divider()
                                        
                                        Text(transaction.note ?? "")
                                            .frame(minWidth: 150, alignment: .leading)
                                        
                                        Divider()
                                        
                                        Text(transaction.receivingAccount?.name ?? "")
                                            .frame(minWidth: 120, alignment: .leading)
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        }
                        
                        // Instead of "Export Options" block, simply display the Export Report button.
                        Button("Export Report") {
                            exportReport()
                        }
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // Overlay progress view while exporting.
                if isExporting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        ProgressView("Generating Report...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Export Report")
        }
        .sheet(isPresented: $isShowingReportShareSheet) {
            if let url = exportedURL {
                ShareSheetWrapper(url: url)
            } else {
                Text("Failed to prepare export file.")
                    .padding()
            }
        }
    }
    
    // Loads transactions from Core Data for the given workspace within the selected date range.
    private func loadTransactions() {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let workspacePredicate = NSPredicate(format: "workspace == %@", workspace)
        let startPredicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        let endPredicate = NSPredicate(format: "date <= %@", endDate as NSDate)
        request.predicate = NSCompoundPredicate(type: .and, subpredicates: [workspacePredicate, startPredicate, endPredicate])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: true)]
        do {
            transactions = try viewContext.fetch(request)
        } catch {
            print("Error fetching transactions for report: \(error)")
            transactions = []
        }
    }
    
    // Exports transactions as CSV using a background thread and shows a progress overlay while generating.
    private func exportReport() {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = self.exportCSV() {
                DispatchQueue.main.async {
                    self.exportedURL = url
                    self.isExporting = false
                    self.isShowingReportShareSheet = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    print("Failed to create CSV file.")
                }
            }
        }
    }
    
    // Exports transactions as CSV to a temporary file.
    private func exportCSV() -> URL? {
        var csvText = "Date,Merchant/Payer,Account,Category,Type,Amount,Note,Receiving Account\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for transaction in transactions {
            let dateString = transaction.date != nil ? dateFormatter.string(from: transaction.date!) : "N/A"
            let merchant = transaction.typeRaw == TransactionType.income.rawValue ? (transaction.payer ?? "") : (transaction.merchant ?? "")
            let account = transaction.account?.name ?? "N/A"
            let category = transaction.category?.name ?? "N/A"
            let type = transaction.typeRaw?.capitalized ?? "N/A"
            let amount = String(format: "%.2f", transaction.amount)
            let note = transaction.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            let receiving = transaction.receivingAccount?.name ?? ""
            let newLine = "\"\(dateString)\",\"\(merchant)\",\"\(account)\",\"\(category)\",\"\(type)\",\"\(amount)\",\"\(note)\",\"\(receiving)\"\n"
            csvText.append(newLine)
        }
        
        let fileName = "Report_\(UUID().uuidString).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create CSV file: \(error)")
            return nil
        }
    }
}

struct ShareSheetWrapper: View {
    let provider: NSItemProvider
    
    init(url: URL) {
        guard let provider = NSItemProvider(contentsOf: url) else {
            fatalError("Unable to create NSItemProvider from URL: \(url)")
        }
        provider.suggestedName = url.lastPathComponent
        self.provider = provider
    }
    
    var body: some View {
        ShareSheet(activityItems: [provider])
    }
}

struct ReportView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let workspace = Workspace(context: context)
        workspace.id = UUID()
        workspace.name = "Preview Workspace"
        return NavigationStack {
            ReportView(workspace: workspace)
                .environment(\.managedObjectContext, context)
        }
    }
}
