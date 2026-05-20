//
//  EditorView.swift
//  daily-log-ios
//

import SwiftUI
import Photos
import UniformTypeIdentifiers

struct EditorView: View {
    let initialAssets: [MediaAsset]
    @State private var viewModel = TimelineViewModel()
    @State private var playerManager = VideoPlayerManager()
    @State private var editorViewModel = EditorViewModel()

    @State private var selectedItemId: String?
    @State private var draggedClipId: String?
    @State private var isExporting = false
    @State private var showExportAlert = false
    @State private var exportMessage = ""

    private let pointsPerSecond: CGFloat = 32
    private let clipSpacing: CGFloat = 10

    var body: some View {
        @Bindable var viewModel = viewModel
        return ScrollView {
            VStack(spacing: 0) {
                timelineHeader
                Divider()
                timelineStrip
                Divider()
                selectedClipPreview
                Divider()
                EditorToolTray(
                    viewModel: editorViewModel,
                    clipBinding: selectedClipBinding(viewModel: viewModel),
                    onClipEditingStarted: handleClipEditingStarted,
                    onClipEditingEnded: handleClipEditingEnded
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
                .background(Color(.systemBackground))
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    editorViewModel.showsSaveConfirmation = true
                }
                .disabled(viewModel.items.isEmpty)
            }
        }
        .alert("Save", isPresented: $editorViewModel.showsSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Project saving will land with Phase 6 (draft persistence).")
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.buildTimeline(from: initialAssets)
            }
            playerManager.load(items: viewModel.items)
            if selectedItemId == nil {
                selectedItemId = viewModel.items.first?.id
            }
            if let id = selectedItemId {
                playerManager.selectItem(id: id)
            }
        }
        .onDisappear {
            playerManager.pause()
        }
        .onChange(of: selectedItemId) { _, newId in
            if let newId, playerManager.currentItem?.id != newId {
                playerManager.selectItem(id: newId)
            }
        }
        .onChange(of: viewModel.items.map(\.id)) { _, itemIds in
            playerManager.update(items: viewModel.items)
            if selectedItemId == nil || !itemIds.contains(where: { $0 == selectedItemId }) {
                selectedItemId = itemIds.first
            }
        }
        .onChange(of: playerManager.currentItem?.id) { _, newId in
            if let newId, selectedItemId != newId {
                selectedItemId = newId
            }
        }
    }

    // MARK: - Timeline

    private var timelineHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Timeline")
                    .font(.headline)
                Text("\(viewModel.items.count) clips ordered by capture time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(viewModel.totalDurationString)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var timelineStrip: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.secondarySystemBackground)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: clipSpacing) {
                        ForEach($viewModel.items) { $item in
                            TimelineClipBlock(
                                item: $item,
                                isSelected: item.id == selectedItemId,
                                width: clipWidth(for: item)
                            ) {
                                selectedItemId = item.id
                            }
                            .onDrag {
                                draggedClipId = item.id
                                return NSItemProvider(object: item.id as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: ClipDropDelegate(
                                    itemId: item.id,
                                    items: $viewModel.items,
                                    draggedItemId: $draggedClipId
                                )
                            )
                        }
                    }
                    .padding(.horizontal, max(16, proxy.size.width / 2 - 42))
                    .padding(.vertical, 18)
                }

                FixedPlayhead()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .frame(height: 132)
    }

    private func clipWidth(for item: TimelineItem) -> CGFloat {
        let duration = item.asset.type == .video ? item.effectiveDuration : item.configuration.displayDuration
        return min(max(CGFloat(duration) * pointsPerSecond, 84), 180)
    }

    // MARK: - Preview

    private var selectedClipPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentClip?.captureTimeString ?? "Select a clip")
                        .font(.subheadline.weight(.semibold))
                    if let clip = currentClip {
                        Text("\(clip.asset.type.label) · \(clip.durationString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Tap a clip block to preview it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(selectedItemId == nil)
            }

            previewSurface

            playbackControls
        }
        .padding(16)
    }

    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)

            if let clip = currentClip {
                if clip.asset.type == .video {
                    VideoPlayerLayerView(player: playerManager.player)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let image = playerManager.currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if playerManager.isLoadingClip {
                    ProgressView().tint(.white)
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var playbackControls: some View {
        HStack(spacing: 14) {
            Button {
                playerManager.toggle()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white)
                    .background(Color.orange)
                    .clipShape(Circle())
            }
            .disabled(viewModel.items.isEmpty)

            Slider(
                value: Binding(
                    get: { playerManager.globalTime },
                    set: { playerManager.seek(toGlobal: $0) }
                ),
                in: 0...max(playerManager.totalDuration, 0.01)
            )
            .tint(.orange)
            .disabled(viewModel.items.isEmpty)

            Text(timeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
    }

    private var timeText: String {
        let cur = TimelineItem.formatTime(playerManager.globalTime)
        let total = TimelineItem.formatTime(playerManager.totalDuration)
        return "\(cur) / \(total)"
    }

    private var currentClip: TimelineItem? {
        playerManager.currentItem ?? selectedItem
    }

    private var selectedItem: TimelineItem? {
        guard let selectedItemId else { return nil }
        return viewModel.items.first(where: { $0.id == selectedItemId })
    }

    private func selectedClipBinding(viewModel: TimelineViewModel) -> Binding<TimelineItem>? {
        guard let selectedItemId,
              let index = viewModel.items.firstIndex(where: { $0.id == selectedItemId }) else {
            return nil
        }
        return Binding(
            get: { viewModel.items[index] },
            set: { viewModel.items[index] = $0 }
        )
    }

    private func handleClipEditingStarted() {
        playerManager.pause()
    }

    private func handleClipEditingEnded() {
        playerManager.update(items: viewModel.items)
        if let selectedItemId {
            playerManager.selectItem(id: selectedItemId)
        }
    }

    private func removeSelected() {
        guard let selectedItemId,
              let index = viewModel.items.firstIndex(where: { $0.id == selectedItemId }) else {
            return
        }

        viewModel.items.remove(at: index)
        reindexTimelineItems()

        if viewModel.items.indices.contains(index) {
            self.selectedItemId = viewModel.items[index].id
        } else {
            self.selectedItemId = viewModel.items.last?.id
        }
    }

    private func reindexTimelineItems() {
        for index in viewModel.items.indices {
            viewModel.items[index].orderIndex = index
        }
    }

    // MARK: - Export

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.items.count) clips")
                    .font(.subheadline.weight(.medium))
                Text(viewModel.totalDurationString + " total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await exportTimeline() }
            } label: {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 72)
                } else {
                    Text("Export")
                        .font(.body.weight(.semibold))
                        .frame(width: 72)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .background(Color.orange)
            .clipShape(Capsule())
            .disabled(isExporting || viewModel.items.isEmpty)
            .opacity(isExporting || viewModel.items.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
    }

    private func exportTimeline() async {
        guard !isExporting else { return }
        isExporting = true
        exportMessage = ""

        do {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized else {
                throw VideoExportError.saveFailed(underlying: nil)
            }

            let url = try await VideoExportService.shared.export(items: viewModel.items)
            try await VideoExportService.shared.saveToPhotoLibrary(url: url)
            exportMessage = "Saved to Photos."
        } catch {
            exportMessage = error.localizedDescription
        }

        isExporting = false
        showExportAlert = true
    }
}

// MARK: - TimelineClipBlock

private struct TimelineClipBlock: View {
    @Binding var item: TimelineItem
    let isSelected: Bool
    let width: CGFloat
    let onSelect: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
                .frame(width: width, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 5) {
                    Image(systemName: item.asset.type.systemImageName)
                        .font(.caption2)
                    Text(item.durationString)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(.black.opacity(0.52))
                .clipShape(Capsule())
                .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 3)
            )

            Text(item.captureTimeString)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
        .task(id: item.id) {
            thumbnail = await PhotoLibraryService.shared.requestThumbnail(
                for: item.asset,
                targetSize: CGSize(width: 240, height: 240)
            )
        }
    }
}

private struct FixedPlayhead: View {
    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.orange)
                .frame(width: 14, height: 10)

            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: 98)
        }
        .shadow(color: .orange.opacity(0.35), radius: 2)
        .allowsHitTesting(false)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct ClipDropDelegate: DropDelegate {
    let itemId: String
    @Binding var items: [TimelineItem]
    @Binding var draggedItemId: String?

    func dropEntered(info: DropInfo) {
        guard let draggedItemId,
              draggedItemId != itemId,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItemId }),
              let toIndex = items.firstIndex(where: { $0.id == itemId }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            reindex()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemId = nil
        reindex()
        return true
    }

    private func reindex() {
        for index in items.indices {
            items[index].orderIndex = index
        }
    }
}

private extension MediaType {
    var label: String {
        switch self {
        case .video: return "Video"
        case .livePhoto: return "Live Photo"
        case .image: return "Photo"
        case .unknown: return "Media"
        }
    }

    var systemImageName: String {
        switch self {
        case .video: return "video.fill"
        case .livePhoto: return "livephoto"
        case .image, .unknown: return "photo.fill"
        }
    }
}

#Preview {
    EditorView(initialAssets: [])
}
