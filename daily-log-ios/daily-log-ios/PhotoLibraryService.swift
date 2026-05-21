//
//  PhotoLibraryService.swift
//  daily-log-ios
//

import Photos
import UIKit
import AVFoundation

enum PhotoAuthorizationStatus {
    case authorized
    case limited
    case denied
    case notDetermined
}

class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    func requestAuthorization() async -> PhotoAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return mapStatus(status)
    }

    func currentAuthorizationStatus() -> PhotoAuthorizationStatus {
        mapStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func fetchAssets(for date: Date) -> [MediaAsset] {
        autoreleasepool {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return []
            }

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                startOfDay as NSDate,
                endOfDay as NSDate
            )
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let result = PHAsset.fetchAssets(with: fetchOptions)
            var assets: [MediaAsset] = []

            result.enumerateObjects { phAsset, _, _ in
                let type: MediaType
                switch phAsset.mediaType {
                case .image:
                    type = phAsset.mediaSubtypes.contains(.photoLive) ? .livePhoto : .image
                case .video:
                    type = .video
                default:
                    type = .unknown
                }

                let asset = MediaAsset(
                    id: phAsset.localIdentifier,
                    type: type,
                    creationDate: phAsset.creationDate,
                    modificationDate: phAsset.modificationDate,
                    duration: phAsset.mediaType == .video ? phAsset.duration : nil,
                    localIdentifier: phAsset.localIdentifier,
                    isSelected: false,
                    phAsset: phAsset
                )
                assets.append(asset)
            }

            return assets
        }
    }

    func makeMediaAsset(from phAsset: PHAsset) -> MediaAsset {
        let type: MediaType
        switch phAsset.mediaType {
        case .image:
            type = phAsset.mediaSubtypes.contains(.photoLive) ? .livePhoto : .image
        case .video:
            type = .video
        default:
            type = .unknown
        }

        return MediaAsset(
            id: phAsset.localIdentifier,
            type: type,
            creationDate: phAsset.creationDate,
            modificationDate: phAsset.modificationDate,
            duration: phAsset.mediaType == .video ? phAsset.duration : nil,
            localIdentifier: phAsset.localIdentifier,
            isSelected: false,
            phAsset: phAsset
        )
    }

    func requestThumbnail(for asset: MediaAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset.phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func requestPreviewImage(for asset: MediaAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset.phAsset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func requestPlayerItem(for asset: MediaAsset) async -> AVPlayerItem? {
        guard asset.type == .video else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestPlayerItem(
                forVideo: asset.phAsset,
                options: options
            ) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    func requestAVAsset(for asset: MediaAsset) async -> AVAsset? {
        if asset.type == .livePhoto {
            return await requestLivePhotoPairedVideoAsset(for: asset)
        }

        guard asset.type == .video else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(
                forVideo: asset.phAsset,
                options: options
            ) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    func requestVideoDuration(for asset: MediaAsset) async -> TimeInterval? {
        if asset.type == .video {
            return asset.duration
        }

        guard asset.type == .livePhoto,
              let avAsset = await requestAVAsset(for: asset),
              let duration = try? await avAsset.load(.duration),
              duration.seconds.isFinite,
              duration.seconds > 0 else {
            return nil
        }

        return duration.seconds
    }

    func cleanupStaleLivePhotoVideoCache(olderThan age: TimeInterval = 24 * 60 * 60) {
        let fileManager = FileManager.default
        let directory = livePhotoPairedVideoDirectory
        let cutoff = Date().addingTimeInterval(-age)

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true,
                  let modified = values?.contentModificationDate,
                  modified < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Private

    private var livePhotoPairedVideoDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyLogLivePhotoVideos", isDirectory: true)
    }

    private func requestLivePhotoPairedVideoAsset(for asset: MediaAsset) async -> AVAsset? {
        guard let resource = PHAssetResource
            .assetResources(for: asset.phAsset)
            .first(where: { $0.type == .pairedVideo }) else {
            return nil
        }

        let fileURL = livePhotoPairedVideoURL(for: asset, resource: resource)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return AVURLAsset(url: fileURL)
        }

        return await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            } catch {
                continuation.resume(returning: nil)
                return
            }

            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: fileURL,
                options: options
            ) { error in
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: AVURLAsset(url: fileURL))
                }
            }
        }
    }

    private func livePhotoPairedVideoURL(for asset: MediaAsset, resource: PHAssetResource) -> URL {
        let safeIdentifier = asset.localIdentifier.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let ext = (resource.originalFilename as NSString).pathExtension
        let fileExtension = ext.isEmpty ? "mov" : ext

        return livePhotoPairedVideoDirectory
            .appendingPathComponent("\(safeIdentifier).\(fileExtension)")
    }

    private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoAuthorizationStatus {
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
