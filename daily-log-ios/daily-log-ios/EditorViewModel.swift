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
    var selectedTool: Tool? = nil
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
            case .presets:    return "Canvas"
            case .adjusts:    return "Adjust"
            case .audio:      return "Audio"
            case .transcript: return "Captions"
            }
        }

        var systemImage: String {
            switch self {
            case .cut:        return "scissors"
            case .speed:      return "speedometer"
            case .presets:    return "aspectratio"
            case .adjusts:    return "slider.horizontal.3"
            case .audio:      return "music.note"
            case .transcript: return "text.bubble"
            }
        }
    }
}
