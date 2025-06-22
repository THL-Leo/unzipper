//
//  TarExtractor.swift
//  unzipper
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
        
        // Clean destination directory to avoid conflicts
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Create destination directory
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Handle pure gzip files differently
        if archiveType == .gzip {
            try await extractGzipFile(from: sourceURL, to: destinationURL, progressHandler: progressHandler)
            return
        }
        
        // Get file list for progress tracking
        let fileList = try await listContents(of: sourceURL)
        let totalFiles = fileList.count
        
        print("Extracting \(archiveType) archive: \(sourceURL.lastPathComponent)")
        print("To destination: \(destinationURL.path)")
        print("Files to extract: \(totalFiles)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        // Build arguments properly for each archive type
        var arguments: [String] = []
        
        switch archiveType {
        case .tarGz:
            arguments = ["-xzvf", sourceURL.path, "-C", destinationURL.path]
        case .tarBz2:
            arguments = ["-xjvf", sourceURL.path, "-C", destinationURL.path]
        case .tarXz:
            arguments = ["-xJvf", sourceURL.path, "-C", destinationURL.path]
        case .tar:
            arguments = ["-xvf", sourceURL.path, "-C", destinationURL.path]
        default:
            throw ExtractionError.unsupportedFormat
        }
        
        task.arguments = arguments
        
        print("Executing command: tar \(arguments.joined(separator: " "))")
        
        // Set up pipes for monitoring output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        // Set up progress monitoring
        var filesProcessed = 0
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            // Try to read output and count extracted files
            let outputData = outputPipe.fileHandleForReading.availableData
            if !outputData.isEmpty {
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let extractedLines = output.components(separatedBy: .newlines).filter {
                    !$0.trimmingCharacters(in: .whitespaces).isEmpty
                }
                filesProcessed += extractedLines.count
            }
            
            let currentProcessed = min(filesProcessed, totalFiles)
            let currentFile = currentProcessed < fileList.count ? fileList[currentProcessed] : "Processing..."
            
            let progress = ExtractionProgress(
                currentFile: currentFile,
                filesProcessed: currentProcessed,
                totalFiles: totalFiles,
                bytesProcessed: 0,
                totalBytes: 0
            )
            progressHandler(progress)
        }
        
        defer {
            progressTimer.invalidate()
        }
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to run tar command: \(error)")
            throw ExtractionError.extractionFailed("Failed to execute tar: \(error.localizedDescription)")
        }
        
        // Check for errors
        if task.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            print("TAR extraction failed with status \(task.terminationStatus)")
            print("Error: \(errorOutput)")
            throw ExtractionError.extractionFailed("TAR extraction failed: \(errorOutput)")
        }
        
        // Verify extraction worked
        let extractedContents = try FileManager.default.contentsOfDirectory(atPath: destinationURL.path)
        print("Extraction completed. Found \(extractedContents.count) items in destination:")
        for item in extractedContents.prefix(5) {
            print("  - \(item)")
        }
        
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
            // For pure .gz files, return the expected output filename
            return [archiveURL.properBaseName]
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var arguments: [String] = []
        
        switch archiveType {
        case .tarGz:
            arguments = ["-tzf", archiveURL.path]
        case .tarBz2:
            arguments = ["-tjf", archiveURL.path]
        case .tarXz:
            arguments = ["-tJf", archiveURL.path]
        case .tar:
            arguments = ["-tf", archiveURL.path]
        default:
            throw ExtractionError.unsupportedFormat
        }
        
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        print("Listing archive contents: tar \(arguments.joined(separator: " "))")
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw ExtractionError.corruptedArchive
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        print("Archive contents:\n\(output)")
        
        return parseTarListOutput(output)
    }
    
    func estimateSize(of archiveURL: URL) async throws -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                switch archiveType {
                case .tarGz:
                    return fileSize * 3
                case .tarBz2:
                    return fileSize * 4
                case .tarXz:
                    return fileSize * 5
                case .tar:
                    return fileSize
                default:
                    return fileSize * 2
                }
            }
        } catch {
            throw ExtractionError.corruptedArchive
        }
        return 0
    }
    
    private func extractGzipFile(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping (ExtractionProgress) -> Void
    ) async throws {
        let outputFilename = sourceURL.properBaseName
        let outputURL = destinationURL.appendingPathComponent(outputFilename)
        
        print("Extracting .gz file to: \(outputFilename)")
        
        progressHandler(ExtractionProgress(
            currentFile: outputFilename,
            filesProcessed: 0,
            totalFiles: 1,
            bytesProcessed: 0,
            totalBytes: 0
        ))
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        task.arguments = ["-c", sourceURL.path]
        
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer { outputHandle.closeFile() }
        
        task.standardOutput = outputHandle
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            try? FileManager.default.removeItem(at: outputURL)
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
    
    private func parseTarListOutput(_ output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var files: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Skip lines that look like total summaries or headers
            if trimmed.lowercased().contains("total") ||
               trimmed.allSatisfy({ $0 == "-" || $0 == "=" || $0.isWhitespace }) {
                continue
            }
            
            // TAR -tf output is usually just filenames, one per line
            // Handle both simple listing and detailed listing formats
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if components.count > 1 {
                // Detailed listing: permissions, user, date, filename
                // Filename is the last component
                if let filename = components.last, !filename.isEmpty {
                    files.append(filename)
                }
            } else if !trimmed.isEmpty {
                // Simple filename listing
                files.append(trimmed)
            }
        }
        
        return files
    }
}

extension URL {
    /// Properly removes archive extensions to get the base name
    var properBaseName: String {
        let name = self.lastPathComponent
        let lowercaseName = name.lowercased()
        
        // Handle double extensions like .tar.gz, .tar.bz2, etc.
        if lowercaseName.hasSuffix(".tar.gz") || lowercaseName.hasSuffix(".tgz") {
            // Remove .tar.gz -> get "test" from "test.tar.gz"
            let withoutGz = self.deletingPathExtension() // "test.tar"
            let withoutTar = withoutGz.deletingPathExtension() // "test"
            return withoutTar.lastPathComponent
        } else if lowercaseName.hasSuffix(".tar.bz2") || lowercaseName.hasSuffix(".tbz2") {
            // Remove .tar.bz2 -> get "test" from "test.tar.bz2"
            let withoutBz2 = self.deletingPathExtension() // "test.tar"
            let withoutTar = withoutBz2.deletingPathExtension() // "test"
            return withoutTar.lastPathComponent
        } else if lowercaseName.hasSuffix(".tar.xz") || lowercaseName.hasSuffix(".txz") {
            // Remove .tar.xz -> get "test" from "test.tar.xz"
            let withoutXz = self.deletingPathExtension() // "test.tar"
            let withoutTar = withoutXz.deletingPathExtension() // "test"
            return withoutTar.lastPathComponent
        } else if lowercaseName.hasSuffix(".tar") {
            // Remove .tar -> get "test" from "test.tar"
            return self.deletingPathExtension().lastPathComponent
        } else if lowercaseName.hasSuffix(".gz") {
            // Remove .gz -> get "test" from "test.gz"
            return self.deletingPathExtension().lastPathComponent
        }
        
        // For other extensions, just remove the last one
        return self.deletingPathExtension().lastPathComponent
    }
    
    // Keep the old property for compatibility, but fix it
    var archiveBaseName: String {
        return properBaseName
    }
}
