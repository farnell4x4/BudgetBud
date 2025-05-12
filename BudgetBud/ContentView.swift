
//ContentView.swift
//BudgetBud
//Update on 2025-04-23, 22:00

import SwiftUI
import CoreData

struct ContentView: View {
    @AppStorage("selectedWorkspaceID") private var selectedWorkspaceID: String?
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Workspace.name, ascending: true)],
        animation: .default
    ) private var allWorkspaces: FetchedResults<Workspace>

    @State private var selectedTab = 0

    // Receipt scanning states
    @State private var showReceiptScanner = false
    @State private var showAddTransactionFromScan = false
    @State private var isProcessingOCR = false
    @State private var prefilledMerchant: String = ""
    @State private var prefilledAmount: Double? = nil
    
    @State private var prefilledDate: Date = Date()
    @State private var scannedReceiptImage: MyPlatformImage? = nil

    private var selectedWorkspace: Workspace? {
        guard let idString = selectedWorkspaceID, let uuid = UUID(uuidString: idString),
              let workspace = allWorkspaces.first(where: { $0.id == uuid }) else {
            return nil
        }
        return workspace
    }

    var body: some View {
        Group {
            if let workspace = selectedWorkspace {
                MainTabs(workspace: workspace)
            } else {
                WorkspaceOnboardingView(onWorkspaceCreated: { newWorkspace in
                    selectedWorkspaceID = newWorkspace.id?.uuidString
                })
            }
        }
    }
}

struct MainTabs: View {
    var workspace: Workspace
    @State private var selectedTab = 0
    @State private var showReceiptScanner = false
    @State private var showAddTransactionFromScan = false
    @State private var isProcessingOCR = false
    @State private var prefilledMerchant: String = ""
    @State private var prefilledAmount: Double? = nil
    @State private var prefilledDate: Date = Date()
    @State private var scannedReceiptImage: MyPlatformImage? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @State private var amountAlternatives: [Double] = []
    @State private var keyboardVisible = false



    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationView {
                    AccountsView(workspace: workspace)
                }
                .navigationViewStyle(.stack)
                .tabItem { Label("Accounts", systemImage: "creditcard") }
                .tag(0)

                NavigationView {
                    BudgetView(workspace: workspace)
                }
                .navigationViewStyle(.stack)
                .tabItem { Label("Budget", systemImage: "chart.pie") }
                .tag(1)

                NavigationView {
                    TransactionsListView(workspace: workspace)
                }
                .navigationViewStyle(.stack)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle.portrait") }
                .tag(2)

                NavigationView {
                    SettingsView()
                }
                .navigationViewStyle(.stack)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
            }

            .accentColor(Color("AccentColor"))

        }
        
        // observe both willShow/didShow and willHide/didHide notifications
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    keyboardVisible = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    keyboardVisible = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardVisible = false
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
                    keyboardVisible = false
                }
        .sheet(isPresented: $showAddTransactionFromScan) {
            AddTransactionView(
                workspace: workspace,
                prefilledMerchant: prefilledMerchant,
                prefilledAmount: prefilledAmount,
                prefilledDate: prefilledDate,
                prefilledTransactionType: .expense,
                prefilledReceiptImage: scannedReceiptImage,
                amountAlternatives: amountAlternatives 
            )
        }
    }
}
