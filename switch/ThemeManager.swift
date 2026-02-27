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
            if scheduleEnabled {
                lastAppliedTransitionDate = nil
                reschedule()
            } else {
                transitionTimer?.invalidate()
                transitionTimer = nil
            }
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
    
    private var transitionTimer: Timer?
    private var lastAppliedTransitionDate: Date?
    private var wakeObserver: Any?
    
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

        // Subscribe to wake-from-sleep notifications
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.reschedule()
            }
        }

        // Reschedule after a short delay (to allow permission dialog)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.reschedule()
        }
    }
    
    func stopScheduler() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }
    
    private func transitionTimes(for date: Date) -> [(date: Date, isDark: Bool)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let lightTime = calendar.date(byAdding: DateComponents(hour: lightModeHour, minute: lightModeMinute), to: startOfDay)!
        let darkTime = calendar.date(byAdding: DateComponents(hour: darkModeHour, minute: darkModeMinute), to: startOfDay)!
        return [(lightTime, false), (darkTime, true)]
    }

    private func mostRecentTransition(before date: Date) -> (date: Date, isDark: Bool)? {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        let candidates = transitionTimes(for: date) + transitionTimes(for: yesterday)
        return candidates
            .filter { $0.date <= date }
            .max(by: { $0.date < $1.date })
    }

    private func nextTransition(after date: Date) -> (date: Date, isDark: Bool)? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        let candidates = transitionTimes(for: date) + transitionTimes(for: tomorrow)
        return candidates
            .filter { $0.date > date }
            .min(by: { $0.date < $1.date })
    }

    private func reschedule() {
        transitionTimer?.invalidate()
        transitionTimer = nil

        guard scheduleEnabled else { return }

        let now = Date()

        // Apply missed transition if needed
        if let recent = mostRecentTransition(before: now) {
            if lastAppliedTransitionDate == nil || recent.date > lastAppliedTransitionDate! {
                if recent.isDark != isDarkMode() {
                    setDarkMode(recent.isDark)
                }
                lastAppliedTransitionDate = recent.date
            }
        }

        // Schedule one-shot timer for the next transition
        if let next = nextTransition(after: now) {
            let interval = max(next.date.timeIntervalSince(now), 0.1)
            let newTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.scheduleEnabled else { return }
                    if next.isDark != self.isDarkMode() {
                        self.setDarkMode(next.isDark)
                    }
                    self.lastAppliedTransitionDate = next.date
                    self.reschedule()
                }
            }
            RunLoop.main.add(newTimer, forMode: .common)
            transitionTimer = newTimer
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
        let newHour = calendar.component(.hour, from: date)
        let newMinute = calendar.component(.minute, from: date)
        guard newHour != lightModeHour || newMinute != lightModeMinute else { return }
        lightModeHour = newHour
        lightModeMinute = newMinute
        lastAppliedTransitionDate = nil
        reschedule()
    }
    
    func getDarkModeDate() -> Date {
        var components = DateComponents()
        components.hour = darkModeHour
        components.minute = darkModeMinute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    func setDarkModeDate(_ date: Date) {
        let calendar = Calendar.current
        let newHour = calendar.component(.hour, from: date)
        let newMinute = calendar.component(.minute, from: date)
        guard newHour != darkModeHour || newMinute != darkModeMinute else { return }
        darkModeHour = newHour
        darkModeMinute = newMinute
        lastAppliedTransitionDate = nil
        reschedule()
    }
}
