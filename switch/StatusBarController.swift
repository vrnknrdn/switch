//
//  StatusBarController.swift
//  Switch
//
//  Created by Andrey Nikonorov on 31.01.2026.
//

import Cocoa
import SwiftUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    
    init() {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        // Configure the button
        if let button = statusItem.button {
            button.image = createMenuBarIcon(isOn: false)
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Update icon after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateIcon()
        }
        
        // Subscribe to theme changes to update icon
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
        
        // Also observe system appearance changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            SettingsWindowController.shared.showWindow()
        } else {
            ThemeManager.shared.toggleTheme()
        }
    }
    
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let isDarkMode = ThemeManager.shared.isDarkMode()
        button.image = createMenuBarIcon(isOn: isDarkMode)
    }
    
    /// Creates a light switch icon for the menu bar
    /// - Parameter isOn: true = switch down (dark mode), false = switch up (light mode)
    private func createMenuBarIcon(isOn: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let lineWidth: CGFloat = 1.5
            
            // Switch plate (more square, like a light switch)
            let plateWidth: CGFloat = 12
            let plateHeight: CGFloat = 14
            let plateX = (18 - plateWidth) / 2
            let plateY = (18 - plateHeight) / 2
            let plateRect = NSRect(x: plateX, y: plateY, width: plateWidth, height: plateHeight)
            let platePath = NSBezierPath(roundedRect: plateRect, xRadius: 2.5, yRadius: 2.5)
            platePath.lineWidth = lineWidth
            NSColor.black.setStroke()
            platePath.stroke()
            
            // Switch toggle (the rocker part)
            let toggleWidth: CGFloat = 8
            let toggleHeight: CGFloat = 5
            let toggleX = (18 - toggleWidth) / 2
            
            // Position: up for light (off), down for dark (on)
            let toggleY: CGFloat = isOn ? plateY + 2 : plateY + plateHeight - toggleHeight - 2
            let toggleRect = NSRect(x: toggleX, y: toggleY, width: toggleWidth, height: toggleHeight)
            let togglePath = NSBezierPath(roundedRect: toggleRect, xRadius: 1.5, yRadius: 1.5)
            NSColor.black.setFill()
            togglePath.fill()
            
            return true
        }
        
        image.isTemplate = true
        return image
    }
    
    @objc private func themeDidChange() {
        updateIcon()
    }
    
    @objc private func systemAppearanceDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateIcon()
        }
    }
}
