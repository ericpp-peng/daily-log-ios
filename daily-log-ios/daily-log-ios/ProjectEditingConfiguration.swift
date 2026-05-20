//
//  ProjectEditingConfiguration.swift
//  daily-log-ios
//
//  Project-wide resumable edit state. Holds output-level settings
//  that apply across every clip in the timeline (canvas, watermark,
//  audio overdub, transcript) plus current UI presentation.
//

import Foundation

struct ProjectEditingConfiguration: Codable, Equatable {
    var canvas: Canvas = .init()
    var timestamp: Timestamp = .init()
    var watermark: Watermark? = nil
    var audio: Audio = .init()
    var transcript: Transcript = .init()
    var presentation: Presentation = .init()

    struct Canvas: Codable, Equatable {
        var preset: Preset = .vertical9x16

        enum Preset: String, Codable {
            case original
            case vertical9x16
            case square1x1
            case landscape16x9
        }
    }

    struct Watermark: Codable, Equatable {
        var position: Position = .bottomTrailing

        enum Position: String, Codable {
            case topLeading, topTrailing, bottomLeading, bottomTrailing
        }
    }

    struct Timestamp: Codable, Equatable {
        var enabled: Bool = true
        var font: FontFace = .rounded
        var note: String = ""

        enum FontFace: String, CaseIterable, Codable {
            case system
            case rounded
            case serif
            case monospaced

            var displayName: String {
                switch self {
                case .system: return "System"
                case .rounded: return "Rounded"
                case .serif: return "Serif"
                case .monospaced: return "Mono"
                }
            }
        }
    }

    struct Audio: Codable, Equatable {
        var recordedClipURL: URL? = nil
        var recordedClipDuration: TimeInterval = 0
        var recordedClipVolume: Double = 1
        var selectedTrack: SelectedTrack = .original

        enum SelectedTrack: String, Codable {
            case original
            case recorded
        }
    }

    struct Transcript: Codable, Equatable {
        var enabled: Bool = false
    }

    struct Presentation: Codable, Equatable {
        var selectedTool: Tool? = nil

        enum Tool: String, Codable {
            case cut, speed, presets, adjusts, audio, transcript
        }
    }
}
