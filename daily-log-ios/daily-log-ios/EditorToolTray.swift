//
//  EditorToolTray.swift
//  daily-log-ios
//
//  Horizontal tool selector + selected-tool panel.
//  Phase 2: scaffolds the UI only. Each tool panel will be
//  populated in Phase 3 (cut/speed/adjusts/crop) and Phase 4
//  (presets/canvas, audio, transcript).
//

import SwiftUI

struct EditorToolTray: View {
    @Bindable var viewModel: EditorViewModel
    var clipBinding: Binding<TimelineItem>?
    var onClipEditingStarted: () -> Void = {}
    var onClipEditingEnded: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            toolRow

            if let tool = viewModel.selectedTool {
                toolPanel(for: tool)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedTool)
        .padding(.vertical, 10)
    }

    // MARK: - Subviews

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(EditorViewModel.Tool.allCases) { tool in
                    ToolButton(
                        tool: tool,
                        isSelected: viewModel.selectedTool == tool
                    ) {
                        toggle(tool)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func toolPanel(for tool: EditorViewModel.Tool) -> some View {
        switch tool {
        case .cut:
            if let clipBinding {
                ClipTrimView(
                    item: clipBinding,
                    onEditingStarted: onClipEditingStarted,
                    onEditingEnded: onClipEditingEnded
                )
            } else {
                placeholderPanel(for: tool, message: "Tap a clip in the timeline strip to trim it.")
            }
        default:
            placeholderPanel(for: tool, message: placeholderCopy(for: tool))
        }
    }

    private func placeholderPanel(for tool: EditorViewModel.Tool, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tool.title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    private func toggle(_ tool: EditorViewModel.Tool) {
        if viewModel.selectedTool == tool {
            viewModel.selectedTool = nil
        } else {
            viewModel.selectedTool = tool
        }
    }

    private func placeholderCopy(for tool: EditorViewModel.Tool) -> String {
        switch tool {
        case .cut:        return "Tap a clip in the timeline strip to trim it."
        case .speed:      return "Change clip playback rate — coming in Phase 3."
        case .presets:    return "Canvas / aspect-ratio presets — coming in Phase 4."
        case .adjusts:    return "Brightness, contrast, saturation — coming in Phase 3."
        case .audio:      return "Audio overdub and mixing — coming in Phase 4."
        case .transcript: return "Auto-captions with edit support — coming in Phase 4."
        }
    }
}

// MARK: - ToolButton

private struct ToolButton: View {
    let tool: EditorViewModel.Tool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tool.systemImage)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.orange.opacity(0.18) : Color(.tertiarySystemBackground))
                    )
                    .foregroundStyle(isSelected ? Color.orange : Color.primary)
                Text(tool.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.orange : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
