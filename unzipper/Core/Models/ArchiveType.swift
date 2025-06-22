//
//  ArchiveType.swift
//  unzipper
//
//  Created by Leo Lee on 6/20/25.
//


import Foundation

// MARK: - Archive Types
enum ArchiveType: CaseIterable {
    case zip
    case tar
    case tarGz
    case tarBz2
    case tarXz
    case gzip
    case sevenZip
    case rar
    
    var extensions: [String] {
        switch self {
        case .zip: return ["zip"]
        case .tar: return ["tar"]
        case .tarGz: return ["tar.gz", "tgz"]
        case .tarBz2: return ["tar.bz2", "tbz2"]
        case .tarXz: return ["tar.xz", "txz"]
        case .gzip: return ["gz"]
        case .sevenZip: return ["7z"]
        case .rar: return ["rar"]
        }
    }
    
    var displayName: String {
        switch self {
        case .zip: return "ZIP Archive"
        case .tar: return "TAR Archive"
        case .tarGz: return "TAR.GZ Archive"
        case .tarBz2: return "TAR.BZ2 Archive"
        case .tarXz: return "TAR.XZ Archive"
        case .gzip: return "GZIP Archive"
        case .sevenZip: return "7-Zip Archive"
        case .rar: return "RAR Archive"
        }
    }
}
