//
//  DualHandleRangeSlider.swift
//  daily-log-ios
//
//  Two-handle range slider used by the cut/trim tool.
//  Mirrors VideoEditorKit's RangedSliderView pattern:
//  - Each handle tracks its own drag-start value so multi-touch is stable.
//  - Minimum distance is enforced symmetrically.
//  - onEditingStarted / onEditingEnded callbacks let the parent pause
//    the player and re-seek on commit.
//

import SwiftUI

struct DualHandleRangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    var minimumDistance: Double = 0.5
    var onEditingStarted: () -> Void = {}
    var onEditingEnded: () -> Void = {}

    @State private var leftDragStart: Double?
    @State private var rightDragStart: Double?

    private let handleWidth: CGFloat = 14
    private let handleHitSlop: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            sliderBody(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Layout

    private func sliderBody(width: CGFloat, height: CGFloat) -> some View {
        let totalRange = max(bounds.upperBound - bounds.lowerBound, 0.0001)
        let leftX = position(for: range.lowerBound, width: width, totalRange: totalRange)
        let rightX = position(for: range.upperBound, width: width, totalRange: totalRange)
        let selectionWidth = max(rightX - leftX, 0)

        return ZStack(alignment: .topLeading) {
            // Dim regions outside the selected range
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(leftX, 0), height: height)
                .allowsHitTesting(false)
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(width - rightX, 0), height: height)
                .offset(x: rightX)
                .allowsHitTesting(false)

            // Highlight border around the selection
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.orange, lineWidth: 2)
                .frame(width: selectionWidth, height: height)
                .offset(x: leftX)
                .allowsHitTesting(false)

            // Left handle
            handle()
                .offset(x: leftX - handleWidth, y: -3)
                .frame(width: handleWidth, height: height + 6)
                .contentShape(Rectangle().inset(by: -handleHitSlop))
                .gesture(handleGesture(
                    isLeft: true,
                    width: width,
                    totalRange: totalRange
                ))

            // Right handle
            handle()
                .offset(x: rightX, y: -3)
                .frame(width: handleWidth, height: height + 6)
                .contentShape(Rectangle().inset(by: -handleHitSlop))
                .gesture(handleGesture(
                    isLeft: false,
                    width: width,
                    totalRange: totalRange
                ))
        }
        .frame(width: width, height: height)
    }

    private func handle() -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.orange)
            .overlay {
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 14)
            }
    }

    // MARK: - Gestures

    private func handleGesture(
        isLeft: Bool,
        width: CGFloat,
        totalRange: Double
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isLeft {
                    if leftDragStart == nil {
                        leftDragStart = range.lowerBound
                        onEditingStarted()
                    }
                    applyLeftDrag(translation: value.translation.width, width: width, totalRange: totalRange)
                } else {
                    if rightDragStart == nil {
                        rightDragStart = range.upperBound
                        onEditingStarted()
                    }
                    applyRightDrag(translation: value.translation.width, width: width, totalRange: totalRange)
                }
            }
            .onEnded { _ in
                if isLeft {
                    if leftDragStart != nil {
                        leftDragStart = nil
                        onEditingEnded()
                    }
                } else {
                    if rightDragStart != nil {
                        rightDragStart = nil
                        onEditingEnded()
                    }
                }
            }
    }

    private func applyLeftDrag(translation: CGFloat, width: CGFloat, totalRange: Double) {
        guard let start = leftDragStart, width > 0 else { return }
        let deltaValue = Double(translation / width) * totalRange
        var proposed = start + deltaValue
        proposed = max(proposed, bounds.lowerBound)
        proposed = min(proposed, range.upperBound - minimumDistance)
        range = proposed...range.upperBound
    }

    private func applyRightDrag(translation: CGFloat, width: CGFloat, totalRange: Double) {
        guard let start = rightDragStart, width > 0 else { return }
        let deltaValue = Double(translation / width) * totalRange
        var proposed = start + deltaValue
        proposed = min(proposed, bounds.upperBound)
        proposed = max(proposed, range.lowerBound + minimumDistance)
        range = range.lowerBound...proposed
    }

    // MARK: - Helpers

    private func position(for value: Double, width: CGFloat, totalRange: Double) -> CGFloat {
        let normalized = (value - bounds.lowerBound) / totalRange
        return CGFloat(min(max(normalized, 0), 1)) * width
    }
}
