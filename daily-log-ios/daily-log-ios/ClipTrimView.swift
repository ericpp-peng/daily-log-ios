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
                lowerBound: trimLowerBinding(sourceDuration: sourceDuration),
                upperBound: trimUpperBinding(sourceDuration: sourceDuration),
                bounds: 0...sourceDuration,
                minimumDistance: minimumTrimDuration,
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

    private var minimumTrimDuration: Double {
        0.5
    }

    private func trimLowerBinding(sourceDuration: Double) -> Binding<Double> {
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

    private func trimUpperBinding(sourceDuration: Double) -> Binding<Double> {
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

    private func resolvedTrimUpper(sourceDuration: Double) -> Double {
        let lower = min(max(item.configuration.trim.lowerBound, 0), sourceDuration)
        return min(max(item.configuration.trim.upperBound, lower + minimumTrimDuration), sourceDuration)
    }

    // MARK: - Photo duration

    @ViewBuilder
    private var photoBody: some View {
        ZStack {
            ClipThumbnailStrip(asset: item.asset, thumbnailCount: 1)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            DualHandleRangeSlider(
                lowerBound: photoLowerBinding,
                upperBound: photoUpperBinding,
                bounds: photoDurationBounds,
                minimumDistance: TimelineViewModel.minPhotoDuration,
                onEditingStarted: onEditingStarted,
                onEditingEnded: onEditingEnded
            )
        }
        .frame(height: 64)

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
}
