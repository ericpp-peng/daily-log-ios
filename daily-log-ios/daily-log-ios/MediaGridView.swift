//
//  MediaGridView.swift
//  daily-log-ios
//

import SwiftUI
import Photos
import AVFoundation

struct MediaGridView: View {
    let date: Date
    let viewModel: MediaSelectionViewModel
    @State private var previewAsset: MediaAsset?

    private let gridSpacing: CGFloat = 2
    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 2),
        count: 3
    )

    private var dateTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: date)
    }

    var body: some View {
        Group {
            switch viewModel.authorizationStatus {
            case .denied:
                PermissionDeniedView()
            case .notDetermined:
                PermissionRequestView {
                    Task { await viewModel.requestPermission() }
                }
            default:
                contentView
            }
        }
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            switch viewModel.authorizationStatus {
            case .authorized, .limited:
                await viewModel.loadAssets(for: date)
            case .notDetermined:
                await viewModel.requestPermission()
                if case .authorized = viewModel.authorizationStatus {
                    await viewModel.loadAssets(for: date)
                } else if case .limited = viewModel.authorizationStatus {
                    await viewModel.loadAssets(for: date)
                }
            case .denied:
                break
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ZStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider()

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredAssets.isEmpty {
                    emptyState
                } else {
                    selectionBar
                    Divider()
                    grid
                }
            }

            if let previewAsset {
                MediaQuickPreviewOverlay(asset: previewAsset) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        self.previewAsset = nil
                    }
                }
                .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectedCount > 0, previewAsset == nil {
                bottomBar
            }
        }
    }

    // MARK: - Subviews

    private var filterBar: some View {
        HStack(spacing: 0) {
            FilterTab(title: "All", isSelected: viewModel.filter == .all) {
                viewModel.filter = .all
            }
            FilterTab(title: "Photos", isSelected: viewModel.filter == .photos) {
                viewModel.filter = .photos
            }
            FilterTab(title: "Videos", isSelected: viewModel.filter == .videos) {
                viewModel.filter = .videos
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var selectionBar: some View {
        HStack {
            Text("\(viewModel.assets.count) item\(viewModel.assets.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(viewModel.selectedCount == viewModel.assets.count ? "Clear All" : "Select All") {
                if viewModel.selectedCount == viewModel.assets.count {
                    viewModel.clearAll()
                } else {
                    viewModel.selectAll()
                }
            }
            .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.filteredAssets) { asset in
                    ThumbnailCell(
                        asset: asset,
                        onTap: {
                            viewModel.toggleSelection(for: asset.id)
                        },
                        onPreview: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                previewAsset = asset
                            }
                        }
                    )
                }
            }
            .padding(.top, gridSpacing)
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No media found for this date")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("\(viewModel.selectedCount) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink(destination: TimelineView(initialAssets: viewModel.selectedAssets)) {
                    Text("Next")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - FilterTab

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? Color(.systemBackground).clipShape(RoundedRectangle(cornerRadius: 8))
                        : nil
                )
                .padding(2)
        }
    }
}

// MARK: - ThumbnailCell

struct ThumbnailCell: View {
    let asset: MediaAsset
    let onTap: () -> Void
    let onPreview: () -> Void

    @State private var thumbnail: UIImage?
    private let thumbSize = CGSize(width: 224, height: 224)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                thumbnailContent
                    .frame(width: side, height: side)
                    .clipped()

                if asset.isSelected {
                    Color.orange.opacity(0.25)
                }
            }
            .overlay(alignment: .bottomLeading) {
                timestampBadge
            }
            .overlay(alignment: .bottomTrailing) {
                durationBadge
            }
            .overlay(alignment: .topLeading) {
                orientationBadge
            }
            .overlay(alignment: .topTrailing) {
                selectionBadge
            }
            .frame(width: side, height: side)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.35, perform: onPreview)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .task(id: asset.id) {
            thumbnail = await PhotoLibraryService.shared.requestPreviewImage(
                for: asset,
                targetSize: thumbSize
            )
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        } else {
            Color(.systemGray5)
                .overlay(ProgressView().scaleEffect(0.6))
        }
    }

    @ViewBuilder
    private var timestampBadge: some View {
        if let date = asset.creationDate ?? asset.modificationDate {
            Text(timeString(from: date))
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(5)
        }
    }

    @ViewBuilder
    private var durationBadge: some View {
        if asset.type == .video, let duration = asset.duration {
            Text(formatDuration(duration))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(5)
        }
    }

    private var orientationBadge: some View {
        Image(systemName: orientationIconName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 18)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(5)
    }

    private var orientationIconName: String {
        asset.phAsset.pixelWidth >= asset.phAsset.pixelHeight ? "rectangle" : "rectangle.portrait"
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(asset.isSelected ? Color.orange : Color.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            if asset.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(6)
    }

    private func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return mins > 0
            ? "\(mins):\(String(format: "%02d", secs))"
            : "0:\(String(format: "%02d", secs))"
    }
}

// MARK: - MediaQuickPreviewOverlay

private struct MediaQuickPreviewOverlay: View {
    let asset: MediaAsset
    let onDismiss: () -> Void

    @State private var previewImage: UIImage?
    @State private var player = AVPlayer()
    @State private var showsVideoPreview = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 10) {
                previewSurface
                    .frame(maxWidth: 320, maxHeight: 430)
                    .aspectRatio(assetAspectRatio, contentMode: .fit)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)

                metadata
            }
            .padding(.horizontal, 28)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.86, anchor: .center).combined(with: .opacity),
                    removal: .scale(scale: 0.96, anchor: .center).combined(with: .opacity)
                )
            )
        }
        .task(id: asset.id) {
            await loadPreview()
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    @ViewBuilder
    private var previewSurface: some View {
        if showsVideoPreview {
            VideoPlayerLayerView(player: player)
        } else if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
        } else {
            ProgressView()
                .tint(.white)
                .frame(width: 220, height: 260)
        }
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
            Text(titleText)
            if let duration = asset.duration {
                Text(formatDuration(duration))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.62))
        .clipShape(Capsule())
    }

    private var assetAspectRatio: CGFloat {
        let width = max(CGFloat(asset.phAsset.pixelWidth), 1)
        let height = max(CGFloat(asset.phAsset.pixelHeight), 1)
        return width / height
    }

    private var iconName: String {
        switch asset.type {
        case .video: return "video.fill"
        case .livePhoto: return "livephoto"
        case .image: return "photo.fill"
        case .unknown: return "questionmark.square.fill"
        }
    }

    private var titleText: String {
        guard let date = asset.creationDate ?? asset.modificationDate else {
            return "Preview"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func loadPreview() async {
        showsVideoPreview = false
        player.pause()
        player.replaceCurrentItem(with: nil)

        if asset.type == .video || asset.type == .livePhoto,
           let avAsset = await PhotoLibraryService.shared.requestAVAsset(for: asset) {
            configurePreviewAudioSession()
            let item = AVPlayerItem(asset: avAsset)
            player.replaceCurrentItem(with: item)
            player.volume = 1
            player.isMuted = false
            showsVideoPreview = true
            player.play()
            return
        }

        previewImage = await PhotoLibraryService.shared.requestPreviewImage(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200)
        )
    }

    private func configurePreviewAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // The preview can still show video if the audio session cannot be activated.
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return mins > 0
            ? "\(mins):\(String(format: "%02d", secs))"
            : "0:\(String(format: "%02d", secs))"
    }
}
