//
//  TimelineViewModel.swift
//  daily-log-ios
//

import Observation
import SwiftUI

@MainActor
@Observable
final class TimelineViewModel {
    var items: [TimelineItem] = []
    var project: ProjectEditingConfiguration = .init()

    static let defaultPhotoDuration: TimeInterval = 2.0
    static let defaultMaxVideoDuration: TimeInterval = 5.0
    static let minPhotoDuration: TimeInterval = 1.0
    static let maxPhotoDuration: TimeInterval = 8.0
    static let minVideoDuration: TimeInterval = 1.0

    func load(items: [TimelineItem], project: ProjectEditingConfiguration) {
        self.items = items
        self.project = project
        reindex()
    }

    func buildTimeline(from assets: [MediaAsset]) {
        let sorted = assets.sorted { $0.sortDate < $1.sortDate }
        items = sorted.enumerated().map { index, asset in
            TimelineItem(
                id: asset.id,
                asset: asset,
                orderIndex: index,
                configuration: Self.makeInitialConfiguration(for: asset)
            )
        }
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        reindex()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        reindex()
    }

    func addAssets(_ assets: [MediaAsset]) {
        let startIndex = items.count
        let newItems = assets.enumerated().map { offset, asset in
            TimelineItem(
                id: asset.id,
                asset: asset,
                orderIndex: startIndex + offset,
                configuration: Self.makeInitialConfiguration(for: asset)
            )
        }
        items.append(contentsOf: newItems)
    }

    var totalDuration: TimeInterval {
        items.reduce(0) { $0 + $1.effectiveDuration }
    }

    var totalDurationString: String {
        let total = Int(totalDuration)
        let mins = total / 60
        let secs = total % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(secs)s"
    }

    // MARK: - Configuration factory

    static func makeInitialConfiguration(for asset: MediaAsset) -> ClipEditingConfiguration {
        let isVideoPlayback = asset.type == .video || asset.type == .livePhoto
        let maxDuration = maxVideoDuration(for: asset)
        let defaultDuration = defaultDuration(for: asset)
        return ClipEditingConfiguration(
            trim: .init(
                lowerBound: 0,
                upperBound: isVideoPlayback ? maxDuration : defaultDuration
            ),
            displayDuration: defaultDuration,
            livePhotoMode: asset.type == .livePhoto ? .video : .photo
        )
    }

    static func defaultDuration(for asset: MediaAsset) -> TimeInterval {
        if asset.type == .video || asset.type == .livePhoto {
            let maxDuration = maxVideoDuration(for: asset)
            return max(minVideoDuration, min(maxDuration, defaultMaxVideoDuration))
        }
        return min(maxPhotoDuration, max(minPhotoDuration, defaultPhotoDuration))
    }

    static func maxVideoDuration(for asset: MediaAsset) -> TimeInterval {
        min(asset.duration ?? defaultMaxVideoDuration, defaultMaxVideoDuration)
    }

    // MARK: - Private

    private func reindex() {
        for i in items.indices {
            items[i].orderIndex = i
        }
    }
}
