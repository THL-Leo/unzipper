//
//  ExtractionError.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Extraction Errors
enum ExtractionError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case corruptedArchive
    case insufficientPermissions
    case destinationExists
    case extractionFailed(String)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported archive format"
        case .fileNotFound:
            return "Archive file not found"
        case .corruptedArchive:
            return "Archive appears to be corrupted"
        case .insufficientPermissions:
            return "Insufficient permissions to extract files"
        case .destinationExists:
            return "Destination folder already exists"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        case .userCancelled:
            return "Extraction was cancelled by user"
        }
    }
    
    var recoveryOptions: [String] {
        switch self {
        case .fileNotFound:
            return ["Choose a different file"]
        case .destinationExists:
            return ["Choose a different destination", "Overwrite existing files"]
        case .insufficientPermissions:
            return ["Choose a different destination", "Check file permissions"]
        default:
            return ["Try again", "Choose a different file"]
        }
    }
}