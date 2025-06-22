//
//  ContentView.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ArchiveExtractorViewModel()
    @EnvironmentObject private var preferences: UserPreferences
    
    var body: some View {
        VStack(spacing: 20) {
            HeaderView()
            
            if viewModel.isExtracting {
                // DURING EXTRACTION: Only show progress, hide everything else
                ExtractionProgressView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            } else if viewModel.selectedArchive == nil {
                // NO ARCHIVE: Show drop zone
                
                DropZoneView(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                // ARCHIVE SELECTED: Show details
                ArchiveDetailsView(viewModel: viewModel)
                    .transition(.slide)
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .frame(minWidth: 600, minHeight: 450)
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedArchive)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isExtracting)
        .onChange(of: viewModel.selectedArchive, {oldValue, newValue in
            resizeWindow(hasArchive: newValue != nil)
        })
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
                viewModel.showErrorAlert = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
    private func resizeWindow(hasArchive: Bool) {
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                let targetSize: NSSize
                
                if hasArchive {
                    // Expanded size when archive is selected
                    targetSize = NSSize(width: 600, height: 550)
                } else {
                    // Compact size when no archive
                    targetSize = NSSize(width: 600, height: 450)
                }
                
                // Animate the window resize
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(
                        NSRect(
                            origin: NSPoint(
                                x: window.frame.origin.x,
                                y: window.frame.origin.y + window.frame.height - targetSize.height
                            ),
                            size: targetSize
                        ),
                        display: true
                    )
                }
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(UserPreferences.shared)
}
