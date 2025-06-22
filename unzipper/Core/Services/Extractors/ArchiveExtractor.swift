//
//  ArchiveExtractor.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Archive Extractor Protocol
protocol ArchiveExtractor {
    /// Extracts an archive from source URL to destination URL
    /// - Parameters:
    ///   - sourceURL: The archive file to extract
    ///   - destinationURL: The directory where files should be extracted
    ///   - progressHandler: Called periodically with extraction progress
    func extract(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping (ExtractionProgress) -> Void
    ) async throws
    
    /// Lists the contents of an archive without extracting
    /// - Parameter archiveURL: The archive file to inspect
    /// - Returns: Array of file paths contained in the archive
    func listContents(of archiveURL: URL) async throws -> [String]
    
    /// Estimates the total size of the archive contents
    /// - Parameter archiveURL: The archive file to analyze
    /// - Returns: Estimated total size in bytes
    func estimateSize(of archiveURL: URL) async throws -> Int64
}