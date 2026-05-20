//
//  EditorToolTray.swift
//  daily-log-ios
//

import SwiftUI

struct EditorToolTray: View {
    @Bindable var viewModel: EditorViewModel
    let canvasSubtitle: String

    private let visibleTools: [EditorViewModel.Tool] = [
        .presets,
        .audio,
        .adjusts,
        .speed
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(visibleTools) { tool in
                    EditorToolCard(
                        tool: tool,
                        subtitle: subtitle(for: tool),
                        isSelected: viewModel.selectedTool == tool
                    ) {
                        viewModel.selectedTool = tool
                    }
                    .frame(width: 104, height: 104)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private func subtitle(for tool: EditorViewModel.Tool) -> String? {
        switch tool {
        case .presets:
            return canvasSubtitle
        case .audio, .adjusts, .speed, .cut, .transcript:
            return nil
        }
    }
}

// MARK: - EditorToolCard

private struct EditorToolCard: View {
    let tool: EditorViewModel.Tool
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: tool.systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(height: 24)

                Text(tool.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? Color.blue.opacity(0.45) : Color.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue : .white.opacity(0.12), lineWidth: 1.2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
