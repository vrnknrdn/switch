//
//  AppDelegate.swift
//  Switch
//
//  Created by Andrey Nikonorov on 31.01.2026.
//

import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the status bar controller
        statusBarController = StatusBarController()
        
        // Start the theme scheduler
        ThemeManager.shared.startScheduler()
        
        // Show settings window on launch if enabled
        if ThemeManager.shared.showWindowOnLaunch {
            SettingsWindowController.shared.showWindow()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ThemeManager.shared.stopScheduler()
    }
}
