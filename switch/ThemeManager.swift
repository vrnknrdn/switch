//
//  ThemeManager.swift
//  Switch
//
//  Created by Andrey Nikonorov on 31.01.2026.
//

import Foundation
import Cocoa
import Combine

// MARK: - Constants

enum UserDefaultsKeys {
    static let scheduleEnabled = "scheduleEnabled"
    static let lightModeHour = "lightModeHour"
    static let lightModeMinute = "lightModeMinute"
    static let darkModeHour = "darkModeHour"
    static let darkModeMinute = "darkModeMinute"
    static let showWindowOnLaunch = "showWindowOnLaunch"
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

// MARK: - ThemeManager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var scheduleEnabled: Bool {
        didSet {
            UserDefaults.standard.set(scheduleEnabled, forKey: UserDefaultsKeys.scheduleEnabled)
        }
    }
    
    @Published var lightModeHour: Int {
        didSet {
            UserDefaults.standard.set(lightModeHour, forKey: UserDefaultsKeys.lightModeHour)
        }
    }
    
    @Published var lightModeMinute: Int {
        didSet {
            UserDefaults.standard.set(lightModeMinute, forKey: UserDefaultsKeys.lightModeMinute)
        }
    }
    
    @Published var darkModeHour: Int {
        didSet {
            UserDefaults.standard.set(darkModeHour, forKey: UserDefaultsKeys.darkModeHour)
        }
    }
    
    @Published var darkModeMinute: Int {
        didSet {
            UserDefaults.standard.set(darkModeMinute, forKey: UserDefaultsKeys.darkModeMinute)
        }
    }
    
    @Published var showWindowOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(showWindowOnLaunch, forKey: UserDefaultsKeys.showWindowOnLaunch)
        }
    }
    
    private var timer: Timer?
    
    private init() {
        // Load saved settings or use defaults
        self.scheduleEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.scheduleEnabled)
        self.lightModeHour = UserDefaults.standard.object(forKey: UserDefaultsKeys.lightModeHour) as? Int ?? 7
        self.lightModeMinute = UserDefaults.standard.object(forKey: UserDefaultsKeys.lightModeMinute) as? Int ?? 0
        self.darkModeHour = UserDefaults.standard.object(forKey: UserDefaultsKeys.darkModeHour) as? Int ?? 19
        self.darkModeMinute = UserDefaults.standard.object(forKey: UserDefaultsKeys.darkModeMinute) as? Int ?? 0
        // Default to true for first launch
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.showWindowOnLaunch) == nil {
            self.showWindowOnLaunch = true
        } else {
            self.showWindowOnLaunch = UserDefaults.standard.bool(forKey: UserDefaultsKeys.showWindowOnLaunch)
        }
    }
    
    // MARK: - Theme Control
    
    func toggleTheme() {
        let newMode = !isDarkMode()
        setDarkMode(newMode)
    }
    
    func setDarkMode(_ enabled: Bool) {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled ? "true" : "false")
            end tell
        end tell
        """
        
        runOsascriptAsync(script) { [weak self] in
            Task { @MainActor in
                NotificationCenter.default.post(name: .themeDidChange, object: nil)
                self?.objectWillChange.send()
            }
        }
    }
    
    func isDarkMode() -> Bool {
        // Check actual system appearance
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    
    private nonisolated func runOsascriptAsync(_ script: String, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                        print("osascript error: \(errorString)")
                    }
                }
            } catch {
                print("Failed to run osascript: \(error)")
            }
            
            completion?()
        }
    }
    
    // MARK: - Permissions
    
    func requestPermissions() {
        // This will trigger the permission dialog if not already granted
        let script = """
        tell application "System Events"
            return name
        end tell
        """
        runOsascriptAsync(script)
    }
    
    // MARK: - Scheduler
    
    func startScheduler() {
        // Request permissions on first launch
        requestPermissions()
        
        // Check schedule after a short delay (to allow permission dialog)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.checkAndApplySchedule()
        }
        
        // Then check every minute
        let newTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkAndApplySchedule()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    func stopScheduler() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkAndApplySchedule() {
        guard scheduleEnabled else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        let lightTimeInMinutes = lightModeHour * 60 + lightModeMinute
        let darkTimeInMinutes = darkModeHour * 60 + darkModeMinute
        
        let shouldBeDark: Bool
        
        if lightTimeInMinutes < darkTimeInMinutes {
            // Normal case: light time is before dark time (e.g., 7:00 - 19:00)
            shouldBeDark = currentTimeInMinutes < lightTimeInMinutes || currentTimeInMinutes >= darkTimeInMinutes
        } else {
            // Inverted case: dark time is before light time (e.g., 22:00 - 6:00)
            shouldBeDark = currentTimeInMinutes >= darkTimeInMinutes && currentTimeInMinutes < lightTimeInMinutes
        }
        
        let currentlyDark = isDarkMode()
        
        if shouldBeDark != currentlyDark {
            setDarkMode(shouldBeDark)
        }
    }
    
    // MARK: - Helper for Date Picker
    
    func getLightModeDate() -> Date {
        var components = DateComponents()
        components.hour = lightModeHour
        components.minute = lightModeMinute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    func setLightModeDate(_ date: Date) {
        let calendar = Calendar.current
        lightModeHour = calendar.component(.hour, from: date)
        lightModeMinute = calendar.component(.minute, from: date)
    }
    
    func getDarkModeDate() -> Date {
        var components = DateComponents()
        components.hour = darkModeHour
        components.minute = darkModeMinute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    func setDarkModeDate(_ date: Date) {
        let calendar = Calendar.current
        darkModeHour = calendar.component(.hour, from: date)
        darkModeMinute = calendar.component(.minute, from: date)
    }
}
