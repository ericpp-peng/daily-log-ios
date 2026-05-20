//
//  ClipTrimView.swift
//  daily-log-ios
//
//  Cut/trim tool panel. Composes ClipThumbnailStrip + DualHandleRangeSlider
//  for videos, or thumbnail + single slider for photos. The active clip
//  is passed in as a Binding<TimelineItem> so writes go straight into
//  the project's TimelineViewModel.items.
//

import SwiftUI

struct ClipTrimView: View {
    @Binding var item: TimelineItem
    var onEditingStarted: () -> Void = {}
    var onEditingEnded: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if item.asset.type == .video {
                videoBody
            } else {
                photoBody
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "scissors")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(item.asset.type == .video ? "Trim clip" : "Photo duration")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(item.durationString)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Video trim

    @ViewBuilder
    private var videoBody: some View {
        let sourceDuration = max(item.asset.duration ?? TimelineViewModel.defaultMaxVideoDuration, 0.5)

        ZStack {
            ClipThumbnailStrip(asset: item.asset, thumbnailCount: 8)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            DualHandleRangeSlider(
                range: trimBinding(sourceDuration: sourceDuration),
                bounds: 0...sourceDuration,
                minimumDistance: 0.5,
                onEditingStarted: onEditingStarted,
                onEditingEnded: onEditingEnded
            )
        }
        .frame(height: 56)

        HStack {
            Text("Start \(TimelineItem.formatTime(item.configuration.trim.lowerBound))")
            Spacer()
            Text("Length \(TimelineItem.formatTime(max(0, item.configuration.trim.upperBound - item.configuration.trim.lowerBound)))")
            Spacer()
            Text("End \(TimelineItem.formatTime(item.configuration.trim.upperBound))")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private func trimBinding(sourceDuration: Double) -> Binding<ClosedRange<Double>> {
        Binding(
            get: {
                let lower = min(max(item.configuration.trim.lowerBound, 0), sourceDuration)
                let upper = min(max(item.configuration.trim.upperBound, lower), sourceDuration)
                return lower...upper
            },
            set: { newRange in
                item.configuration.trim.lowerBound = newRange.lowerBound
                item.configuration.trim.upperBound = newRange.upperBound
            }
        )
    }

    // MARK: - Photo duration

    @ViewBuilder
    private var photoBody: some View {
        ClipThumbnailStrip(asset: item.asset, thumbnailCount: 1)
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

        Slider(
            value: $item.configuration.displayDuration,
            in: TimelineViewModel.minPhotoDuration...TimelineViewModel.maxPhotoDuration,
            step: 0.5,
            onEditingChanged: { editing in
                if editing {
                    onEditingStarted()
                } else {
                    onEditingEnded()
                }
            }
        )
        .tint(.orange)

        HStack {
            Text("Duration \(TimelineItem.formatTime(item.configuration.displayDuration))")
            Spacer()
            Text(String(
                format: "%.1fs – %.1fs",
                TimelineViewModel.minPhotoDuration,
                TimelineViewModel.maxPhotoDuration
            ))
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}
