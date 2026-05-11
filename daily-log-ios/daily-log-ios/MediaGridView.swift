//
//  MediaGridView.swift
//  daily-log-ios
//

import SwiftUI
import Photos

struct MediaGridView: View {
    let date: Date
    @ObservedObject var viewModel: MediaSelectionViewModel

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 2)]

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
        .safeAreaInset(edge: .bottom) {
            if viewModel.selectedCount > 0 {
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
                    ThumbnailCell(asset: asset) {
                        viewModel.toggleSelection(for: asset.id)
                    }
                }
            }
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

    @State private var thumbnail: UIImage?
    private let thumbSize = CGSize(width: 224, height: 224)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
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
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()

            // Timestamp
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

            // Video duration badge (bottom trailing)
            if asset.type == .video, let duration = asset.duration {
                Text(formatDuration(duration))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(5)
            }

            // Selection tint
            if asset.isSelected {
                Color.orange.opacity(0.25)
            }
        }
        .overlay(alignment: .topTrailing) {
            selectionBadge
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .task(id: asset.id) {
            thumbnail = await PhotoLibraryService.shared.requestThumbnail(
                for: asset,
                targetSize: thumbSize
            )
        }
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
