//
//  ExtractionProgress.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Extraction Progress
struct ExtractionProgress {
    let currentFile: String
    let filesProcessed: Int
    let totalFiles: Int
    let bytesProcessed: Int64
    let totalBytes: Int64
    
    var percentage: Double {
        guard totalFiles > 0 else { return 0.0 }
        return Double(filesProcessed) / Double(totalFiles) * 100.0
    }
    
    var bytesPercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesProcessed) / Double(totalBytes) * 100.0
    }
    
    var formattedCurrentFile: String {
        return currentFile.isEmpty ? "Preparing..." : currentFile
    }
}