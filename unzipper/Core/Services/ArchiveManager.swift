//
//  ArchiveManager.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Main Archive Manager
class ArchiveManager {
    static let shared = ArchiveManager()
    
    private init() {}
    
    /// Extracts an archive to the specified destination
    func extractArchive(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping (ExtractionProgress) -> Void
    ) async throws {
        // Detect archive type
        guard let archiveType = ArchiveDetector.detectArchiveType(from: sourceURL) else {
            throw ExtractionError.unsupportedFormat
        }
        
        // Validate source file
        try ArchiveDetector.validateArchiveFile(sourceURL)
        
        // Check if destination exists and handle appropriately
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // For now, we'll create a subdirectory with the archive name
            let archiveName = sourceURL.deletingPathExtension().lastPathComponent
            let finalDestination = destinationURL.appendingPathComponent(archiveName)
            
            // Create the extractor and perform extraction
            let extractor = createExtractor(for: archiveType)
            try await extractor.extract(
                from: sourceURL,
                to: finalDestination,
                progressHandler: progressHandler
            )
        } else {
            // Create the extractor and perform extraction
            let extractor = createExtractor(for: archiveType)
            try await extractor.extract(
                from: sourceURL,
                to: destinationURL,
                progressHandler: progressHandler
            )
        }
    }
    
    /// Lists the contents of an archive without extracting
    func listArchiveContents(of archiveURL: URL) async throws -> [String] {
        guard let archiveType = ArchiveDetector.detectArchiveType(from: archiveURL) else {
            throw ExtractionError.unsupportedFormat
        }
        
        try ArchiveDetector.validateArchiveFile(archiveURL)
        
        let extractor = createExtractor(for: archiveType)
        return try await extractor.listContents(of: archiveURL)
    }
    
    /// Estimates the size of archive contents
    func estimateArchiveSize(of archiveURL: URL) async throws -> Int64 {
        guard let archiveType = ArchiveDetector.detectArchiveType(from: archiveURL) else {
            throw ExtractionError.unsupportedFormat
        }
        
        try ArchiveDetector.validateArchiveFile(archiveURL)
        
        let extractor = createExtractor(for: archiveType)
        return try await extractor.estimateSize(of: archiveURL)
    }
    
    /// Gets information about a supported archive
    func getArchiveInfo(for url: URL) -> (type: ArchiveType, isSupported: Bool)? {
        guard let type = ArchiveDetector.detectArchiveType(from: url) else {
            return nil
        }
        
        let isSupported = isSupportedForExtraction(type)
        return (type: type, isSupported: isSupported)
    }
    
    /// Checks if an archive type is supported for extraction
    func isSupportedForExtraction(_ type: ArchiveType) -> Bool {
        switch type {
        case .zip, .tar, .tarGz, .tarBz2, .tarXz, .gzip:
            return true
        case .sevenZip, .rar:
            return false // Would require additional libraries
        }
    }
    
    // MARK: - Private Methods
    
    private func createExtractor(for type: ArchiveType) -> ArchiveExtractor {
        switch type {
        case .zip:
            return ZipExtractor()
        case .tar, .tarGz, .tarBz2, .tarXz, .gzip:
            return TarExtractor(type: type)
        case .sevenZip, .rar:
            fatalError("7-Zip and RAR support requires additional libraries like libarchive")
        }
    }
    
    /// Creates a unique destination directory name if one already exists
    private func createUniqueDestination(basePath: URL, archiveName: String) -> URL {
        var counter = 1
        var destination = basePath.appendingPathComponent(archiveName)
        
        while FileManager.default.fileExists(atPath: destination.path) {
            let uniqueName = "\(archiveName)_\(counter)"
            destination = basePath.appendingPathComponent(uniqueName)
            counter += 1
        }
        
        return destination
    }
}