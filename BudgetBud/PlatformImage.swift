//PlatformImage.swift
//BudgetBud
//Update on 2025-04-05, 20:45
#if canImport(UIKit)
import UIKit
public typealias MyPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias MyPlatformImage = NSImage
#endif
