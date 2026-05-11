//
//  TimelineViewModel.swift
//  daily-log-ios
//

import SwiftUI

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var items: [TimelineItem] = []

    static let defaultPhotoDuration: TimeInterval = 2.0
    static let defaultMaxVideoDuration: TimeInterval = 5.0

    func buildTimeline(from assets: [MediaAsset]) {
        let sorted = assets.sorted { $0.sortDate < $1.sortDate }
        items = sorted.enumerated().map { index, asset in
            TimelineItem(
                id: asset.id,
                asset: asset,
                displayDuration: effectiveDuration(for: asset),
                orderIndex: index
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

    var totalDuration: TimeInterval {
        items.reduce(0) { $0 + $1.displayDuration }
    }

    var totalDurationString: String {
        let total = Int(totalDuration)
        let mins = total / 60
        let secs = total % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(secs)s"
    }

    // MARK: - Private

    private func effectiveDuration(for asset: MediaAsset) -> TimeInterval {
        if asset.type == .video {
            return min(asset.duration ?? Self.defaultMaxVideoDuration, Self.defaultMaxVideoDuration)
        }
        return Self.defaultPhotoDuration
    }

    private func reindex() {
        for i in items.indices {
            items[i].orderIndex = i
        }
    }
}
