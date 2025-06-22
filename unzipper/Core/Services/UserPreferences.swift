//
//  UserPreferences.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation
import SwiftUI

// MARK: - User Preferences
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let lastExtractionPath = "lastExtractionPath"
        static let autoOpenAfterExtraction = "autoOpenAfterExtraction"
        static let windowFrame = "windowFrame"
        static let showExtractionProgress = "showExtractionProgress"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }
    
    // MARK: - Published Properties
    @Published var lastExtractionPath: String? {
        didSet {
            defaults.set(lastExtractionPath, forKey: Keys.lastExtractionPath)
        }
    }
    
    @Published var autoOpenAfterExtraction: Bool {
        didSet {
            defaults.set(autoOpenAfterExtraction, forKey: Keys.autoOpenAfterExtraction)
        }
    }
    
    @Published var showExtractionProgress: Bool {
        didSet {
            defaults.set(showExtractionProgress, forKey: Keys.showExtractionProgress)
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load saved preferences
        self.lastExtractionPath = defaults.string(forKey: Keys.lastExtractionPath)
        self.autoOpenAfterExtraction = defaults.bool(forKey: Keys.autoOpenAfterExtraction)
        self.showExtractionProgress = defaults.bool(forKey: Keys.showExtractionProgress)
        
        // Set defaults for first launch
        if !defaults.bool(forKey: Keys.hasLaunchedBefore) {
            self.autoOpenAfterExtraction = true
            self.showExtractionProgress = true
            defaults.set(true, forKey: Keys.hasLaunchedBefore)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the last extraction path as a URL
    func getLastExtractionURL() -> URL? {
        guard let path = lastExtractionPath else { return nil }
        let url = URL(fileURLWithPath: path)
        
        // Verify the path still exists
        guard FileManager.default.fileExists(atPath: path) else {
            // Clear invalid path
            lastExtractionPath = nil
            return nil
        }
        
        return url
    }
    
    /// Sets the last extraction path from a URL
    func setLastExtractionURL(_ url: URL) {
        lastExtractionPath = url.path
    }
    
    /// Gets a suggested extraction path (Downloads folder if no previous path)
    func getSuggestedExtractionURL() -> URL {
        if let lastURL = getLastExtractionURL() {
            return lastURL
        }
        
        // Default to Downloads folder
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        return downloadsURL ?? URL(fileURLWithPath: NSHomeDirectory())
    }
    
    // MARK: - Window Management
    
    /// Saves the window frame for next launch
    func saveWindowFrame(_ frame: CGRect) {
        let frameDict: [String: Double] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        defaults.set(frameDict, forKey: Keys.windowFrame)
    }
    
    /// Loads the saved window frame
    func loadWindowFrame() -> CGRect? {
        guard let frameDict = defaults.dictionary(forKey: Keys.windowFrame),
              let x = frameDict["x"] as? Double,
              let y = frameDict["y"] as? Double,
              let width = frameDict["width"] as? Double,
              let height = frameDict["height"] as? Double else {
            return nil
        }
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Reset Methods
    
    /// Resets all preferences to defaults
    func resetToDefaults() {
        lastExtractionPath = nil
        autoOpenAfterExtraction = true
        showExtractionProgress = true
        
        // Clear window frame
        defaults.removeObject(forKey: Keys.windowFrame)
    }
    
    /// Clears the last extraction path (useful if folder was deleted)
    func clearLastExtractionPath() {
        lastExtractionPath = nil
    }
}