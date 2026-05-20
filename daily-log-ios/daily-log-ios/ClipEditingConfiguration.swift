//
//  ClipEditingConfiguration.swift
//  daily-log-ios
//
//  Per-clip resumable edit state. Modeled on VideoEditorKit's
//  `VideoEditingConfiguration` but scoped to a single timeline clip,
//  since Daily Log composes many clips into one output.
//

import Foundation

struct ClipEditingConfiguration: Codable, Equatable {
    var trim: Trim
    var displayDuration: TimeInterval
    var playback: Playback = .init()
    var crop: Crop = .init()
    var adjusts: Adjusts = .init()
    var livePhotoMode: LivePhotoMode = .photo
    var timestampNote: String = ""

    init(
        trim: Trim,
        displayDuration: TimeInterval,
        playback: Playback = .init(),
        crop: Crop = .init(),
        adjusts: Adjusts = .init(),
        livePhotoMode: LivePhotoMode = .photo,
        timestampNote: String = ""
    ) {
        self.trim = trim
        self.displayDuration = displayDuration
        self.playback = playback
        self.crop = crop
        self.adjusts = adjusts
        self.livePhotoMode = livePhotoMode
        self.timestampNote = timestampNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trim = try container.decode(Trim.self, forKey: .trim)
        displayDuration = try container.decode(TimeInterval.self, forKey: .displayDuration)
        playback = try container.decodeIfPresent(Playback.self, forKey: .playback) ?? .init()
        crop = try container.decodeIfPresent(Crop.self, forKey: .crop) ?? .init()
        adjusts = try container.decodeIfPresent(Adjusts.self, forKey: .adjusts) ?? .init()
        livePhotoMode = try container.decodeIfPresent(LivePhotoMode.self, forKey: .livePhotoMode) ?? .photo
        timestampNote = try container.decodeIfPresent(String.self, forKey: .timestampNote) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trim, forKey: .trim)
        try container.encode(displayDuration, forKey: .displayDuration)
        try container.encode(playback, forKey: .playback)
        try container.encode(crop, forKey: .crop)
        try container.encode(adjusts, forKey: .adjusts)
        try container.encode(livePhotoMode, forKey: .livePhotoMode)
        try container.encode(timestampNote, forKey: .timestampNote)
    }

    enum LivePhotoMode: String, Codable, Equatable {
        case photo
        case video
    }

    private enum CodingKeys: String, CodingKey {
        case trim
        case displayDuration
        case playback
        case crop
        case adjusts
        case livePhotoMode
        case timestampNote
    }

    struct Trim: Codable, Equatable {
        var lowerBound: TimeInterval
        var upperBound: TimeInterval
    }

    struct Playback: Codable, Equatable {
        var rate: Double = 1.0
    }

    struct Crop: Codable, Equatable {
        var rotationDegrees: Double = 0
        var isMirrored: Bool = false
        var freeformRect: FreeformRect? = nil
    }

    struct FreeformRect: Codable, Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    struct Adjusts: Codable, Equatable {
        var brightness: Double = 0
        var contrast: Double = 1
        var saturation: Double = 1
    }
}
