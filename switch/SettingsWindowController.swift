//
//  SettingsWindowController.swift
//  Switch
//
//  Created by Andrey Nikonorov on 01.02.2026.
//

import Cocoa
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func showWindow() {
        // Show in Dock when window opens
        NSApp.setActivationPolicy(.regular)
        
        if let existingWindow = window {
            existingWindow.center()
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = MainSettingsView()
        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Switch"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        
        window = newWindow
    }
    
    func closeWindow() {
        window?.close()
    }
    
    // MARK: - NSWindowDelegate
    
    nonisolated func windowWillClose(_ notification: Notification) {
        // Hide from Dock when window closes
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
