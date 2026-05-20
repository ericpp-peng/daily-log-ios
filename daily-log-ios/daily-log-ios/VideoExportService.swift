//
//  VideoExportService.swift
//  daily-log-ios
//

import AVFoundation
import Photos
import UIKit

enum VideoExportError: Error, LocalizedError {
    case noItems
    case exportFailed(status: AVAssetExportSession.Status?, underlying: Error?)
    case saveFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .noItems:
            return "No clips to export."
        case .exportFailed(let status, let underlying):
            let statusText = status.map { "status=\($0)" } ?? "status=unknown"
            if let underlying {
                return "Export failed (\(statusText)): \(errorDetails(for: underlying))"
            }
            return "Export failed (\(statusText)). Please try again."
        case .saveFailed(let underlying):
            if let underlying {
                return "Save failed: \(errorDetails(for: underlying))"
            }
            return "Save failed. Please allow Photos access."
        }
    }

    private func errorDetails(for error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    }
}

class VideoExportService {
    static let shared = VideoExportService()

    private let renderSize = CGSize(width: 1080, height: 1920)
    private let frameRate: Int32 = 30

    private struct TimestampSegment {
        let text: String
        let start: CMTime
        let duration: CMTime
    }

    private var sdrColorProperties: [String: Any] {
        [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
    }

    func export(
        items: [TimelineItem],
        timestamp: ProjectEditingConfiguration.Timestamp = .init()
    ) async throws -> URL {
        guard !items.isEmpty else { throw VideoExportError.noItems }

        if items.allSatisfy({ !$0.usesVideoPlayback }) {
            return try await exportStillsOnly(items: items, timestamp: timestamp)
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var timestampSegments: [TimestampSegment] = []
        var cursor = CMTime.zero
        var intermediateURLs: [URL] = []
        defer {
            removeTemporaryFiles(intermediateURLs)
        }

        for item in items {
            if item.usesVideoPlayback {
                guard let asset = await PhotoLibraryService.shared.requestAVAsset(for: item.asset),
                      let sourceVideoTrack = asset.tracks(withMediaType: .video).first else {
                    continue
                }
                let loadedDuration = try? await asset.load(.duration)
                let sourceDuration = loadedDuration?.seconds ?? item.configuration.trim.upperBound
                let safeSourceDuration = max(sourceDuration, 0.1)
                let trimStart = min(max(item.configuration.trim.lowerBound, 0), safeSourceDuration - 0.1)
                let trimEnd = min(
                    max(item.configuration.trim.upperBound, trimStart + 0.1),
                    safeSourceDuration
                )
                let start = CMTime(seconds: trimStart, preferredTimescale: 600)
                let durationSeconds = max(trimEnd - trimStart, 0.1)
                let duration = CMTime(seconds: durationSeconds, preferredTimescale: 600)
                let timeRange = CMTimeRange(start: start, duration: duration)

                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: cursor)
                if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first {
                    try? audioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: cursor)
                }

                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: cursor, duration: duration)
                instruction.backgroundColor = UIColor.black.cgColor
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                let transform = videoTransform(for: sourceVideoTrack, renderSize: renderSize)
                layerInstruction.setTransform(transform, at: cursor)
                instruction.layerInstructions = [layerInstruction]
                instructions.append(instruction)
                if let segment = timestampSegment(
                    for: item,
                    start: cursor,
                    duration: duration,
                    style: timestamp
                ) {
                    timestampSegments.append(segment)
                }

                cursor = cursor + duration
            } else {
                guard let image = await PhotoLibraryService.shared.requestPreviewImage(
                    for: item.asset,
                    targetSize: renderSize
                ) else {
                    continue
                }

                let durationSeconds = max(item.effectiveDuration, 0.5)
                let stillURL = try await makeStillVideo(
                    from: image,
                    duration: durationSeconds,
                    renderSize: renderSize
                )
                intermediateURLs.append(stillURL)
                let stillAsset = AVAsset(url: stillURL)
                guard let stillTrack = stillAsset.tracks(withMediaType: .video).first else { continue }

                let timeRange = CMTimeRange(start: .zero, duration: stillAsset.duration)
                try videoTrack.insertTimeRange(timeRange, of: stillTrack, at: cursor)

                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: cursor, duration: timeRange.duration)
                instruction.backgroundColor = UIColor.black.cgColor
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                layerInstruction.setTransform(.identity, at: cursor)
                instruction.layerInstructions = [layerInstruction]
                instructions.append(instruction)
                if let segment = timestampSegment(
                    for: item,
                    start: cursor,
                    duration: timeRange.duration,
                    style: timestamp
                ) {
                    timestampSegments.append(segment)
                }

                cursor = cursor + timeRange.duration
            }
        }

        guard cursor > .zero else { throw VideoExportError.noItems }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.renderScale = 1.0
        videoComposition.frameDuration = CMTime(value: 1, timescale: frameRate)
        videoComposition.instructions = instructions
        videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        if timestamp.enabled {
            videoComposition.animationTool = timestampAnimationTool(
                for: timestampSegments,
                style: timestamp,
                renderSize: renderSize
            )
        }

        do {
            return try await runExport(
                composition: composition,
                videoComposition: videoComposition,
                presetName: AVAssetExportPresetHighestQuality,
                preferredType: .mp4,
                fileExtension: "mp4"
            )
        } catch let error as VideoExportError {
            if case .exportFailed(_, let underlying) = error,
               let nsError = underlying as NSError?,
               nsError.domain == AVFoundationErrorDomain,
               nsError.code == -11838 {
                do {
                    return try await runExport(
                        composition: composition,
                        videoComposition: videoComposition,
                        presetName: AVAssetExportPresetHighestQuality,
                        preferredType: .mov,
                        fileExtension: "mov"
                    )
                } catch {
                    return try await runExport(
                        composition: composition,
                        videoComposition: nil,
                        presetName: AVAssetExportPresetHighestQuality,
                        preferredType: .mov,
                        fileExtension: "mov"
                    )
                }
            }
            throw error
        }
    }

    func saveToPhotoLibrary(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: VideoExportError.saveFailed(underlying: error))
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: VideoExportError.saveFailed(underlying: nil))
                }
            }
        }
    }

    func removeTemporaryFile(at url: URL) {
        guard isDailyLogTemporaryFile(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func cleanupStaleTemporaryFiles(olderThan age: TimeInterval = 24 * 60 * 60) {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-age)

        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in urls where isDailyLogTemporaryFile(url) {
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

    private func export(_ session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                if let error = session.error {
                    continuation.resume(
                        throwing: VideoExportError.exportFailed(
                            status: session.status,
                            underlying: error
                        )
                    )
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func runExport(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        presetName: String,
        preferredType: AVFileType,
        fileExtension: String
    ) async throws -> URL {
        let outputURL = makeTemporaryURL(fileExtension: fileExtension)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: presetName
        ) else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }

        exportSession.outputURL = outputURL
        if exportSession.supportedFileTypes.contains(preferredType) {
            exportSession.outputFileType = preferredType
        } else if let fallback = exportSession.supportedFileTypes.first {
            exportSession.outputFileType = fallback
        } else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        try await export(exportSession)

        guard exportSession.status == .completed else {
            throw VideoExportError.exportFailed(
                status: exportSession.status,
                underlying: exportSession.error
            )
        }

        return outputURL
    }

    private func makeTemporaryURL(fileExtension: String) -> URL {
        let filename = "daily-log-\(UUID().uuidString).\(fileExtension)"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func removeTemporaryFiles(_ urls: [URL]) {
        for url in urls {
            removeTemporaryFile(at: url)
        }
    }

    private func isDailyLogTemporaryFile(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        let temporaryDirectory = FileManager.default.temporaryDirectory.standardizedFileURL
        guard standardizedURL.deletingLastPathComponent() == temporaryDirectory else {
            return false
        }

        let fileName = standardizedURL.lastPathComponent
        let fileExtension = standardizedURL.pathExtension.lowercased()
        return fileName.hasPrefix("daily-log-") && ["mov", "mp4"].contains(fileExtension)
    }

    private func makeStillVideo(
        from image: UIImage,
        duration: TimeInterval,
        renderSize: CGSize
    ) async throws -> URL {
        let outputURL = makeTemporaryURL(fileExtension: "mov")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSize.width,
            AVVideoHeightKey: renderSize.height,
            AVVideoColorPropertiesKey: sdrColorProperties
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: renderSize.width,
            kCVPixelBufferHeightKey as String: renderSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        guard let buffer = makePixelBuffer(from: image, size: renderSize) else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }

        let frameDuration = CMTime(value: 1, timescale: frameRate)
        let frameCount = max(Int(duration * Double(frameRate)), 1)

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
            adaptor.append(buffer, withPresentationTime: presentationTime)
        }
        input.markAsFinished()
        try await finishWriting(writer)

        return outputURL
    }

    private func exportStillsOnly(
        items: [TimelineItem],
        timestamp: ProjectEditingConfiguration.Timestamp
    ) async throws -> URL {
        let outputURL = makeTemporaryURL(fileExtension: "mov")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSize.width,
            AVVideoHeightKey: renderSize.height,
            AVVideoColorPropertiesKey: sdrColorProperties
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: renderSize.width,
            kCVPixelBufferHeightKey as String: renderSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else {
            throw VideoExportError.exportFailed(status: nil, underlying: nil)
        }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var cursor = CMTime.zero
        let frameDuration = CMTime(value: 1, timescale: frameRate)

        for item in items {
            guard let image = await PhotoLibraryService.shared.requestPreviewImage(
                for: item.asset,
                targetSize: renderSize
            ),
            let buffer = makePixelBuffer(
                from: image,
                size: renderSize,
                timestampText: timestamp.enabled ? timestampText(for: item, style: timestamp) : nil,
                timestampStyle: timestamp
            ) else {
                continue
            }

            let durationSeconds = max(item.effectiveDuration, 0.5)
            let frameCount = max(Int(durationSeconds * Double(frameRate)), 1)

            for frame in 0..<frameCount {
                while !input.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                let presentationTime = cursor + CMTimeMultiply(frameDuration, multiplier: Int32(frame))
                adaptor.append(buffer, withPresentationTime: presentationTime)
            }
            cursor = cursor + CMTime(seconds: durationSeconds, preferredTimescale: frameRate)
        }

        input.markAsFinished()
        try await finishWriting(writer)

        return outputURL
    }

    private func finishWriting(_ writer: AVAssetWriter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func makePixelBuffer(
        from image: UIImage,
        size: CGSize,
        timestampText: String? = nil,
        timestampStyle: ProjectEditingConfiguration.Timestamp = .init()
    ) -> CVPixelBuffer? {
        guard let frameImage = renderedStillFrame(
            from: image,
            size: size,
            timestampText: timestampText,
            timestampStyle: timestampStyle
        ).cgImage else {
            return nil
        }

        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(.init(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        let colorSpace = CGColorSpace(name: CGColorSpace.itur_709) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        context.interpolationQuality = .high
        context.draw(frameImage, in: CGRect(origin: .zero, size: size))

        return buffer
    }

    private func renderedStillFrame(
        from image: UIImage,
        size: CGSize,
        timestampText: String? = nil,
        timestampStyle: ProjectEditingConfiguration.Timestamp = .init()
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }

            let scale = min(size.width / imageSize.width, size.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: scaledSize))

            if let timestampText {
                drawTimestamp(
                    timestampText,
                    style: timestampStyle,
                    in: CGRect(origin: .zero, size: size)
                )
            }
        }
    }

    private func timestampSegment(
        for item: TimelineItem,
        start: CMTime,
        duration: CMTime,
        style: ProjectEditingConfiguration.Timestamp
    ) -> TimestampSegment? {
        guard let text = timestampText(for: item, style: style) else { return nil }
        return TimestampSegment(text: text, start: start, duration: duration)
    }

    private func timestampText(for item: TimelineItem) -> String? {
        guard let date = item.captureTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func timestampText(
        for item: TimelineItem,
        style: ProjectEditingConfiguration.Timestamp
    ) -> String? {
        guard let time = timestampText(for: item) else { return nil }
        let note = item.configuration.timestampNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return time }
        return "\(time)  \(note)"
    }

    private func timestampAnimationTool(
        for segments: [TimestampSegment],
        style: ProjectEditingConfiguration.Timestamp,
        renderSize: CGSize
    ) -> AVVideoCompositionCoreAnimationTool? {
        guard !segments.isEmpty else { return nil }

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)

        for segment in segments {
            let timestampLayer = makeTimestampLayer(
                text: segment.text,
                style: style,
                renderSize: renderSize
            )
            timestampLayer.opacity = 0

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.beginTime = AVCoreAnimationBeginTimeAtZero + segment.start.seconds
            fade.duration = max(segment.duration.seconds, 0.01)
            fade.keyTimes = [0, 0.01, 0.99, 1]
            fade.values = [0, 1, 1, 0]
            fade.isRemovedOnCompletion = false
            fade.fillMode = .both
            timestampLayer.add(fade, forKey: "clipTimestampOpacity")

            parentLayer.addSublayer(timestampLayer)
        }

        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }

    private func makeTimestampLayer(
        text: String,
        style: ProjectEditingConfiguration.Timestamp,
        renderSize: CGSize
    ) -> CALayer {
        let fontSize: CGFloat = 48
        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = 16
        let margin: CGFloat = 56
        let topMargin: CGFloat = 112
        let textSize = (text as NSString).size(withAttributes: [
            .font: timestampUIFont(for: style.font, size: fontSize)
        ])
        let width = ceil(textSize.width + horizontalPadding * 2)
        let height = ceil(textSize.height + verticalPadding * 2)

        let container = CALayer()
        container.frame = CGRect(
            x: margin,
            y: topMargin,
            width: width,
            height: height
        )
        container.cornerRadius = 18
        container.backgroundColor = UIColor.black.withAlphaComponent(0.58).cgColor
        container.masksToBounds = true

        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.font = timestampUIFont(for: style.font, size: fontSize).fontName as CFTypeRef
        textLayer.fontSize = fontSize
        textLayer.frame = CGRect(
            x: horizontalPadding,
            y: verticalPadding - 2,
            width: width - horizontalPadding * 2,
            height: height - verticalPadding * 2 + 4
        )
        container.addSublayer(textLayer)

        return container
    }

    private func drawTimestamp(
        _ text: String,
        style: ProjectEditingConfiguration.Timestamp,
        in rect: CGRect
    ) {
        let fontSize: CGFloat = 48
        let font = timestampUIFont(for: style.font, size: fontSize)
        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = 16
        let margin: CGFloat = 56
        let topMargin: CGFloat = 112
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let badgeRect = CGRect(
            x: margin,
            y: topMargin,
            width: ceil(textSize.width + horizontalPadding * 2),
            height: ceil(textSize.height + verticalPadding * 2)
        )

        UIColor.black.withAlphaComponent(0.58).setFill()
        UIBezierPath(roundedRect: badgeRect, cornerRadius: 18).fill()

        (text as NSString).draw(
            in: CGRect(
                x: badgeRect.minX + horizontalPadding,
                y: badgeRect.minY + verticalPadding - 2,
                width: badgeRect.width - horizontalPadding * 2,
                height: badgeRect.height - verticalPadding * 2 + 4
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ]
        )
    }

    private func timestampUIFont(
        for font: ProjectEditingConfiguration.Timestamp.FontFace,
        size: CGFloat
    ) -> UIFont {
        switch font {
        case .system:
            return .systemFont(ofSize: size, weight: .semibold)
        case .rounded:
            let descriptor = UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
                .withDesign(.rounded) ?? UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        case .serif:
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2)
                .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title2)
            return UIFont(descriptor: descriptor, size: size)
        case .monospaced:
            return .monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        }
    }

    private func videoTransform(for track: AVAssetTrack, renderSize: CGSize) -> CGAffineTransform {
        let preferred = track.preferredTransform
        let transformedRect = CGRect(origin: .zero, size: track.naturalSize).applying(preferred)
        let width = abs(transformedRect.width)
        let height = abs(transformedRect.height)

        let scale = min(renderSize.width / width, renderSize.height / height)
        let scaledSize = CGSize(width: width * scale, height: height * scale)
        let translateX = (renderSize.width - scaledSize.width) / 2
        let translateY = (renderSize.height - scaledSize.height) / 2
        let normalize = CGAffineTransform(
            translationX: -transformedRect.minX,
            y: -transformedRect.minY
        )

        return preferred
            .concatenating(normalize)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: translateX, y: translateY))
    }
}
