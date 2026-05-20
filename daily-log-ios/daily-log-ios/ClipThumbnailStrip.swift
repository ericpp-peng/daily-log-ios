//
//  ClipThumbnailStrip.swift
//  daily-log-ios
//
//  Horizontal thumbnail strip for a single MediaAsset.
//  Videos: extracts N evenly-spaced frames via AVAssetImageGenerator.
//  Photos: shows the asset's preview image stretched across the strip.
//

import AVFoundation
import SwiftUI
import UIKit

struct ClipThumbnailStrip: View {
    let asset: MediaAsset
    var thumbnailCount: Int = 8
    var prefersVideo: Bool = false

    @State private var thumbnails: [UIImage] = []
    @State private var isLoading: Bool = false

    var body: some View {
        GeometryReader { geo in
            stripContent(width: geo.size.width, height: geo.size.height)
        }
        .task(id: thumbnailRequestID) {
            await loadThumbnails()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func stripContent(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color(.systemGray5)

            if isLoading && thumbnails.isEmpty {
                ProgressView().scaleEffect(0.7)
            } else if shouldLoadVideoFrames {
                videoStrip(width: width, height: height)
            } else if let image = thumbnails.first {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
    }

    private func videoStrip(width: CGFloat, height: CGFloat) -> some View {
        let count = max(thumbnails.count, 1)
        let cellWidth = width / CGFloat(count)
        return HStack(spacing: 0) {
            ForEach(thumbnails.indices, id: \.self) { idx in
                Image(uiImage: thumbnails[idx])
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellWidth, height: height)
                    .clipped()
            }
        }
    }

    // MARK: - Loading

    private var thumbnailRequestID: String {
        "\(asset.id)-\(thumbnailCount)-\(shouldLoadVideoFrames)"
    }

    private var shouldLoadVideoFrames: Bool {
        asset.type == .video || (asset.type == .livePhoto && prefersVideo)
    }

    private func loadThumbnails() async {
        isLoading = true
        defer { isLoading = false }

        if shouldLoadVideoFrames {
            await loadVideoThumbnails()
        } else {
            await loadPhotoThumbnail()
        }
    }

    private func loadVideoThumbnails() async {
        guard let avAsset = await PhotoLibraryService.shared.requestAVAsset(for: asset) else {
            thumbnails = []
            return
        }
        let duration: CMTime
        do {
            duration = try await avAsset.load(.duration)
        } catch {
            thumbnails = []
            return
        }
        let durSec = duration.seconds
        guard durSec.isFinite, durSec > 0 else {
            thumbnails = []
            return
        }

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 240, height: 240)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        var collected: [UIImage] = []
        for index in 0..<thumbnailCount {
            let time = CMTime(
                seconds: durSec * (Double(index) + 0.5) / Double(thumbnailCount),
                preferredTimescale: 600
            )
            do {
                let cgImage = try await generator.image(at: time).image
                collected.append(UIImage(cgImage: cgImage))
            } catch {
                continue
            }
        }
        thumbnails = collected
    }

    private func loadPhotoThumbnail() async {
        let image = await PhotoLibraryService.shared.requestPreviewImage(
            for: asset,
            targetSize: CGSize(width: 720, height: 480)
        )
        if let image {
            thumbnails = [image]
        }
    }
}
