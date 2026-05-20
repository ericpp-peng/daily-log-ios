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
    private enum ActiveHandle {
        case left
        case right
    }

    @Binding private var lowerBound: Double
    @Binding private var upperBound: Double

    let bounds: ClosedRange<Double>
    var minimumDistance: Double = 0.5
    var allowsLowerHandleEditing: Bool = true
    var allowsUpperHandleEditing: Bool = true
    var onEditingStarted: () -> Void = {}
    var onEditingEnded: () -> Void = {}

    @State private var leftDragStartX: CGFloat?
    @State private var rightDragStartX: CGFloat?
    @State private var lockedUpperBound: Double?
    @State private var lockedLowerBound: Double?
    @State private var activeHandle: ActiveHandle?

    private let handleWidth: CGFloat = 22
    private let minimumHandleHitSize = CGSize(width: 52, height: 52)

    init(
        lowerBound: Binding<Double>,
        upperBound: Binding<Double>,
        bounds: ClosedRange<Double>,
        minimumDistance: Double = 0.5,
        allowsLowerHandleEditing: Bool = true,
        allowsUpperHandleEditing: Bool = true,
        onEditingStarted: @escaping () -> Void = {},
        onEditingEnded: @escaping () -> Void = {}
    ) {
        self._lowerBound = lowerBound
        self._upperBound = upperBound
        self.bounds = bounds
        self.minimumDistance = minimumDistance
        self.allowsLowerHandleEditing = allowsLowerHandleEditing
        self.allowsUpperHandleEditing = allowsUpperHandleEditing
        self.onEditingStarted = onEditingStarted
        self.onEditingEnded = onEditingEnded
    }

    init(
        range: Binding<ClosedRange<Double>>,
        bounds: ClosedRange<Double>,
        minimumDistance: Double = 0.5,
        allowsLowerHandleEditing: Bool = true,
        allowsUpperHandleEditing: Bool = true,
        onEditingStarted: @escaping () -> Void = {},
        onEditingEnded: @escaping () -> Void = {}
    ) {
        self.init(
            lowerBound: Binding(
                get: { range.wrappedValue.lowerBound },
                set: { newValue in
                    range.wrappedValue = newValue...range.wrappedValue.upperBound
                }
            ),
            upperBound: Binding(
                get: { range.wrappedValue.upperBound },
                set: { newValue in
                    range.wrappedValue = range.wrappedValue.lowerBound...newValue
                }
            ),
            bounds: bounds,
            minimumDistance: minimumDistance,
            allowsLowerHandleEditing: allowsLowerHandleEditing,
            allowsUpperHandleEditing: allowsUpperHandleEditing,
            onEditingStarted: onEditingStarted,
            onEditingEnded: onEditingEnded
        )
    }

    private var currentRange: ClosedRange<Double> {
        let lower = clampedLowerBound
        let upper = clampedUpperBound(relativeTo: lower)
        return lower...upper
    }

    var body: some View {
        GeometryReader { geo in
            sliderBody(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Layout

    private func sliderBody(width: CGFloat, height: CGFloat) -> some View {
        let totalRange = max(bounds.upperBound - bounds.lowerBound, 0.0001)
        let range = currentRange
        let leftX = position(for: range.lowerBound, width: width, totalRange: totalRange)
        let rightX = position(for: range.upperBound, width: width, totalRange: totalRange)
        let selectionWidth = max(rightX - leftX, 0)

        return ZStack {
            // Dim regions outside the selected range
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(leftX, 0), height: height)
                .position(x: max(leftX, 0) / 2, y: height / 2)
                .allowsHitTesting(false)
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(width: max(width - rightX, 0), height: height)
                .position(x: rightX + max(width - rightX, 0) / 2, y: height / 2)
                .allowsHitTesting(false)

            // Highlight border around the selection
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.yellow, lineWidth: 3)
                .frame(width: selectionWidth, height: height)
                .position(x: leftX + selectionWidth / 2, y: height / 2)
                .allowsHitTesting(false)

            // Left handle
            handle(isLeading: true, height: height)
                .position(x: leftX, y: height / 2)
                .allowsHitTesting(allowsLowerHandleEditing)
                .highPriorityGesture(handleGesture(
                    isLeft: true,
                    width: width,
                    totalRange: totalRange
                ))

            // Right handle
            handle(isLeading: false, height: height)
                .position(x: rightX, y: height / 2)
                .allowsHitTesting(allowsUpperHandleEditing)
                .highPriorityGesture(handleGesture(
                    isLeft: false,
                    width: width,
                    totalRange: totalRange
                ))
        }
        .frame(width: width, height: height)
    }

    private func handle(isLeading: Bool, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.yellow)
                .frame(width: handleWidth, height: height + 6)
                .overlay {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 3, height: 3)
                        }
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: isLeading ? 8 : 0,
                            bottomLeading: isLeading ? 8 : 0,
                            bottomTrailing: isLeading ? 0 : 8,
                            topTrailing: isLeading ? 0 : 8
                        )
                    )
                )
        }
        .frame(
            width: minimumHandleHitSize.width,
            height: max(height + 18, minimumHandleHitSize.height)
        )
        .contentShape(Rectangle())
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
                    guard activeHandle == nil || activeHandle == .left else { return }
                    if leftDragStartX == nil {
                        activeHandle = .left
                        leftDragStartX = position(for: currentRange.lowerBound, width: width, totalRange: totalRange)
                        lockedUpperBound = currentRange.upperBound
                        onEditingStarted()
                    }
                    applyLeftDrag(translation: value.translation.width, width: width, totalRange: totalRange)
                } else {
                    guard activeHandle == nil || activeHandle == .right else { return }
                    if rightDragStartX == nil {
                        activeHandle = .right
                        rightDragStartX = position(for: currentRange.upperBound, width: width, totalRange: totalRange)
                        lockedLowerBound = currentRange.lowerBound
                        onEditingStarted()
                    }
                    applyRightDrag(translation: value.translation.width, width: width, totalRange: totalRange)
                }
            }
            .onEnded { _ in
                if isLeft {
                    if leftDragStartX != nil {
                        leftDragStartX = nil
                        lockedUpperBound = nil
                        activeHandle = nil
                        onEditingEnded()
                    }
                } else {
                    if rightDragStartX != nil {
                        rightDragStartX = nil
                        lockedLowerBound = nil
                        activeHandle = nil
                        onEditingEnded()
                    }
                }
            }
    }

    private func applyLeftDrag(translation: CGFloat, width: CGFloat, totalRange: Double) {
        guard let startX = leftDragStartX,
              let lockedUpperBound,
              width > 0 else { return }
        let maxX = position(for: lockedUpperBound - minimumDistance, width: width, totalRange: totalRange)
        let proposedX = min(max(startX + translation, 0), maxX)
        lowerBound = value(at: proposedX, width: width, totalRange: totalRange)
    }

    private func applyRightDrag(translation: CGFloat, width: CGFloat, totalRange: Double) {
        guard let startX = rightDragStartX,
              let lockedLowerBound,
              width > 0 else { return }
        let minX = position(for: lockedLowerBound + minimumDistance, width: width, totalRange: totalRange)
        let proposedX = max(min(startX + translation, width), minX)
        upperBound = value(at: proposedX, width: width, totalRange: totalRange)
    }

    // MARK: - Helpers

    private func position(for value: Double, width: CGFloat, totalRange: Double) -> CGFloat {
        let normalized = (value - bounds.lowerBound) / totalRange
        return CGFloat(min(max(normalized, 0), 1)) * width
    }

    private func value(at position: CGFloat, width: CGFloat, totalRange: Double) -> Double {
        guard width > 0 else { return bounds.lowerBound }
        let progress = min(max(position / width, 0), 1)
        let rawValue = bounds.lowerBound + (Double(progress) * totalRange)
        return min(max(rawValue, bounds.lowerBound), bounds.upperBound)
    }

    private var clampedLowerBound: Double {
        min(max(lowerBound, bounds.lowerBound), bounds.upperBound)
    }

    private func clampedUpperBound(relativeTo lower: Double) -> Double {
        min(max(upperBound, lower + minimumDistance), bounds.upperBound)
    }
}
