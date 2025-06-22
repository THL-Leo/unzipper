//
//  TarExtractor.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - TAR Extractor
class TarExtractor: ArchiveExtractor {
    private let archiveType: ArchiveType
    
    init(type: ArchiveType) {
        self.archiveType = type
    }
    
    func extract(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping (ExtractionProgress) -> Void
    ) async throws {
        // Validate source file
        try ArchiveDetector.validateArchiveFile(sourceURL)
        
        // Create destination directory
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Get file list for progress tracking
        let fileList = try await listContents(of: sourceURL)
        let totalFiles = fileList.count
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var arguments = ["xf", sourceURL.path, "-C", destinationURL.path]
        
        // Add compression flags based on archive type
        switch archiveType {
        case .tarGz:
            arguments[0] = "xzf" // Extract with gzip compression
        case .tarBz2:
            arguments[0] = "xjf" // Extract with bzip2 compression
        case .tarXz:
            arguments[0] = "xJf" // Extract with xz compression
        case .gzip:
            // For standalone .gz files, decompress first
            try await extractGzipFile(from: sourceURL, to: destinationURL, progressHandler: progressHandler)
            return
        default:
            break // Use default "xf" for plain tar
        }
        
        task.arguments = arguments
        
        // Set up progress monitoring
        var filesProcessed = 0
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            filesProcessed = min(filesProcessed + 1, totalFiles)
            let progress = ExtractionProgress(
                currentFile: filesProcessed < fileList.count ? fileList[filesProcessed] : "Finishing...",
                filesProcessed: filesProcessed,
                totalFiles: totalFiles,
                bytesProcessed: 0,
                totalBytes: 0
            )
            progressHandler(progress)
        }
        
        defer {
            progressTimer.invalidate()
        }
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw ExtractionError.extractionFailed("TAR extraction failed with status \(task.terminationStatus)")
        }
        
        // Final progress update
        let finalProgress = ExtractionProgress(
            currentFile: "Complete",
            filesProcessed: totalFiles,
            totalFiles: totalFiles,
            bytesProcessed: 0,
            totalBytes: 0
        )
        progressHandler(finalProgress)
    }
    
    func listContents(of archiveURL: URL) async throws -> [String] {
        if archiveType == .gzip {
            // For standalone gzip files, return the decompressed filename
            let originalName = archiveURL.deletingPathExtension().lastPathComponent
            return [originalName]
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var arguments = ["tf", archiveURL.path]
        
        // Add compression flags for listing
        switch archiveType {
        case .tarGz:
            arguments[0] = "tzf"
        case .tarBz2:
            arguments[0] = "tjf"
        case .tarXz:
            arguments[0] = "tJf"
        default:
            break
        }
        
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw ExtractionError.corruptedArchive
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    func estimateSize(of archiveURL: URL) async throws -> Int64 {
        // For TAR files, we estimate based on archive size
        // This is approximate since compressed files vary
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                // Estimate decompressed size based on compression type
                switch archiveType {
                case .tarGz:
                    return fileSize * 3 // Rough estimate for gzip compression
                case .tarBz2:
                    return fileSize * 4 // Rough estimate for bzip2 compression
                case .tarXz:
                    return fileSize * 5 // Rough estimate for xz compression
                case .tar:
                    return fileSize // No compression
                default:
                    return fileSize * 2
                }
            }
        } catch {
            throw ExtractionError.corruptedArchive
        }
        
        return 0
    }
    
    // MARK: - Private Methods
    
    private func extractGzipFile(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping (ExtractionProgress) -> Void
    ) async throws {
        let outputFilename = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = destinationURL.appendingPathComponent(outputFilename)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        task.arguments = ["-c", sourceURL.path]
        
        // Redirect output to destination file
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer { outputHandle.closeFile() }
        
        task.standardOutput = outputHandle
        
        // Simple progress for single file
        progressHandler(ExtractionProgress(
            currentFile: outputFilename,
            filesProcessed: 0,
            totalFiles: 1,
            bytesProcessed: 0,
            totalBytes: 0
        ))
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw ExtractionError.extractionFailed("GZIP extraction failed")
        }
        
        progressHandler(ExtractionProgress(
            currentFile: "Complete",
            filesProcessed: 1,
            totalFiles: 1,
            bytesProcessed: 0,
            totalBytes: 0
        ))
    }
}