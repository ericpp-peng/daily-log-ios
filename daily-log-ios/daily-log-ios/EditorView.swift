//
//  EditorView.swift
//  daily-log-ios
//

import SwiftUI
import Photos

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss

    let initialAssets: [MediaAsset]

    @State private var viewModel = TimelineViewModel()
    @State private var playerManager = VideoPlayerManager()
    @State private var editorViewModel = EditorViewModel()

    @State private var selectedItemId: String?
    @State private var draggedClipId: String?
    @State private var isExporting = false
    @State private var showExportAlert = false
    @State private var exportMessage = ""

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        return ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        previewSurface
                            .padding(.horizontal, 28)
                            .padding(.top, 26)

                        playbackTimeline(
                            clipBinding: selectedClipBinding(viewModel: bindableViewModel),
                            items: $bindableViewModel.items
                        )
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 24)
                }

                EditorToolTray(
                    viewModel: editorViewModel,
                    canvasSubtitle: viewModel.project.canvas.preset.displayName
                )
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage)
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.buildTimeline(from: initialAssets)
            }
            playerManager.load(items: viewModel.items)
            if selectedItemId == nil {
                selectedItemId = viewModel.items.first?.id
            }
            if let selectedItemId {
                playerManager.selectItem(id: selectedItemId)
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

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            Text("Editor")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            HStack {
                Button {
                    playerManager.pause()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                }

                Spacer()

                Button {
                    Task { await exportTimeline() }
                } label: {
                    topIconLabel(systemName: "square.and.arrow.up")
                }
                .disabled(isExporting || viewModel.items.isEmpty)

                Button {
                    Task { await exportTimeline() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                        if isExporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.title.weight(.medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                }
                .disabled(isExporting || viewModel.items.isEmpty)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func topIconLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.08))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }

    // MARK: - Preview

    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black)

            if let clip = currentClip {
                if clip.asset.type == .video {
                    VideoPlayerLayerView(player: playerManager.player)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if let image = playerManager.currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if playerManager.isLoadingClip {
                    ProgressView().tint(.white)
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .aspectRatio(viewModel.project.canvas.preset.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Playback Timeline

    private func playbackTimeline(
        clipBinding: Binding<TimelineItem>?,
        items: Binding<[TimelineItem]>
    ) -> some View {
        HStack(alignment: .center, spacing: 22) {
            Button {
                playerManager.toggle()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 72, height: 72)
                    .background(.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .disabled(viewModel.items.isEmpty)

            VStack(spacing: 8) {
                timeBadge

                if let clipBinding {
                    ClipPlaybackTimelineTrack(
                        item: clipBinding,
                        localPlaybackTime: currentClipLocalTime,
                        onEditingStarted: handleClipEditingStarted,
                        onEditingEnded: handleClipEditingEnded,
                        onSeekLocalTime: seekSelectedClip(toLocalTime:)
                    )
                    .frame(height: 64)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(height: 64)
                }

                timelineFooter

                clipSelectorStrip(items: items)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func clipSelectorStrip(items: Binding<[TimelineItem]>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { $item in
                    MiniTimelineClip(
                        item: item,
                        isSelected: item.id == selectedItemId
                    ) {
                        selectedItemId = item.id
                    }
                    .onDrag {
                        draggedClipId = item.id
                        return NSItemProvider(object: item.id as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: MiniClipDropDelegate(
                            itemId: item.id,
                            items: items,
                            draggedItemId: $draggedClipId
                        )
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 52)
    }

    private var timeBadge: some View {
        Text("\(Self.formatPreciseTime(currentClipLocalTime)) / \(Self.formatPreciseTime(currentClipDuration))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.09))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }

    private var timelineFooter: some View {
        HStack {
            Text(currentClipStartLabel)
            Spacer()
            Text(currentClipEndLabel)
        }
        .font(.caption.monospacedDigit().weight(.medium))
        .foregroundStyle(.white)
    }

    private var currentClipStartLabel: String {
        guard let clip = currentClip else { return "00:00.00" }
        if clip.asset.type == .video {
            return Self.formatPreciseTime(clip.configuration.trim.lowerBound)
        }
        return Self.formatPreciseTime(clip.configuration.trim.lowerBound)
    }

    private var currentClipEndLabel: String {
        guard let clip = currentClip else { return "00:00.00" }
        if clip.asset.type == .video {
            return Self.formatPreciseTime(clip.configuration.trim.upperBound)
        }
        return Self.formatPreciseTime(clip.configuration.trim.upperBound)
    }

    private var currentClipDuration: TimeInterval {
        currentClip?.effectiveDuration ?? 0
    }

    private var currentClipLocalTime: TimeInterval {
        guard let currentClip,
              let index = viewModel.items.firstIndex(where: { $0.id == currentClip.id }) else {
            return 0
        }
        let start = globalStartTime(forItemAt: index)
        return min(max(playerManager.globalTime - start, 0), currentClip.effectiveDuration)
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

    private func seekSelectedClip(toLocalTime localTime: TimeInterval) {
        guard let selectedItemId,
              let index = viewModel.items.firstIndex(where: { $0.id == selectedItemId }) else {
            return
        }
        let start = globalStartTime(forItemAt: index)
        playerManager.seek(toGlobal: start + localTime)
    }

    private func globalStartTime(forItemAt targetIndex: Int) -> TimeInterval {
        guard targetIndex > 0 else { return 0 }
        return viewModel.items.prefix(targetIndex).reduce(0) { $0 + $1.effectiveDuration }
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

    // MARK: - Export

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

    private static func formatPreciseTime(_ value: TimeInterval) -> String {
        let clamped = max(value, 0)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        let hundredths = Int((clamped - floor(clamped)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

// MARK: - ClipPlaybackTimelineTrack

private struct ClipPlaybackTimelineTrack: View {
    @Binding var item: TimelineItem

    let localPlaybackTime: TimeInterval
    let onEditingStarted: () -> Void
    let onEditingEnded: () -> Void
    let onSeekLocalTime: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ClipThumbnailStrip(asset: item.asset, thumbnailCount: thumbnailCount)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .gesture(seekGesture(width: proxy.size.width))

                trimOverlay(width: proxy.size.width)

                playhead(width: proxy.size.width)
            }
        }
    }

    private var thumbnailCount: Int {
        item.asset.type == .video ? 8 : 1
    }

    @ViewBuilder
    private func trimOverlay(width: CGFloat) -> some View {
        if item.asset.type == .video {
            let sourceDuration = videoSourceDuration
            DualHandleRangeSlider(
                lowerBound: trimLowerBinding(sourceDuration: sourceDuration),
                upperBound: trimUpperBinding(sourceDuration: sourceDuration),
                bounds: 0...sourceDuration,
                minimumDistance: minimumTrimDuration,
                onEditingStarted: onEditingStarted,
                onEditingEnded: onEditingEnded
            )
        } else {
            DualHandleRangeSlider(
                lowerBound: photoLowerBinding,
                upperBound: photoUpperBinding,
                bounds: photoDurationBounds,
                minimumDistance: TimelineViewModel.minPhotoDuration,
                onEditingStarted: onEditingStarted,
                onEditingEnded: onEditingEnded
            )
        }
    }

    private func playhead(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .offset(x: playheadX(width: width))
            .allowsHitTesting(false)
    }

    private var videoSourceDuration: TimeInterval {
        max(item.asset.duration ?? item.configuration.trim.upperBound, 0.5)
    }

    private var minimumTrimDuration: TimeInterval {
        0.5
    }

    private var photoDurationBounds: ClosedRange<Double> {
        0...TimelineViewModel.maxPhotoDuration
    }

    private var photoLowerBinding: Binding<Double> {
        Binding(
            get: {
                resolvedPhotoRange.lowerBound
            },
            set: { newValue in
                let range = resolvedPhotoRange
                let lower = min(
                    max(newValue, photoDurationBounds.lowerBound),
                    range.upperBound - TimelineViewModel.minPhotoDuration
                )
                setPhotoRange(lower...range.upperBound)
            }
        )
    }

    private var photoUpperBinding: Binding<Double> {
        Binding(
            get: {
                resolvedPhotoRange.upperBound
            },
            set: { newValue in
                let range = resolvedPhotoRange
                let upper = min(
                    max(newValue, range.lowerBound + TimelineViewModel.minPhotoDuration),
                    photoDurationBounds.upperBound
                )
                setPhotoRange(range.lowerBound...upper)
            }
        )
    }

    private var resolvedPhotoRange: ClosedRange<Double> {
        let lower = min(
            max(item.configuration.trim.lowerBound, photoDurationBounds.lowerBound),
            photoDurationBounds.upperBound - TimelineViewModel.minPhotoDuration
        )
        let upper = min(
            max(item.configuration.trim.upperBound, lower + TimelineViewModel.minPhotoDuration),
            photoDurationBounds.upperBound
        )
        return lower...upper
    }

    private func setPhotoRange(_ range: ClosedRange<Double>) {
        item.configuration.trim.lowerBound = range.lowerBound
        item.configuration.trim.upperBound = range.upperBound
        item.configuration.displayDuration = max(
            TimelineViewModel.minPhotoDuration,
            range.upperBound - range.lowerBound
        )
    }

    private func trimLowerBinding(sourceDuration: TimeInterval) -> Binding<Double> {
        Binding(
            get: {
                let upper = resolvedTrimUpper(sourceDuration: sourceDuration)
                return min(max(item.configuration.trim.lowerBound, 0), max(0, upper - minimumTrimDuration))
            },
            set: { newValue in
                let upper = resolvedTrimUpper(sourceDuration: sourceDuration)
                item.configuration.trim.lowerBound = min(max(newValue, 0), max(0, upper - minimumTrimDuration))
            }
        )
    }

    private func trimUpperBinding(sourceDuration: TimeInterval) -> Binding<Double> {
        Binding(
            get: {
                resolvedTrimUpper(sourceDuration: sourceDuration)
            },
            set: { newValue in
                let lower = min(max(item.configuration.trim.lowerBound, 0), sourceDuration)
                item.configuration.trim.upperBound = min(max(newValue, lower + minimumTrimDuration), sourceDuration)
            }
        )
    }

    private func resolvedTrimUpper(sourceDuration: TimeInterval) -> TimeInterval {
        let lower = min(max(item.configuration.trim.lowerBound, 0), sourceDuration)
        return min(max(item.configuration.trim.upperBound, lower + minimumTrimDuration), sourceDuration)
    }

    private func seekGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                seek(toX: value.location.x, width: width)
            }
            .onEnded { value in
                seek(toX: value.location.x, width: width)
            }
    }

    private func seek(toX x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let progress = min(max(x / width, 0), 1)

        if item.asset.type == .video {
            let sourceTime = (Double(progress) * videoSourceDuration)
                .clamped(to: item.configuration.trim.lowerBound...item.configuration.trim.upperBound)
            let rate = max(item.configuration.playback.rate, 0.01)
            onSeekLocalTime((sourceTime - item.configuration.trim.lowerBound) / rate)
        } else {
            let range = resolvedPhotoRange
            let photoTime = (Double(progress) * photoDurationBounds.upperBound)
                .clamped(to: range)
            onSeekLocalTime(photoTime - range.lowerBound)
        }
    }

    private func playheadX(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }

        if item.asset.type == .video {
            let rate = max(item.configuration.playback.rate, 0.01)
            let sourceTime = item.configuration.trim.lowerBound + (localPlaybackTime * rate)
            let progress = sourceTime / max(videoSourceDuration, 0.001)
            return min(max(CGFloat(progress) * width, 0), width)
        }

        let range = resolvedPhotoRange
        let sourceTime = range.lowerBound + localPlaybackTime
        let progress = sourceTime / max(photoDurationBounds.upperBound, 0.001)
        return min(max(CGFloat(progress) * width, 0), width)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Mini Timeline Rail

private struct MiniTimelineClip: View {
    let item: TimelineItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.white.opacity(0.08)
                            .overlay(ProgressView().scaleEffect(0.5).tint(.white))
                    }
                }
                .frame(width: 74, height: 44)
                .clipped()

                Image(systemName: item.asset.type == .video ? "video.fill" : "photo.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Color.yellow : .white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .opacity(isSelected ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .task(id: item.id) {
            thumbnail = await PhotoLibraryService.shared.requestThumbnail(
                for: item.asset,
                targetSize: CGSize(width: 148, height: 88)
            )
        }
    }
}

private struct MiniClipDropDelegate: DropDelegate {
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

private extension ProjectEditingConfiguration.Canvas.Preset {
    var displayName: String {
        switch self {
        case .original: return "Original"
        case .vertical9x16: return "Portrait 9:16"
        case .square1x1: return "Square 1:1"
        case .landscape16x9: return "Landscape 16:9"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .original, .vertical9x16:
            return 9.0 / 16.0
        case .square1x1:
            return 1.0
        case .landscape16x9:
            return 16.0 / 9.0
        }
    }
}

#Preview {
    EditorView(initialAssets: [])
}
