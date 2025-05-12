//
//  Helper.swift
//  BudgetBud
//
//  Created by Joshua Farnell on 4/23/25.
//

import Foundation
import UIKit

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
