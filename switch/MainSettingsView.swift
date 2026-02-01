//
//  MainSettingsView.swift
//  Switch
//
//  Created by Andrey Nikonorov on 01.02.2026.
//

import SwiftUI
import ServiceManagement

struct MainSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var launchAtLogin: Bool = false
    @State private var lightModeTime: Date = Date()
    @State private var darkModeTime: Date = Date()
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var selectedTheme: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Theme Section
            themeSection
            
            Divider()
            
            // Settings Section
            settingsSection
            
            Divider()
            
            // Schedule Section
            scheduleSection
            
            Divider()
                .padding(.top, 8)
            
            // Footer
            footerSection
        }
        .padding(20)
        .fixedSize()
        .onAppear(perform: loadCurrentState)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Theme
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(.headline)
            
            Picker("", selection: $selectedTheme) {
                Text("Light").tag(0)
                Text("Dark").tag(1)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .onChange(of: selectedTheme) { _, newValue in
                themeManager.setDarkMode(newValue == 1)
            }
        }
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                
                Toggle("Show this window on launch", isOn: $themeManager.showWindowOnLaunch)
                    .toggleStyle(.checkbox)
            }
        }
    }
    
    // MARK: - Schedule
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Schedule")
                .font(.headline)
            
            Toggle("Auto-switch theme", isOn: $themeManager.scheduleEnabled)
                .toggleStyle(.checkbox)
            
            if themeManager.scheduleEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Light at")
                        DatePicker("", selection: $lightModeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: lightModeTime) { _, newValue in
                                themeManager.setLightModeDate(newValue)
                            }
                    }
                    
                    HStack {
                        Text("Dark at")
                        DatePicker("", selection: $darkModeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: darkModeTime) { _, newValue in
                                themeManager.setDarkModeDate(newValue)
                            }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            
            Spacer()
            
            Text("v0.0.1")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentState() {
        launchAtLogin = getLaunchAtLoginStatus()
        lightModeTime = themeManager.getLightModeDate()
        darkModeTime = themeManager.getDarkModeDate()
        selectedTheme = themeManager.isDarkMode() ? 1 : 0
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled
            errorMessage = "Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func getLaunchAtLoginStatus() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}

#Preview {
    MainSettingsView()
}
