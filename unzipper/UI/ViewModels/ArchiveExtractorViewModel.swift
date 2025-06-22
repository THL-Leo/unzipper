//
//  ArchiveExtractorViewModel.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View Model
@MainActor
class ArchiveExtractorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedArchive: URL?
    @Published var archiveType: ArchiveType?
    @Published var archiveContents: [String] = []
    @Published var destinationURL: URL?
    @Published var isExtracting = false
    @Published var extractionProgress: ExtractionProgress?
    @Published var showFileImporter = false
    @Published var showDestinationPicker = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var isLoadingContents = false
    @Published var estimatedSize: Int64 = 0
    
    // NEW: Permission handling
    @Published var needsPermissionForLocation = false
    @Published var permissionLocationName = ""
    
    // MARK: - Private Properties
    private var extractionTask: Task<Void, Never>?
    private let preferences = UserPreferences.shared
    private let archiveManager = ArchiveManager.shared
    private var securityScopedURLs: [URL] = [] // NEW: Track security scoped URLs
    
    // MARK: - Initialization
    init() {
        destinationURL = nil
    }
    
    // MARK: - File Handling Methods
    
    /// Handles dropped files from drag and drop
    func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { url, error in
            DispatchQueue.main.async {
                if let url = url {
                    // NEW: Start accessing security scoped resource for dropped files
                    if url.startAccessingSecurityScopedResource() {
                        self.securityScopedURLs.append(url)
                        self.selectArchive(url)
                    } else if let copiedURL = self.copyFileToTemporaryLocation(url) {
                        self.selectArchive(copiedURL)
                    } else {
                        self.showError("Cannot access the dropped file. Please try selecting it through the file picker.")
                    }
                } else if let error = error {
                    self.showError("Failed to load dropped file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handles file selection from file importer
    func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectArchive(url)
            }
        case .failure(let error):
            showError("Failed to select file: \(error.localizedDescription)")
        }
    }
    
    /// Handles destination folder selection
    func handleDestinationSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // NEW: Start accessing security scoped resource for destination
                if url.startAccessingSecurityScopedResource() {
                    // Remove old destination from scoped URLs if it exists
                    if let oldDestination = destinationURL,
                       let index = securityScopedURLs.firstIndex(of: oldDestination) {
                        oldDestination.stopAccessingSecurityScopedResource()
                        securityScopedURLs.remove(at: index)
                    }
                    
                    securityScopedURLs.append(url)
                }
                
                destinationURL = url
                needsPermissionForLocation = false // NEW: Clear permission flag
                print("🔍 Selected destination: \(url.path)")
                // Removed: preferences.setLastExtractionURL(url) - keeping it simple
            }
        case .failure(let error):
            showError("Failed to select destination: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Archive Operations
    
    /// Selects and analyzes an archive file
    private func selectArchive(_ url: URL) {
        print("🔍 Selecting archive: \(url.lastPathComponent)")
        selectedArchive = url
        archiveType = ArchiveDetector.detectArchiveType(from: url)
        print("🔍 Archive type: \(archiveType?.displayName ?? "unknown")")
        archiveContents = []
        estimatedSize = 0
        
        // NEW: Start accessing security scoped resource for the archive
        if url.startAccessingSecurityScopedResource() {
            securityScopedURLs.append(url)
        }
        
        // NEW: Check if we can write to the archive's folder
        let archiveFolder = url.deletingLastPathComponent()
        
        if isDirectoryWritable(archiveFolder) {
            // We can write here - set as destination
            destinationURL = archiveFolder
            needsPermissionForLocation = false
            print("🔍 Default extraction location: \(archiveFolder.path)")
        } else {
            // We need permission for this location
            destinationURL = nil
            needsPermissionForLocation = true
            permissionLocationName = archiveFolder.lastPathComponent
            print("🔍 Need permission for: \(archiveFolder.path)")
        }
        
        // Load archive contents asynchronously
        Task {
            await loadArchiveContents()
        }
    }
    
    /// NEW: Request permission for the archive's location
    func requestPermissionForArchiveLocation() {
        guard let archiveURL = selectedArchive else { return }
        let archiveFolder = archiveURL.deletingLastPathComponent()
        
        // This will trigger the file picker for the archive's folder
        showDestinationPicker = true
        print("🔍 Requesting permission for: \(archiveFolder.path)")
    }
    
    /// Loads the contents of the selected archive
    private func loadArchiveContents() async {
        guard let archiveURL = selectedArchive else { return }
        print("🔍 Loading contents for: \(archiveURL.lastPathComponent)")
        isLoadingContents = true
        
        do {
            // Load contents and estimated size
            async let contentsTask = archiveManager.listArchiveContents(of: archiveURL)
            async let sizeTask = archiveManager.estimateArchiveSize(of: archiveURL)
            
            let (contents, size) = try await (contentsTask, sizeTask)
            print("🔍 Found \(contents.count) files:")
            for (index, file) in contents.prefix(5).enumerated() {
                print("🔍   \(index + 1): \(file)")
            }
            
            await MainActor.run {
                self.archiveContents = contents
                self.estimatedSize = size
                self.isLoadingContents = false
                print("🔍 Archive contents updated with \(self.archiveContents.count) files")
            }
        } catch {
            await MainActor.run {
                self.isLoadingContents = false
                self.showError("Failed to read archive: \(error.localizedDescription)")
            }
        }
    }
    
    /// Starts the extraction process
    func extractArchive() async {
        guard let sourceURL = selectedArchive,
              let destinationURL = destinationURL else { return }
        
        isExtracting = true
        extractionProgress = ExtractionProgress(
            currentFile: "Preparing...",
            filesProcessed: 0,
            totalFiles: archiveContents.count,
            bytesProcessed: 0,
            totalBytes: estimatedSize
        )
        
        extractionTask = Task {
            do {
                try await archiveManager.extractArchive(
                    from: sourceURL,
                    to: destinationURL
                ) { progress in
                    Task {
                        @MainActor in
                        self.extractionProgress = progress
                    }
                }
                
                await MainActor.run {
                    self.isExtracting = false
                    self.extractionProgress = nil
                    
                    // Open destination folder if user preference is enabled
                    if self.preferences.autoOpenAfterExtraction {
                        NSWorkspace.shared.open(destinationURL)
                    }
                    
                    // Show success message
                    self.showSuccess("Archive extracted successfully!")
                    self.clearSelection()
                }
            } catch {
                await MainActor.run {
                    self.isExtracting = false
                    self.extractionProgress = nil
                    self.showError("Extraction failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cancels the current extraction
    func cancelExtraction() {
        extractionTask?.cancel()
        isExtracting = false
        extractionProgress = nil
    }
    
    /// Clears the current selection
    func clearSelection() {
        // NEW: Stop accessing all security scoped resources
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll()
        
        selectedArchive = nil
        archiveType = nil
        archiveContents = []
        extractionProgress = nil
        estimatedSize = 0
        destinationURL = nil
        
        // NEW: Clear permission flags
        needsPermissionForLocation = false
        permissionLocationName = ""
    }
    
    // MARK: - Utility Methods
    
    /// Shows an error message to the user
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    /// Shows a success message (you might want to add a success alert too)
    private func showSuccess(_ message: String) {
        // For now, we'll just print it. You could add a success alert similar to error alert
        print("✅ \(message)")
    }
    
    /// Copies a file to a temporary location (needed for sandboxed apps)
    private func copyFileToTemporaryLocation(_ url: URL) -> URL? {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let destinationURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to copy file to temporary location: \(error)")
            return nil
        }
    }
    
    /// NEW: Checks if a directory is writable
    private func isDirectoryWritable(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        
        // Check if directory exists and is writable
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        // Try to create a temporary file to test write access
        let testFile = url.appendingPathComponent(".write_test_\(UUID().uuidString)")
        
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            return true
        } catch {
            return false
        }
    }
    
    /// Formats file size for display
    func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Gets the number of files to display in the preview
    var previewFileCount: Int {
        return min(archiveContents.count, 10)
    }
    
    /// Gets whether there are more files than shown in preview
    var hasMoreFiles: Bool {
        return archiveContents.count > 10
    }
    
    /// Gets the count of additional files not shown
    var additionalFileCount: Int {
        return max(0, archiveContents.count - 10)
    }
    
    // MARK: - NEW: Cleanup
    deinit {
        // Clean up security scoped resources
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
