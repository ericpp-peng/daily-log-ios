//
//  TimelineItem.swift
//  daily-log-ios
//

import Foundation

struct TimelineItem: Identifiable {
    let id: String
    let asset: MediaAsset
    var displayDuration: TimeInterval
    var orderIndex: Int

    var captureTime: Date? {
        asset.creationDate ?? asset.modificationDate
    }

    var captureTimeString: String {
        guard let date = captureTime else { return "Unknown time" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    var durationString: String {
        let total = Int(displayDuration)
        let mins = total / 60
        let secs = total % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(secs)s"
    }
}
