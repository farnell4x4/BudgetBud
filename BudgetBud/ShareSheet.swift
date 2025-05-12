//
//  ShareSheet.swift
//  BudgetBud49,3
//
//  Created by Joshua Farnell on 4/21/25.
//


//ShareSheet.swift
//BudgetBud
//Update on 2025-04-11, 10:25
import SwiftUI
#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update required.
    }
    
}
#endif
