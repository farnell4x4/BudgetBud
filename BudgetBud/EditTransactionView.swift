//EditTransactionView.swift
//BudgetBud
//Update on 2025-04-09, 11:05
import SwiftUI
import CoreData

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @AppStorage("defaultAccountID") private var defaultAccountID: String = ""
    @AppStorage("defaultCategoryID") private var defaultCategoryID: String = ""

    var transaction: Transaction

    @State private var merchant: String
    @State private var amountText: String
    @State private var note: String
    @State private var selectedDate: Date
    @State private var transactionType: TransactionType

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

    @State private var showAccountCreationSheet: Bool = false
    @State private var showCategoryCreationSheet: Bool = false

    @State private var showFullReceipt: Bool = false
    
    
    @State private var showEditScanReceiptSheet: Bool = false
    
    
    @State private var isShowingScanner: Bool = false

    @State private var receiptImage: MyPlatformImage? = nil

    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @State private var isProcessingOCR: Bool = false
    @State private var receiptOCRText: String? = nil
    
    @FocusState private var isAccountFieldFocused: Bool
    @FocusState private var isCategoryFieldFocused: Bool

    @FetchRequest(
           sortDescriptors: [NSSortDescriptor(keyPath: \Merchant.name, ascending: true)]
       ) private var merchants: FetchedResults<Merchant>
       
       @FetchRequest(
           sortDescriptors: [NSSortDescriptor(keyPath: \Account.name, ascending: true)]
       ) private var accounts: FetchedResults<Account>

       // 🔒 Scope categories to the transaction's workspace
       @FetchRequest var categories: FetchedResults<Category>

    init(transaction: Transaction) {
        self.transaction = transaction

        _categories = FetchRequest<Category>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
            predicate: NSPredicate(format: "workspace == %@", transaction.workspace ?? Workspace())
        )

        _merchant = State(initialValue: transaction.merchant ?? "")
        _amountText = State(initialValue: String(format: "%.2f", transaction.amount))
        _note = State(initialValue: transaction.note ?? "")
        _selectedDate = State(initialValue: transaction.date ?? Date())
        _transactionType = State(initialValue: TransactionType(rawValue: transaction.typeRaw ?? "expense") ?? .expense)
        _selectedAccount = State(initialValue: transaction.account)
        _selectedCategory = State(initialValue: transaction.category)

        if let rAcc = transaction.receivingAccount {
            _selectedReceivingAccount = State(initialValue: rAcc)
            _receivingAccountSearchText = State(initialValue: rAcc.name ?? "")
        }

        if _transactionType.wrappedValue == .income {
            _selectedIncomeCategory = State(initialValue: transaction.category)
            _incomeCategorySearchText = State(initialValue: transaction.category?.name ?? "")
        } else {
            _selectedIncomeCategory = State(initialValue: nil)
            _incomeCategorySearchText = State(initialValue: "")
        }

        _accountSearchText = State(initialValue: transaction.account?.name ?? "")
        _categorySearchText = State(initialValue: transaction.category?.name ?? "")

        if let receipt = transaction.receipt, let data = receipt.imageData {
            #if canImport(UIKit)
            _receiptImage = State(initialValue: UIImage(data: data))
            #elseif canImport(AppKit)
            _receiptImage = State(initialValue: NSImage(data: data))
            #endif
        } else {
            _receiptImage = State(initialValue: nil)
        }
    }

    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(CompactDatePickerStyle())
                    transactionTypePicker
                    if transactionType != .transfer {
                        TextField(transactionType == .income ? "Payer" : "Merchant", text: $merchant)
                    }
                    TextField("Amount", text: $amountText)
                                            .keyboardType(.numberPad)
                                            .onChange(of: amountText) { newValue in
                                                let digits = newValue.filter { $0.isNumber }
                                                if let cents = Double(digits), !digits.isEmpty {
                                                    amountText = String(format: "%.2f", cents / 100)
                                                } else {
                                                    amountText = ""
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
                Section {
                    if let image = receiptImage {
                        Button(action: {
                            showFullReceipt = true
                        }) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                        }
                    } else {
                        Button(action: {
                            showEditScanReceiptSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.square")
                                Text("Add Image")
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { updateTransaction() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            

            .sheet(isPresented: $showFullReceipt) {
                if let receipt = transaction.receipt {
                    ReceiptDetailView(receipt: receipt)
                }
            }
            .sheet(isPresented: $showAccountCreationSheet) {
                AddAccountView(workspace: transaction.account?.workspace ?? Workspace(context: viewContext), defaultName: accountSearchText, onSave: { newAccount in
                    DispatchQueue.main.async {
                        selectedAccount = newAccount
                        accountSearchText = newAccount.name ?? ""
                        defaultAccountID = newAccount.id?.uuidString ?? ""
                        showAccountCreationSheet = false
                    }
                })
            }
            .sheet(isPresented: $showCategoryCreationSheet) {
                AddCategoryView(workspace: transaction.workspace!, isExpense: (transactionType == .expense || transactionType == .refund), defaultName: categorySearchText) { newCategory in
                    DispatchQueue.main.async {
                        selectedCategory = newCategory
                        defaultCategoryID = newCategory.id?.uuidString ?? ""
                        categorySearchText = newCategory.name ?? ""
                        showCategoryCreationSheet = false
                    }
                }
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
                    ForEach(accounts.filter { accountSearchText.isEmpty || ($0.name ?? "").lowercased().contains(accountSearchText.lowercased()) }, id: \.id) { account in
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
                    ForEach(categories.filter { $0.isExpense && (categorySearchText.isEmpty || ($0.name ?? "").lowercased().contains(categorySearchText.lowercased())) }, id: \.id) { category in
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
            ForEach(categories.filter { !$0.isExpense && (incomeCategorySearchText.isEmpty || ($0.name ?? "").lowercased().contains(incomeCategorySearchText.lowercased())) }, id: \.id) { category in
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
            ForEach(accounts.filter { receivingAccountSearchText.isEmpty || ($0.name ?? "").lowercased().contains(receivingAccountSearchText.lowercased()) }, id: \.id) { account in
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
                isShowingScanner = true
                showEditScanReceiptSheet = true // ← explicit fix here
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
    
    private func updateTransaction() {
        let oldType: TransactionType = TransactionType(rawValue: transaction.typeRaw ?? "expense") ?? .expense
        if let oldAccount = transaction.account {
            switch oldType {
            case .expense:
                oldAccount.balance += transaction.amount
                transaction.category?.actualSpent -= transaction.amount
            case .income:
                oldAccount.balance -= transaction.amount
            case .refund:
                oldAccount.balance -= transaction.amount
                transaction.category?.actualSpent += transaction.amount
            case .transfer:
                oldAccount.balance += transaction.amount
                transaction.receivingAccount?.balance -= transaction.amount
            }
        }
        
        if transactionType == .income {
            transaction.typeRaw = TransactionType.income.rawValue
            transaction.category = selectedIncomeCategory
            transaction.receivingAccount = nil
            transaction.payer = merchant
        } else if transactionType == .transfer {
            transaction.typeRaw = TransactionType.transfer.rawValue
            transaction.category = nil
            transaction.payer = nil
            transaction.receivingAccount = selectedReceivingAccount
        } else {
            transaction.typeRaw = transactionType.rawValue
            transaction.category = selectedCategory
            transaction.payer = nil
            transaction.merchant = merchant  // ✅ ADD THIS
        }

        transaction.date = selectedDate
        transaction.amount = Double(amountText) ?? transaction.amount
        transaction.note = note
        transaction.account = selectedAccount
        
        if let sendingAccount = selectedAccount {
            switch transactionType {
            case .income:
                sendingAccount.balance += transaction.amount
            case .transfer:
                sendingAccount.balance -= transaction.amount
                selectedReceivingAccount?.balance += transaction.amount
            case .expense:
                sendingAccount.balance -= transaction.amount
                selectedCategory?.actualSpent += transaction.amount
            case .refund:
                sendingAccount.balance += transaction.amount
                selectedCategory?.actualSpent -= transaction.amount
            }
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            showValidationError("Failed to save transaction: \(error)")
        }
    }
    
    private func saveReceiptImage(_ image: MyPlatformImage) {
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            let receipt = Receipt(context: viewContext)
            receipt.id = UUID()
            receipt.timestamp = Date()
            receipt.imageData = imageData
            receipt.transaction = transaction
            transaction.receipt = receipt
            viewContext.insert(receipt)
            do {
                try viewContext.save()
                receiptImage = image
            } catch {
                print("Failed to save receipt: \(error)")
            }
        }
    }
    
    private func showValidationError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct EditTransactionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let previewWorkspace = Workspace(context: context)
        previewWorkspace.id = UUID()
        previewWorkspace.name = "Preview Workspace"
        return NavigationStack {
            EditTransactionView(transaction: Transaction(context: context))
                .environment(\.managedObjectContext, context)
        }
    }
}
