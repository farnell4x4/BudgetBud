//AddTransactionView.swift
//BudgetBud
//Update on 2025-04-29, 00:00

import SwiftUI
import CoreData

struct AddTransactionView: View {
    var workspace: Workspace  // Passed in workspace for scoping the transaction
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Filter accounts by workspace.
    @FetchRequest var accounts: FetchedResults<Account>
    @FetchRequest var categories: FetchedResults<Category>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Transaction.date, ascending: true)]
    ) private var transactions: FetchedResults<Transaction>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Merchant.name, ascending: true)]
    ) private var merchants: FetchedResults<Merchant>

    @AppStorage("defaultAccountID") private var defaultAccountID: String = ""
    @AppStorage("defaultCategoryID") private var defaultCategoryID: String = ""

    @State private var selectedDate: Date
    @State private var merchant: String
    @State private var amountText: String
    @State private var transactionType: TransactionType
    @State private var note: String = ""

    @State private var receivingAccountSearchText: String = ""
    @State private var selectedReceivingAccount: Account? = nil

    @State private var accountSearchText: String = ""
    @State private var showAccountDropdown: Bool = false
    @State private var selectedAccount: Account? = nil

    @State private var categorySearchText: String = ""
    @State private var showCategoryDropdown: Bool = false
    @State private var selectedCategory: Category? = nil

    @State private var incomeCategorySearchText: String = ""
    @State private var selectedIncomeCategory: Category? = nil

    @FocusState private var isAccountFieldFocused: Bool
    @FocusState private var isCategoryFieldFocused: Bool

    @State private var showAccountCreationSheet: Bool = false
    @State private var showCategoryCreationSheet: Bool = false

    @State private var receiptImage: MyPlatformImage? = nil
    @State private var isShowingScanner: Bool = false
    @State private var showScanReceiptSheet: Bool = false
    @State private var showFullReceipt: Bool = false

    @State private var isProcessingOCR: Bool = false
    @State private var receiptOCRText: String? = nil

    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAmountSuggestions: Bool = false
    @FocusState private var isAmountFieldFocused: Bool


    @State private var amountAlternatives: [Double] = []

    @State private var showSubscriptionPaywall: Bool = false

    init(
        workspace: Workspace,
        prefilledMerchant: String = "",
        prefilledAmount: Double? = nil,
        prefilledDate: Date = Date(),
        prefilledTransactionType: TransactionType = .expense,
        prefilledReceiptImage: MyPlatformImage? = nil,
        amountAlternatives: [Double] = [] // Clearly documented
    ) {
        self.workspace = workspace
        _merchant = State(initialValue: prefilledMerchant)
        _amountText = State(initialValue: prefilledAmount.map { String(format: "%.2f", $0) } ?? "")
        _selectedDate = State(initialValue: prefilledDate)
        _transactionType = State(initialValue: prefilledTransactionType)
        _receiptImage = State(initialValue: prefilledReceiptImage)
        _amountAlternatives = State(initialValue: amountAlternatives)

        _accounts = FetchRequest<Account>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
        _categories = FetchRequest<Category>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", workspace)
        )
    }


    var body: some View {
        NavigationStack {
            Form {
                transactionDetailsSection
                receiptSection
            }
            .navigationTitle("Add Transaction")
            .toolbar {//Ambiguous use of 'toolbar(content:)'
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveTransaction() }
                }
            }
            .onAppear(perform: setupDefaults)
            
            
            
            .sheet(isPresented: $showAccountCreationSheet) {
                AddAccountView(workspace: workspace, defaultName: accountSearchText) { newAccount in
                    selectedAccount = newAccount
                    accountSearchText = newAccount.name ?? ""
                    defaultAccountID = newAccount.id?.uuidString ?? ""
                    showAccountCreationSheet = false
                }
                .environment(\.managedObjectContext, viewContext)
            }
            
            
            .sheet(isPresented: $showCategoryCreationSheet) {
                AddCategoryView(
                    workspace: workspace,
                    isExpense: (transactionType == .expense || transactionType == .refund),
                    defaultName: categorySearchText
                ) { newCategory in
                    selectedCategory = newCategory
                    categorySearchText = newCategory.name ?? ""
                    defaultCategoryID = newCategory.id?.uuidString ?? ""
                    showCategoryCreationSheet = false
                }
                .environment(\.managedObjectContext, viewContext)
            }
            




            
        }
    }

    var transactionDetailsSection: some View {
        Section {
            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(CompactDatePickerStyle())
            transactionTypePicker

            if transactionType != .transfer {
                TextField(transactionType == .income ? "Payer" : "Merchant", text: $merchant)
            }

            
            VStack(alignment: .leading) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.numberPad)                   // only once
                    .focused($isAmountFieldFocused)             // only once
                    .onChange(of: amountText) { newValue in     // auto-decimal formatting
                        let digits = newValue.filter { $0.isNumber }
                        if let cents = Double(digits), !digits.isEmpty {
                            amountText = String(format: "%.2f", cents / 100)
                        } else {
                            amountText = ""
                        }
                    }
                    .onTapGesture {                             // show suggestions on tap
                        amountText = ""
                        showAmountSuggestions = true
                    }
                    .onChange(of: isAmountFieldFocused) { focused in  // show suggestions when focus arrives
                        if focused {
                            amountText = ""
                            showAmountSuggestions = true
                        }
                    }

                
                
                

                if showAmountSuggestions && !amountAlternatives.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(amountAlternatives, id: \.self) { alt in
                                Button {
                                    amountText = String(format: "%.2f", alt)
                                    showAmountSuggestions = false
                                } label: {
                                    Text(String(format: "%.2f", alt))
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }


            
            
            
            accountSearchSection

            if transactionType == .transfer {
                receivingAccountSection
            } else if transactionType == .income {
                incomeCategorySection
            } else {
                categorySearchSection
            }

            TextField("Note", text: $note)
        }
    }

    @ViewBuilder
    private func amountSuggestionButtons() -> some View {
        if showAmountSuggestions && !amountAlternatives.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(amountAlternatives.enumerated()), id: \.offset) { _, alt in
                        Button {
                            amountText = String(format: "%.2f", alt)
                            showAmountSuggestions = false
                        } label: {
                            Text(String(format: "%.2f", alt))
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }


    
    
    var transactionTypePicker: some View {
        VStack(alignment: .leading) {
            Text("Transaction Type")
                .font(.headline)
            Picker("", selection: $transactionType) {
                ForEach(TransactionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    var accountSearchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search Account", text: $accountSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isAccountFieldFocused)
                .onChange(of: isAccountFieldFocused) { focused in
                    if focused {
                        accountSearchText = ""
                        showAccountDropdown = true
                    }
                }
                .onChange(of: accountSearchText) { newValue in
                    if newValue.isEmpty {
                        showAccountDropdown = true
                    }
                }
            Group {
                if showAccountDropdown {
                    ForEach(Array(accounts), id: \.objectID) { account in
                        Button(action: {
                            selectedAccount = account
                            accountSearchText = account.name ?? ""
                            showAccountDropdown = false
                        }) {
                            Text(account.name ?? "")
                                .padding(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if !accountSearchText.isEmpty &&
                        !accounts.contains(where: { ($0.name ?? "").lowercased() == accountSearchText.lowercased() }) {
                        Button(action: {
                            showAccountCreationSheet = true
                        }) {
                            Text("+ Add \"\(accountSearchText)\"")
                                .padding(4)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            if let account = selectedAccount {
                Text("Selected: \(account.name ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    var categorySearchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search Category", text: $categorySearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isCategoryFieldFocused)
                .onChange(of: isCategoryFieldFocused) { focused in
                    if focused {
                        categorySearchText = ""
                        showCategoryDropdown = true
                    }
                }
                .onChange(of: categorySearchText) { newValue in
                    if newValue.isEmpty {
                        showCategoryDropdown = true
                    }
                }
            Group {
                if showCategoryDropdown {
                    ForEach(Array(categories.filter { $0.isExpense }), id: \.objectID) { category in
                        Button(action: {
                            selectedCategory = category
                            categorySearchText = category.name ?? ""
                            showCategoryDropdown = false
                        }) {
                            Text(category.name ?? "")
                                .padding(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if !categorySearchText.isEmpty &&
                        !categories.filter({ $0.isExpense }).contains(where: { ($0.name ?? "").lowercased() == categorySearchText.lowercased() }) {
                        Button(action: {
                            showCategoryCreationSheet = true
                        }) {
                            Text("+ Add \"\(categorySearchText)\"")
                                .padding(4)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            if let category = selectedCategory {
                Text("Selected: \(category.name ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    var incomeCategorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search Income Category", text: $incomeCategorySearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            ForEach(Array(categories.filter { !$0.isExpense }), id: \.objectID) { category in
                Button(action: {
                    selectedIncomeCategory = category
                    incomeCategorySearchText = category.name ?? ""
                }) {
                    Text(category.name ?? "")
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            if !incomeCategorySearchText.isEmpty &&
                       !categories.filter({ !$0.isExpense }).contains(where: { ($0.name ?? "").lowercased() == incomeCategorySearchText.lowercased() }) {
                       Button(action: {
                           showCategoryCreationSheet = true
                       }) {
                           Text("+ Add \"\(incomeCategorySearchText)\"")
                               .padding(4)
                               .foregroundColor(.blue)
                               .frame(maxWidth: .infinity, alignment: .leading)
                       }
                       .buttonStyle(PlainButtonStyle())
                   }
            if let incCategory = selectedIncomeCategory {
                Text("Selected: \(incCategory.name ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    var receivingAccountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Receiving Account", text: $receivingAccountSearchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onTapGesture {
                    receivingAccountSearchText = ""
                }
            ForEach(Array(accounts), id: \.objectID) { account in
                Button(action: {
                    selectedReceivingAccount = account
                    receivingAccountSearchText = account.name ?? ""
                }) {
                    Text(account.name ?? "")
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            if let rAccount = selectedReceivingAccount {
                Text("Selected Receiving Account: \(rAccount.name ?? "")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    var receiptSection: some View {
        Section {
            Button(action: {
                #if os(iOS)
                showScanReceiptSheet = true // ← explicit fix here
                #else
                print("Scanner not available on this platform.")
                #endif
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan Receipt")
                }
            }
            if let image = receiptImage {
                #if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                #elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                #endif
            }
        }
    }

    
    private func setupDefaults() {
        if selectedAccount == nil {
            if let defaultID = UUID(uuidString: defaultAccountID),
               let def = accounts.first(where: { $0.id == defaultID }) {
                selectedAccount = def
                accountSearchText = def.name ?? ""
            } else if let first = accounts.first {
                selectedAccount = first
                accountSearchText = first.name ?? ""
                defaultAccountID = first.id?.uuidString ?? ""
            }
        }
        if transactionType != .income, selectedCategory == nil {
            if let defaultCatID = UUID(uuidString: defaultCategoryID),
               let defCat = categories.first(where: { $0.id == defaultCatID }) {
                selectedCategory = defCat
                categorySearchText = defCat.name ?? ""
            } else if let first = categories.first(where: { $0.isExpense }) {
                selectedCategory = first
                categorySearchText = first.name ?? ""
                defaultCategoryID = first.id?.uuidString ?? ""
            }
        }
        if transactionType == .income, selectedIncomeCategory == nil {
            if let first = categories.first(where: { !$0.isExpense }) {
                selectedIncomeCategory = first
                incomeCategorySearchText = first.name ?? ""
            }
        }
    }
    
   

    
    private func saveTransaction() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
       

        
        guard (transactionType == .transfer || !merchant.trimmingCharacters(in: .whitespaces).isEmpty) else {
            showValidationError("Please enter a payer.")
            return
        }
        guard let amountValue = Double(amountText), amountValue > 0 else {
            showValidationError("Please enter a valid amount.")
            return
        }
        guard let sendingAccount = selectedAccount else {
            showValidationError("Please select an account.")
            return
        }
        
        var transaction: Transaction
        
        if transactionType == .income {
            transaction = Transaction(context: viewContext)
            transaction.workspace = workspace
            workspace.addToTransaction(transaction)
            transaction.id = UUID()
            transaction.payer = merchant
            transaction.date = selectedDate
            transaction.amount = amountValue
            transaction.typeRaw = TransactionType.income.rawValue
            transaction.category = selectedIncomeCategory
            transaction.account = sendingAccount
            transaction.note = note
            sendingAccount.balance += amountValue
        } else if transactionType == .transfer {
            transaction = Transaction(context: viewContext)
            transaction.workspace = workspace
            workspace.addToTransaction(transaction)
            transaction.id = UUID()
            transaction.merchant = ""
            transaction.date = selectedDate
            transaction.amount = amountValue
            transaction.typeRaw = TransactionType.transfer.rawValue
            transaction.category = nil
            transaction.account = sendingAccount
            transaction.receivingAccount = selectedReceivingAccount
            transaction.note = note
            sendingAccount.balance -= amountValue
            selectedReceivingAccount?.balance += amountValue
        } else {
            transaction = Transaction(context: viewContext)
            transaction.workspace = workspace
            workspace.addToTransaction(transaction)
            transaction.id = UUID()
            transaction.merchant = merchant
            transaction.date = selectedDate
            transaction.amount = amountValue
            transaction.typeRaw = transactionType.rawValue
            transaction.category = selectedCategory
            transaction.account = sendingAccount
            transaction.note = note
            switch transactionType {
            case .expense:
                sendingAccount.balance -= amountValue
                selectedCategory?.actualSpent += amountValue
            case .refund:
                sendingAccount.balance += amountValue
                selectedCategory?.actualSpent -= amountValue
            default:
                break
            }
        }
        
        if let image = receiptImage, let imageData = image.jpegData(compressionQuality: 1.0) {
            let receipt = Receipt(context: viewContext)
            receipt.id = UUID()
            receipt.timestamp = Date()
            receipt.imageData = imageData
            receipt.transaction = transaction
            transaction.receipt = receipt
            viewContext.insert(receipt)
        }
        
        
        do {
            try viewContext.save()
            defaultAccountID = sendingAccount.id?.uuidString ?? ""
            if transactionType != .income && transactionType != .transfer, let cat = selectedCategory {
                defaultCategoryID = cat.id?.uuidString ?? ""
            }
            dismiss()
        } catch {
            alertMessage = "Failed to save transaction: \(error)"
            showValidationError(alertMessage)
        }
    }
    
    private func showValidationError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct AddTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let previewWorkspace = Workspace(context: context)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"

        return NavigationStack {
            AddTransactionView(workspace: previewWorkspace)
                .environment(\.managedObjectContext, context)
        }
    }
}
