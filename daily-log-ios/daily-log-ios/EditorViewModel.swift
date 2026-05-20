//
//  EditorViewModel.swift
//  daily-log-ios
//
//  Ephemeral editor presentation state. Mirrors VideoEditorKit's
//  `EditorViewModel` role (own selected tool / UI presentation) but
//  much lighter — clip data lives in `TimelineViewModel`, playback
//  state lives in `VideoPlayerManager`, persisted edit snapshots
//  live in `ClipEditingConfiguration` / `ProjectEditingConfiguration`.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class EditorViewModel {
    var selectedTool: Tool? = .presets
    var showsSaveConfirmation: Bool = false

    enum Tool: String, CaseIterable, Identifiable {
        case cut
        case speed
        case presets
        case adjusts
        case audio
        case transcript

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cut:        return "Cut"
            case .speed:      return "Speed"
            case .presets:    return "Presets"
            case .adjusts:    return "Adjusts"
            case .audio:      return "Audio"
            case .transcript: return "Captions"
            }
        }

        var systemImage: String {
            switch self {
            case .cut:        return "scissors"
            case .speed:      return "timer"
            case .presets:    return "rectangle.on.rectangle"
            case .adjusts:    return "circle.righthalf.filled"
            case .audio:      return "waveform"
            case .transcript: return "text.bubble"
            }
        }
    }
}
