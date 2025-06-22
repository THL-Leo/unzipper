//
//  ExtractionProgressView.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import SwiftUI

struct ExtractionProgressView: View {
    @ObservedObject var viewModel: ArchiveExtractorViewModel
    @EnvironmentObject private var preferences: UserPreferences
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with cancel button
            progressHeader
            
            // Progress details
            if let progress = viewModel.extractionProgress {
                progressDetails(progress)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.blue.opacity(0.1))
                .stroke(.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        HStack {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.9)
                    .tint(.blue)
                
                Text("Extracting Archive...")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Button("Cancel") {
                viewModel.cancelExtraction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
        }
    }
    
    // MARK: - Progress Details
    private func progressDetails(_ progress: ExtractionProgress) -> some View {
        VStack(spacing: 12) {
            // Current file info
            currentFileSection(progress)
            
            // Progress bar
            progressBarSection(progress)
            
            // Statistics
            statisticsSection(progress)
        }
    }
    
    // MARK: - Current File Section
    private func currentFileSection(_ progress: ExtractionProgress) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Current file:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Image(systemName: "doc.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(progress.formattedCurrentFile)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Progress Bar Section
    private func progressBarSection(_ progress: ExtractionProgress) -> some View {
        VStack(spacing: 6) {
            ProgressView(value: progress.percentage, total: 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.5)
            
            HStack {
                Text("\(progress.filesProcessed) of \(progress.totalFiles) files")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress.percentage))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Statistics Section
    private func statisticsSection(_ progress: ExtractionProgress) -> some View {
        HStack(spacing: 20) {
            // Files remaining
            VStack(alignment: .leading, spacing: 2) {
                Text("Remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(progress.totalFiles - progress.filesProcessed)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Estimated size (if available)
            if progress.totalBytes > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.formattedFileSize(progress.totalBytes))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    let viewModel = ArchiveExtractorViewModel()
    viewModel.isExtracting = true
    viewModel.extractionProgress = ExtractionProgress(
        currentFile: "documents/important_file.pdf",
        filesProcessed: 45,
        totalFiles: 120,
        bytesProcessed: 1024 * 1024 * 3,
        totalBytes: 1024 * 1024 * 8
    )
    
    return ExtractionProgressView(viewModel: viewModel)
        .environmentObject(UserPreferences.shared)
        .padding()
}