//
//  HeaderView.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
                .symbolRenderingMode(.hierarchical)
            
            Text("Unzipper")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Drag & drop ZIP, TAR, TAR.GZ, and TAR.BZ2 files to extract")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    HeaderView()
        .padding()
}
