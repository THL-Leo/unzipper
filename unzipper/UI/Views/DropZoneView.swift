//
//  DropZoneView.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var viewModel: ArchiveExtractorViewModel
    @State private var isDragOver = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isDragOver ? "plus.circle.fill" : "plus.circle.dashed")
                .font(.system(size: 64))
                .foregroundColor(isDragOver ? .blue : .secondary)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(isDragOver ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isDragOver)
            
            VStack(spacing: 8) {
                Text("Drop archive files here")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Choose Files") {
                    viewModel.showFileImporter = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            // Supported formats info
            VStack(spacing: 4) {
                Text("Supported Formats:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("ZIP • TAR • TAR.GZ • TAR.BZ2 • TAR.XZ • GZIP")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 250)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isDragOver ? .blue : .gray.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDragOver ? .blue.opacity(0.1) : .gray.opacity(0.05))
                )
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            viewModel.handleDrop(providers: providers)
            return true
        }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileSelection(result: result)
        }
    }
    
    // MARK: - Supported File Types
    private var supportedContentTypes: [UTType] {
        var types: [UTType] = []
        
        // Add common archive types
        if let zipType = UTType(filenameExtension: "zip") {
            types.append(zipType)
        }
        if let tarType = UTType(filenameExtension: "tar") {
            types.append(tarType)
        }
        if let gzType = UTType(filenameExtension: "gz") {
            types.append(gzType)
        }
        if let tgzType = UTType(filenameExtension: "tgz") {
            types.append(tgzType)
        }
        if let bz2Type = UTType(filenameExtension: "bz2") {
            types.append(bz2Type)
        }
        if let xzType = UTType(filenameExtension: "xz") {
            types.append(xzType)
        }
        
        // Fallback to generic types if specific ones aren't available
        if types.isEmpty {
            types = [.archive, .data]
        }
        
        return types
    }
}

#Preview {
    DropZoneView(viewModel: ArchiveExtractorViewModel())
        .padding()
}
