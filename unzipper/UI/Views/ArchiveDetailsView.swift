import SwiftUI

struct ArchiveDetailsView: View {
    @ObservedObject var viewModel: ArchiveExtractorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Archive Header
            archiveHeaderSection
            
            // Archive Contents Preview
            if viewModel.isLoadingContents {
                loadingContentsSection
            } else if !viewModel.archiveContents.isEmpty {
                archiveContentsSection
            }
            
            // Extraction Controls
            extractionControlsSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .fileImporter(
            isPresented: $viewModel.showDestinationPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleDestinationSelection(result: result)
        }
    }
    
    // MARK: - Archive Header Section
    private var archiveHeaderSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedArchive?.lastPathComponent ?? "Unknown Archive")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    if let type = viewModel.archiveType {
                        Label(type.displayName, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if viewModel.estimatedSize > 0 {
                        Label(viewModel.formattedFileSize(viewModel.estimatedSize), systemImage: "externaldrive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button("Remove") {
                withAnimation {
                    viewModel.clearSelection()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Loading Contents Section
    private var loadingContentsSection: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Reading archive contents...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Archive Contents Section (DYNAMIC SIZING)
    private var archiveContentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with file count
            HStack {
                Text("Archive Contents")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.archiveContents.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // Dynamic file list - size based on file count
            if viewModel.archiveContents.count <= 5 {
                // Show all files without scrolling if 5 or fewer
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(viewModel.archiveContents.enumerated()), id: \.offset) { index, filename in
                        fileRowView(filename: filename, index: index)
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .stroke(.separator, lineWidth: 0.5)
                )
            } else {
                // Show scrollable list for more than 5 files
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.archiveContents.enumerated()), id: \.offset) { index, filename in
                            fileRowView(filename: filename, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: CGFloat(150)) // Height for exactly 5 rows (35px per row)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .stroke(.separator, lineWidth: 0.5)
                )
                .overlay(
                    // Scroll indicator for many files
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
                
                // Scroll hint for many files
//                HStack {
//                    Image(systemName: "arrow.up.arrow.down")
//                        .font(.caption2)
//                        .foregroundColor(.blue)
//                    
//                    Text("Scroll to see all \(viewModel.archiveContents.count) files")
//                        .font(.caption2)
//                        .foregroundColor(.blue)
//                    
//                    Spacer()
//                }
//                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Improved File Row View
    private func fileRowView(filename: String, index: Int) -> some View {
        HStack(spacing: 10) {
            // File number indicator
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
                .monospacedDigit()
            
            // File icon
            Image(systemName: getFileIcon(for: filename))
                .font(.caption)
                .foregroundColor(getFileColor(for: filename))
                .frame(width: 16)
            
            // Filename
            Text(filename)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Spacer()
            
            // File type indicator for special files
            if filename.hasSuffix("/") {
                Text("folder")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6) // Slightly increased padding for better spacing
        .background(
            // Alternating row colors for better readability
            (index % 2 == 0 ? Color.clear : Color.gray.opacity(0.03))
        )
        .cornerRadius(4)
    }
    
    // MARK: - File Icon Helper
    private func getFileIcon(for filename: String) -> String {
        if filename.hasSuffix("/") {
            return "folder.fill"
        }
        
        let lowercased = filename.lowercased()
        if lowercased.hasSuffix(".txt") || lowercased.hasSuffix(".md") {
            return "doc.text.fill"
        } else if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".gif") {
            return "photo.fill"
        } else if lowercased.hasSuffix(".pdf") {
            return "doc.richtext.fill"
        } else if lowercased.hasSuffix(".zip") || lowercased.hasSuffix(".tar") {
            return "archivebox.fill"
        } else {
            return "doc.fill"
        }
    }
    
    // MARK: - File Color Helper
    private func getFileColor(for filename: String) -> Color {
        if filename.hasSuffix("/") {
            return .blue
        }
        
        let lowercased = filename.lowercased()
        if lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".png") || lowercased.hasSuffix(".gif") {
            return .green
        } else if lowercased.hasSuffix(".pdf") {
            return .red
        } else if lowercased.hasSuffix(".zip") || lowercased.hasSuffix(".tar") {
            return .orange
        } else {
            return .secondary
        }
    }
    
    // MARK: - Extraction Controls Section
    private var extractionControlsSection: some View {
        VStack(spacing: 12) {
            // Destination Selection
            HStack {
                Button("Choose Destination") {
                    viewModel.showDestinationPicker = true
                }
                .buttonStyle(.bordered)
                
                if let destination = viewModel.destinationURL {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4){
                            Text("Extract to:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(destination.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Extract Button
            HStack {
                Spacer()
                
                Button("Extract Archive") {
                    Task {
                        await viewModel.extractArchive()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.destinationURL == nil || viewModel.isExtracting || viewModel.isLoadingContents)
            }
        }
    }
}

#Preview {
    let viewModel = ArchiveExtractorViewModel()
    // Simulate a selected archive for preview with many files
    viewModel.selectedArchive = URL(fileURLWithPath: "/tmp/sample.zip")
    viewModel.archiveType = .zip
    viewModel.archiveContents = [
        "50403226_00102_0350_XLarge.apk",
        "50403226_00202_0357_XLarge.pdf",
        "50403226_00301_0349_XLarge.jpg",
        "50403226_90001_0349_XLarge.jpg",
        "50403226_85202_0357_XLarge/",
        "50403226_85202_0357_XLarge.zip",
//        "50403226_85202_0357_XLarge.pdf"
        
    ]
    viewModel.estimatedSize = 1024 * 1024 * 5 // 5MB
    
    return ArchiveDetailsView(viewModel: viewModel)
        .padding()
}
