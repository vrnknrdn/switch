//
//  SwitchApp.swift
//  Switch
//
//  Created by Andrey Nikonorov on 31.01.2026.
//

import SwiftUI

@main
struct SwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
