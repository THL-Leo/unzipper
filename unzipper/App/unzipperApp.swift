//
//  ArchiveExtractorApp.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import SwiftUI

@main
struct unzipperApp: App {
    // MARK: - App State
    @StateObject private var preferences = UserPreferences.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferences)
                .frame(minWidth: 600, minHeight: 450)
                .onAppear {
                    setupAppearance()
                    setInitialWindowSize()
                }
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open Archive...") {
                    // This could trigger the file importer
                    // For now, we'll let the UI handle it
                }
                .keyboardShortcut("o")
            }
            
            CommandGroup(after: .toolbar) {
                Button("Clear Selection") {
                    // This would need to be passed to the view model
                    // Implementation would require a more complex setup
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAppearance() {
        // Configure app appearance
        #if os(macOS)
        // macOS specific appearance setup
        NSApp.appearance = NSAppearance(named: .aqua)
        #endif
    }
    private func setInitialWindowSize() {
            #if os(macOS)
            // Set initial window size using AppKit
            DispatchQueue.main.async {
                if let window = NSApp.windows.first {
                    window.setContentSize(NSSize(width: 600, height: 450))
                    window.center()
                }
            }
            #endif
        }
}

// MARK: - App Configuration Extension
extension unzipperApp {
    /// Handles URL schemes if you want to support opening archives via URL
    func handleURL(_ url: URL) {
        // Future implementation for handling file URLs passed to the app
        print("Received URL: \(url)")
    }
}
