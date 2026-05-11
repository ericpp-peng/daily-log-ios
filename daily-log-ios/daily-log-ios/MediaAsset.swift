//
//  MediaAsset.swift
//  daily-log-ios
//

import Foundation
import Photos

enum MediaType {
    case image
    case video
    case livePhoto
    case unknown
}

struct MediaAsset: Identifiable {
    let id: String
    let type: MediaType
    let creationDate: Date?
    let modificationDate: Date?
    let duration: TimeInterval?
    let localIdentifier: String
    var isSelected: Bool
    let phAsset: PHAsset

    var sortDate: Date {
        creationDate ?? modificationDate ?? Date.distantFuture
    }
}
