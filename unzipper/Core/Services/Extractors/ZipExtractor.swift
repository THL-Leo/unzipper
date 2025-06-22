//
//  ZipExtractor.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - ZIP Extractor
class ZipExtractor: ArchiveExtractor {
    
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
        
        // Get file list first for progress tracking
        let fileList = try await listContents(of: sourceURL)
        let totalFiles = fileList.count
        
        // Use system unzip command for reliable extraction
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-qq", sourceURL.path, "-d", destinationURL.path]
        
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
            throw ExtractionError.extractionFailed("ZIP extraction failed with status \(task.terminationStatus)")
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-l", archiveURL.path]
        
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
        
        return parseUnzipListOutput(output)
    }
    
    func estimateSize(of archiveURL: URL) async throws -> Int64 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-l", archiveURL.path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse the total size from unzip -l output
        let lines = output.components(separatedBy: .newlines)
        for line in lines.reversed() {
            if line.contains("files") && line.contains("bytes") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let sizeString = components.first, let size = Int64(sizeString) {
                    return size
                }
            }
        }
        
        return 0
    }
    
    // MARK: - Private Methods
    
    private func parseUnzipListOutput(_ output: String) -> [String] {
        let lines = output.components(separatedBy: .newlines)
        var files: [String] = []
        var foundHeader = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Look for the header line
            if trimmed.contains("Length") && trimmed.contains("Date") && trimmed.contains("Time") && trimmed.contains("Name") {
                foundHeader = true
                continue
            }
            
            // Skip separator lines (all dashes)
            if trimmed.allSatisfy({ $0 == "-" || $0.isWhitespace }) {
                continue
            }
            
            // Stop at summary line (contains numbers and "files")
            if trimmed.contains("files") && !trimmed.contains(".") {
                break
            }
            
            // If we found the header and this looks like a file entry
            if foundHeader {
                // Split by whitespace and look for the pattern: number date time filename
                let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                if components.count >= 4 {
                    // Check if first component is a number (file size)
                    if Int(components[0]) != nil {
                        // Check if second component looks like a date (MM-DD-YYYY)
                        if components[1].contains("-") {
                            // Check if third component looks like time (HH:MM)
                            if components[2].contains(":") {
                                // Everything from index 3 onwards is the filename
                                let filename = components[3...].joined(separator: " ")
                                if !filename.isEmpty {
                                    files.append(filename)
                                }
                            }
                        }
                    }
                }
            }
        }
        return files
    }
}

// MARK: - String Extension for Regex Matching
extension String {
    func matches(_ pattern: String) -> Bool {
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}

