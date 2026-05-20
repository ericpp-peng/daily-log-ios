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
