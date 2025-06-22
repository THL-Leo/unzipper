//
//  ArchiveDetector.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Archive Detector
class ArchiveDetector {
    
    /// Detects the archive type based on file extension
    static func detectArchiveType(from url: URL) -> ArchiveType? {
        let filename = url.lastPathComponent.lowercased()
        
        // Check for compound extensions first (tar.gz, tar.bz2, etc.)
        for archiveType in ArchiveType.allCases {
            for ext in archiveType.extensions {
                if filename.hasSuffix("." + ext) {
                    return archiveType
                }
            }
        }
        return nil
    }
    
    /// Checks if the file is a supported archive format
    static func isSupportedArchive(_ url: URL) -> Bool {
        return detectArchiveType(from: url) != nil
    }
    
    /// Gets all supported file extensions as a flat array
    static func getAllSupportedExtensions() -> [String] {
        return ArchiveType.allCases.flatMap { $0.extensions }
    }
    
    /// Validates that the file exists and is readable
    static func validateArchiveFile(_ url: URL) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else {
            throw ExtractionError.fileNotFound
        }
        
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw ExtractionError.insufficientPermissions
        }
        
        // Basic size check - empty files are likely corrupted
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64, fileSize == 0 {
                throw ExtractionError.corruptedArchive
            }
        } catch {
            throw ExtractionError.corruptedArchive
        }
    }
}