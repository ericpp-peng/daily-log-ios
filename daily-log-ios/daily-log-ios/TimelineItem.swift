//
//  TimelineItem.swift
//  daily-log-ios
//

import Foundation

struct TimelineItem: Identifiable {
    let id: String
    let asset: MediaAsset
    var orderIndex: Int
    var configuration: ClipEditingConfiguration

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
        Self.formatTime(effectiveDuration)
    }

    var usesVideoPlayback: Bool {
        asset.type == .video || (asset.type == .livePhoto && configuration.livePhotoMode == .video)
    }

    var effectiveDuration: TimeInterval {
        if usesVideoPlayback {
            let rawTrim = max(0, configuration.trim.upperBound - configuration.trim.lowerBound)
            let rate = max(configuration.playback.rate, 0.01)
            return rawTrim / rate
        }
        return configuration.displayDuration
    }

    var trimRangeString: String {
        guard usesVideoPlayback else { return durationString }
        return "\(Self.formatTime(configuration.trim.lowerBound)) - \(Self.formatTime(configuration.trim.upperBound))"
    }

    static func formatTime(_ value: TimeInterval) -> String {
        let total = Int(value)
        let mins = total / 60
        let secs = total % 60
        return mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "0:\(String(format: "%02d", secs))"
    }
}
