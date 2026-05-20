//
//  TimelineView.swift
//  daily-log-ios
//

import SwiftUI

struct TimelineView: View {
    let initialAssets: [MediaAsset]
    @State private var viewModel = TimelineViewModel()

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                contentView
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.buildTimeline(from: initialAssets)
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()

            List {
                ForEach($viewModel.items) { $item in
                    TimelineItemRow(item: $item)
                }
                .onDelete(perform: viewModel.remove)
                .onMove(perform: viewModel.move)
            }
            .listStyle(.plain)

            bottomBar
        }
    }

    private var summaryBar: some View {
        HStack {
            Text("\(viewModel.items.count) item\(viewModel.items.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Total \(viewModel.totalDurationString)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No items in timeline")
                .foregroundStyle(.secondary)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.items.count) clips")
                        .font(.subheadline.weight(.medium))
                    Text(viewModel.totalDurationString + " total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink(
                    destination: EditorView(
                        initialItems: viewModel.items,
                        initialProject: viewModel.project
                    )
                ) {
                    HStack(spacing: 6) {
                        Text("Edit")
                            .font(.body.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .clipShape(Capsule())
                }
                .disabled(viewModel.items.isEmpty)
                .opacity(viewModel.items.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - TimelineItemRow

private struct TimelineItemRow: View {
    @Binding var item: TimelineItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                        .overlay(ProgressView().scaleEffect(0.5))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(item.captureTimeString)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 5) {
                    Image(systemName: typeIcon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.durationString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, alignment: .leading)

            TextField("Note", text: $item.configuration.timestampNote)
                .font(.subheadline)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer()
        }
        .padding(.vertical, 4)
        .task(id: item.id) {
            thumbnail = await PhotoLibraryService.shared.requestThumbnail(
                for: item.asset,
                targetSize: CGSize(width: 128, height: 128)
            )
        }
    }

    private var typeIcon: String {
        switch item.asset.type {
        case .video:     return "video.fill"
        case .livePhoto: return "livephoto"
        default:         return "photo.fill"
        }
    }
}
