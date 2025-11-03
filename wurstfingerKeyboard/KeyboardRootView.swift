//
//  KeyboardRootView.swift
//  Wurstfinger
//
//  Created by Claas Flint on 24.10.25.
//

import Combine
import CoreGraphics
import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    var scaleAnchor: UnitPoint = .bottom
    var frameAlignment: Alignment = .bottom
    var overrideWidth: CGFloat? = nil

    var body: some View {
        // At aspectRatio 1.5 (default), use original height of 54pt
        // Lower ratio = taller keys, higher ratio = shorter keys
        let keyHeight = KeyboardConstants.KeyDimensions.height * (1.5 / viewModel.keyAspectRatio)

        // Calculate horizontal position offset
        let screenWidth = overrideWidth ?? UIScreen.main.bounds.width
        let availableSpace = screenWidth * (1 - viewModel.keyboardScale)
        let horizontalOffset = availableSpace * (viewModel.keyboardHorizontalPosition - 0.5)

        Grid(horizontalSpacing: KeyboardConstants.Layout.gridHorizontalSpacing,
             verticalSpacing: KeyboardConstants.Layout.gridVerticalSpacing) {
                GridRow {
                if viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        onCircularGesture: { direction in
                            viewModel.handleUtilityCircularGesture(.globe, direction: direction)
                        },
                        label: { AnyView(Image(systemName: "globe")) }
                    ) {
                        viewModel.handleAdvanceToNextInputMode()
                    }
                }

                keyCells(forRow: 0, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        onCircularGesture: { direction in
                            viewModel.handleUtilityCircularGesture(.globe, direction: direction)
                        },
                        label: { AnyView(Image(systemName: "globe")) }
                    ) {
                        viewModel.handleAdvanceToNextInputMode()
                    }
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        highlighted: { viewModel.isSymbolsToggleActive },
                        label: { AnyView(Text(viewModel.symbolToggleLabel)) }
                    ) {
                        viewModel.toggleSymbols()
                    }
                }

                keyCells(forRow: 1, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        highlighted: { viewModel.isSymbolsToggleActive },
                        label: { AnyView(Text(viewModel.symbolToggleLabel)) }
                    ) {
                        viewModel.toggleSymbols()
                    }
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        behavior: DeleteKeyBehavior(viewModel: viewModel)
                    )
                }

                keyCells(forRow: 2, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    KeyboardButton(
                        height: keyHeight,
                        behavior: DeleteKeyBehavior(viewModel: viewModel)
                    )
                }
            }

                GridRow {
                    if viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        label: { AnyView(Text("⏎")) }
                    ) {
                        viewModel.handleReturn()
                    }
                }

                keyCells(forRow: 3, keyHeight: keyHeight)
                spaceKey(columnSpan: viewModel.spaceColumnSpan, keyHeight: keyHeight)

                if !viewModel.utilityColumnLeading {
                    utilityButton(
                        height: keyHeight,
                        label: { AnyView(Text("⏎")) }
                    ) {
                        viewModel.handleReturn()
                    }
                }
            }
        }
        .padding(.horizontal, KeyboardConstants.Layout.horizontalPadding)
        .padding(.vertical, KeyboardConstants.Layout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
        .background(Color(.systemBackground))
        .scaleEffect(viewModel.keyboardScale, anchor: scaleAnchor)
        .offset(x: horizontalOffset)
    }

    @ViewBuilder
    private func keyCells(forRow index: Int, keyHeight: CGFloat) -> some View {
        if index < viewModel.rows.count {
            ForEach(viewModel.rows[index]) { key in
                KeyboardButton(
                    height: keyHeight,
                    behavior: DirectionalKeyBehavior(
                        label: { AnyView(Text(viewModel.displayText(for: key))) },
                        overlay: { Optional.some(AnyView(KeyHintOverlay(key: key))) },
                        configuration: { KeyboardButtonVisualConfiguration(fontSize: KeyboardConstants.FontSizes.keyLabel) },
                        callbacks: KeyboardButtonCallbacks(
                            onSwipe: { direction in
                                viewModel.handleKeySwipe(key, direction: direction)
                            },
                            onSwipeReturn: { direction in
                                viewModel.handleKeySwipeReturn(key, direction: direction)
                            },
                            onCircular: { direction in
                                viewModel.handleCircularGesture(for: key, direction: direction)
                            }
                        )
                    )
                )
            }
        } else {
            EmptyView()
        }
    }

    private func spaceKey(columnSpan: Int, keyHeight: CGFloat) -> some View {
        KeyboardButton(
            height: keyHeight,
            behavior: SpaceKeyBehavior(viewModel: viewModel)
        )
            .gridCellColumns(columnSpan)
    }

    private func utilityButton(
        height: CGFloat,
        fontSize: CGFloat = KeyboardConstants.FontSizes.utilityLabel,
        highlighted: @escaping () -> Bool = { false },
        onCircularGesture: ((KeyboardCircularDirection) -> Void)? = nil,
        label: @escaping () -> AnyView,
        action: @escaping () -> Void
    ) -> some View {
        KeyboardButton(
            height: height,
            behavior: DirectionalKeyBehavior(
                label: label,
                overlay: { nil },
                configuration: {
                    KeyboardButtonVisualConfiguration(
                        highlighted: highlighted(),
                        fontSize: fontSize
                    )
                },
                callbacks: KeyboardButtonCallbacks(
                    onTap: action,
                    onCircular: onCircularGesture
                )
            )
        )
    }
}

private struct KeyCap<Content: View>: View {
    let height: CGFloat
    let background: Color
    let highlighted: Bool
    let fontSize: CGFloat
    private let content: Content

    init(
        height: CGFloat,
        background: Color = Color(.secondarySystemBackground),
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.defaultLabel,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.background = background
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.content = content()
    }

    var body: some View {
        content
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary)
            .frame(minWidth: KeyboardConstants.KeyDimensions.minWidth, maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardConstants.KeyDimensions.cornerRadius)
                    .fill(highlighted ? Color.accentColor.opacity(0.25) : background)
            )
    }
}
 
private struct KeyboardButtonGestureContext {
    let activate: () -> Void
    let deactivate: () -> Void
    let setActive: (Bool) -> Void

    init(activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
        self.activate = activate
        self.deactivate = deactivate
        self.setActive = { isActive in
            isActive ? activate() : deactivate()
        }
    }
}

@inline(__always)
private func eraseToAnyGestureVoid<G: Gesture>(_ gesture: G) -> AnyGesture<Void> {
    AnyGesture(gesture.map { _ in () })
}

private struct KeyboardButtonVisualConfiguration {
    let highlighted: Bool
    let fontSize: CGFloat
    let inactiveBackground: Color
    let activeBackground: Color
    let accessibilityLabel: Text?

    init(
        highlighted: Bool = false,
        fontSize: CGFloat = KeyboardConstants.FontSizes.defaultLabel,
        inactiveBackground: Color = Color(.secondarySystemBackground),
        activeBackground: Color = Color(.tertiarySystemFill),
        accessibilityLabel: Text? = nil
    ) {
        self.highlighted = highlighted
        self.fontSize = fontSize
        self.inactiveBackground = inactiveBackground
        self.activeBackground = activeBackground
        self.accessibilityLabel = accessibilityLabel
    }
}

private struct KeyboardButtonCallbacks {
    var onTap: (() -> Void)? = nil
    var onSwipe: ((KeyboardDirection) -> Void)? = nil
    var onSwipeReturn: ((KeyboardDirection) -> Void)? = nil
    var onCircular: ((KeyboardCircularDirection) -> Void)? = nil
}

private protocol KeyboardButtonBehavior: ObservableObject {
    var visualConfiguration: KeyboardButtonVisualConfiguration { get }
    func labelView() -> AnyView
    func overlayView() -> AnyView?
    func primaryGesture(context: KeyboardButtonGestureContext) -> AnyGesture<Void>?
    func simultaneousGestures(context: KeyboardButtonGestureContext) -> [AnyGesture<Void>]
    func onDisappear()
}

private final class AnyKeyboardButtonBehavior: ObservableObject {
    private let wrapped: any KeyboardButtonBehavior
    private var cancellable: AnyCancellable?

    init(_ wrapped: some KeyboardButtonBehavior) {
        self.wrapped = wrapped
        cancellable = wrapped.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        cancellable?.cancel()
    }

    var visualConfiguration: KeyboardButtonVisualConfiguration {
        wrapped.visualConfiguration
    }

    func labelView() -> AnyView {
        wrapped.labelView()
    }

    func overlayView() -> AnyView? {
        wrapped.overlayView()
    }

    func primaryGesture(context: KeyboardButtonGestureContext) -> AnyGesture<Void>? {
        wrapped.primaryGesture(context: context)
    }

    func simultaneousGestures(context: KeyboardButtonGestureContext) -> [AnyGesture<Void>] {
        wrapped.simultaneousGestures(context: context)
    }

    func onDisappear() {
        wrapped.onDisappear()
    }
}

private struct KeyboardButton: View {
    let height: CGFloat
    @StateObject private var behavior: AnyKeyboardButtonBehavior
    @State private var isActive = false

    init(height: CGFloat, behavior: some KeyboardButtonBehavior) {
        self.height = height
        _behavior = StateObject(wrappedValue: AnyKeyboardButtonBehavior(behavior))
    }

    var body: some View {
        let config = behavior.visualConfiguration
        let context = KeyboardButtonGestureContext(
            activate: { isActive = true },
            deactivate: { isActive = false }
        )

        let baseView = KeyCap(
            height: height,
            background: isActive ? config.activeBackground : config.inactiveBackground,
            highlighted: config.highlighted,
            fontSize: config.fontSize
        ) {
            behavior.labelView()
        }
        .overlay(behavior.overlayView() ?? AnyView(EmptyView()))

        let accessibleView: AnyView = {
            if let label = config.accessibilityLabel {
                return AnyView(baseView.accessibilityLabel(label))
            } else {
                return AnyView(baseView)
            }
        }()

        let primaryAppliedView: AnyView = {
            guard let primaryGesture = behavior.primaryGesture(context: context) else {
                return accessibleView
            }
            return AnyView(accessibleView.gesture(primaryGesture))
        }()

        let combinedView = behavior
            .simultaneousGestures(context: context)
            .reduce(primaryAppliedView) { view, gesture in
                AnyView(view.simultaneousGesture(gesture))
            }

        return AnyView(
            combinedView
                .onDisappear {
                    behavior.onDisappear()
                    context.deactivate()
                }
        )
    }
}

private final class DirectionalKeyBehavior: KeyboardButtonBehavior {
    private let labelProvider: () -> AnyView
    private let overlayProvider: () -> AnyView?
    private let configurationProvider: () -> KeyboardButtonVisualConfiguration
    private let callbacks: KeyboardButtonCallbacks

    private var positions: [CGPoint] = []
    private var maxOffset: CGPoint = .zero

    init(
        label: @escaping () -> AnyView,
        overlay: @escaping () -> AnyView?,
        configuration: @escaping () -> KeyboardButtonVisualConfiguration,
        callbacks: KeyboardButtonCallbacks
    ) {
        self.labelProvider = label
        self.overlayProvider = overlay
        self.configurationProvider = configuration
        self.callbacks = callbacks
    }

    var visualConfiguration: KeyboardButtonVisualConfiguration {
        configurationProvider()
    }

    func labelView() -> AnyView {
        labelProvider()
    }

    func overlayView() -> AnyView? {
        overlayProvider()
    }

    func primaryGesture(context: KeyboardButtonGestureContext) -> AnyGesture<Void>? {
        eraseToAnyGestureVoid(
            DragGesture(minimumDistance: 0)
                .onChanged { [weak self] value in
                    guard let self else { return }

                    if positions.isEmpty {
                        positions = [CGPoint.zero]
                        maxOffset = .zero
                    }

                    let point = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(point)

                    if positions.count > KeyboardConstants.Gesture.positionBufferSize {
                        positions.removeFirst(positions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    if point.magnitude() > maxOffset.magnitude() {
                        maxOffset = point
                    }

                    context.activate()
                }
                .onEnded { [weak self] value in
                    guard let self else { return }

                    let finalPoint = CGPoint(x: value.translation.width, y: value.translation.height)
                    positions.append(finalPoint)

                    if positions.count > KeyboardConstants.Gesture.positionBufferSize {
                        positions.removeFirst(positions.count - KeyboardConstants.Gesture.positionBufferSize)
                    }

                    let maxDistance = maxOffset.magnitude()
                    let finalDistance = finalPoint.magnitude()

                    let finalOffsetThreshold = KeyboardConstants.Gesture.minSwipeLength * KeyboardConstants.Gesture.finalOffsetMultiplier

                    let maxDirection = KeyboardDirection.direction(
                        for: CGSize(width: maxOffset.x, height: maxOffset.y),
                        tolerance: 0
                    )

                    let circle = KeyboardGestureRecognizer.circularDirection(
                        positions: positions,
                        circleCompletionTolerance: KeyboardConstants.Gesture.circleCompletionTolerance,
                        minSwipeLength: KeyboardConstants.Gesture.minSwipeLength
                    )

                    let finalDirection = KeyboardDirection.direction(
                        for: value.translation,
                        tolerance: KeyboardConstants.Gesture.minSwipeLength
                    )

                    if let circle,
                       maxDistance >= KeyboardConstants.Gesture.minSwipeLength,
                       let onCircular = callbacks.onCircular {
                        onCircular(circle)
                        reset(context: context)
                        return
                    }

                    let finalOffsetSmallEnough = finalDistance <= finalOffsetThreshold || finalDirection != maxDirection

                    if maxDistance >= KeyboardConstants.Gesture.minSwipeLength, finalOffsetSmallEnough {
                        if maxDirection != .center {
                            triggerReturn(direction: maxDirection)
                        } else {
                            trigger(direction: finalDirection)
                        }
                    } else {
                        trigger(direction: finalDirection)
                    }

                    reset(context: context)
                }
        )
    }

    func simultaneousGestures(context: KeyboardButtonGestureContext) -> [AnyGesture<Void>] {
        []
    }

    func onDisappear() {
        positions.removeAll(keepingCapacity: false)
        maxOffset = .zero
    }

    private func trigger(direction: KeyboardDirection) {
        if let onSwipe = callbacks.onSwipe {
            onSwipe(direction)
        } else if direction == .center {
            callbacks.onTap?()
        } else if let onSwipeReturn = callbacks.onSwipeReturn {
            onSwipeReturn(direction)
        } else {
            callbacks.onTap?()
        }
    }

    private func triggerReturn(direction: KeyboardDirection) {
        if let onSwipeReturn = callbacks.onSwipeReturn {
            onSwipeReturn(direction)
        } else {
            trigger(direction: direction)
        }
    }

    private func reset(context: KeyboardButtonGestureContext) {
        positions.removeAll(keepingCapacity: false)
        maxOffset = .zero
        context.deactivate()
    }
}

private final class SpaceKeyBehavior: KeyboardButtonBehavior {
    private let viewModel: KeyboardViewModel

    private var dragStarted = false
    private var hasDragged = false
    private var isSelecting = false
    private var lastTranslation: CGSize = .zero

    init(viewModel: KeyboardViewModel) {
        self.viewModel = viewModel
    }

    var visualConfiguration: KeyboardButtonVisualConfiguration {
        KeyboardButtonVisualConfiguration(
            fontSize: KeyboardConstants.FontSizes.keyLabel,
            accessibilityLabel: Text("Leerzeichen")
        )
    }

    func labelView() -> AnyView {
        AnyView(Color.clear)
    }

    func overlayView() -> AnyView? {
        nil
    }

    func primaryGesture(context: KeyboardButtonGestureContext) -> AnyGesture<Void>? {
        eraseToAnyGestureVoid(
            DragGesture(minimumDistance: 0)
                .onChanged { [weak self] value in
                    guard let self else { return }

                    if !dragStarted {
                        dragStarted = true
                        viewModel.beginSpaceDrag()
                    }

                    let deltaX = value.translation.width - lastTranslation.width

                    if !isSelecting, abs(value.translation.height) >= KeyboardConstants.SpaceGestures.selectionActivationThreshold {
                        isSelecting = true
                        hasDragged = true
                        viewModel.beginSpaceSelection()
                    }

                    viewModel.updateSpaceDrag(deltaX: deltaX)

                    lastTranslation = value.translation

                    if !hasDragged, !isSelecting, abs(value.translation.width) >= KeyboardConstants.SpaceGestures.dragActivationThreshold {
                        hasDragged = true
                    }

                    context.activate()
                }
                .onEnded { [weak self] _ in
                    guard let self else { return }

                    if dragStarted {
                        viewModel.endSpaceDrag()
                    }

                    if !hasDragged, !isSelecting {
                        viewModel.handleSpace()
                    }

                    reset(context: context)
                }
        )
    }

    func simultaneousGestures(context: KeyboardButtonGestureContext) -> [AnyGesture<Void>] {
        []
    }

    func onDisappear() {
        if dragStarted {
            viewModel.endSpaceDrag()
        }
        resetFlags()
    }

    private func reset(context: KeyboardButtonGestureContext) {
        resetFlags()
        context.deactivate()
    }

    private func resetFlags() {
        dragStarted = false
        hasDragged = false
        isSelecting = false
        lastTranslation = .zero
    }
}

private final class DeleteKeyBehavior: KeyboardButtonBehavior {
    private let viewModel: KeyboardViewModel

    private var dragStarted = false
    private var hasDragged = false
    private var isSliding = false
    private var lastTranslation: CGSize = .zero
    private var totalTranslation: CGSize = .zero
    private var isRepeating = false
    private var repeatTimer: Timer?
    private var repeatTriggered = false

    init(viewModel: KeyboardViewModel) {
        self.viewModel = viewModel
    }

    var visualConfiguration: KeyboardButtonVisualConfiguration {
        KeyboardButtonVisualConfiguration(
            fontSize: KeyboardConstants.FontSizes.keyLabel,
            accessibilityLabel: Text("Löschen")
        )
    }

    func labelView() -> AnyView {
        AnyView(Image(systemName: "delete.left"))
    }

    func overlayView() -> AnyView? {
        nil
    }

    func primaryGesture(context: KeyboardButtonGestureContext) -> AnyGesture<Void>? {
        eraseToAnyGestureVoid(
            DragGesture(minimumDistance: 0)
                .onChanged { [weak self] value in
                    guard let self else { return }

                    if isRepeating {
                        stopRepeat()
                    }

                    if !dragStarted {
                        dragStarted = true
                    }

                    totalTranslation = value.translation

                    if !isSliding,
                       abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.slideActivationThreshold,
                       abs(totalTranslation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance {
                        isSliding = true
                        hasDragged = true
                        viewModel.beginDeleteDrag()
                        lastTranslation = totalTranslation
                        return
                    }

                    if isSliding {
                        let deltaX = totalTranslation.width - lastTranslation.width
                        viewModel.updateDeleteDrag(deltaX: deltaX)
                        lastTranslation = totalTranslation
                    } else {
                        if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.wordSwipeThreshold {
                            hasDragged = true
                        } else if abs(totalTranslation.width) >= KeyboardConstants.DeleteGestures.dragActivationThreshold {
                            hasDragged = true
                        }
                    }

                    lastTranslation = value.translation
                    context.activate()
                }
                .onEnded { [weak self] _ in
                    guard let self else { return }

                    stopRepeat()

                    if isSliding {
                        viewModel.endDeleteDrag()
                    } else {
                        let translation = totalTranslation
                        let isWordSwipe = translation.width <= -KeyboardConstants.DeleteGestures.wordSwipeThreshold &&
                            abs(translation.height) <= KeyboardConstants.DeleteGestures.verticalTolerance

                        if isWordSwipe {
                            viewModel.handleDeleteWord()
                        } else if !repeatTriggered && !hasDragged {
                            viewModel.handleDelete()
                        }
                    }

                    reset(context: context)
                }
        )
    }

    func simultaneousGestures(context: KeyboardButtonGestureContext) -> [AnyGesture<Void>] {
        [
            eraseToAnyGestureVoid(
                LongPressGesture(minimumDuration: KeyboardConstants.DeleteGestures.repeatDelay)
                    .onEnded { [weak self] _ in
                        guard let self else { return }
                        if !isSliding {
                            startRepeat()
                        }
                    }
            )
        ]
    }

    func onDisappear() {
        stopRepeat()
        if isSliding {
            viewModel.endDeleteDrag()
        }
        resetFlags()
    }

    private func startRepeat() {
        guard !isRepeating else { return }
        isRepeating = true
        repeatTriggered = false
        viewModel.handleDelete()
        repeatTriggered = true
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyboardConstants.DeleteGestures.repeatInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.repeatTriggered = true
            self.viewModel.handleDelete()
        }
    }

    private func stopRepeat() {
        if isRepeating {
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
        isRepeating = false
    }

    private func reset(context: KeyboardButtonGestureContext) {
        stopRepeat()
        resetFlags()
        context.deactivate()
    }

    private func resetFlags() {
        dragStarted = false
        hasDragged = false
        isSliding = false
        lastTranslation = .zero
        totalTranslation = .zero
        repeatTriggered = false
    }
}

private struct KeyHintOverlay: View {
    let key: MessagEaseKey

    private let directions: [KeyboardDirection] = KeyboardDirection.allCases.filter { $0 != .center }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ForEach(directions, id: \.self) { direction in
                if let label = key.primaryLabel(for: direction) {
                    hintText(label, emphasis: false)
                        .position(position(for: direction, returning: false, in: size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func hintText(_ text: String, emphasis: Bool) -> some View {
        Text(text)
            .font(.system(size: emphasis ? KeyboardConstants.FontSizes.hintEmphasis : KeyboardConstants.FontSizes.hintNormal,
                         weight: emphasis ? .semibold : .medium, design: .rounded))
            .foregroundStyle(emphasis ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.8))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .allowsHitTesting(false)
    }

    private func position(for direction: KeyboardDirection, returning: Bool, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        let margin: CGFloat = returning ? KeyboardConstants.Layout.hintMarginReturning : KeyboardConstants.Layout.hintMargin

        switch direction {
        case .up:
            return CGPoint(x: width / 2, y: margin)
        case .down:
            return CGPoint(x: width / 2, y: height - margin)
        case .left:
            return CGPoint(x: margin, y: height / 2)
        case .right:
            return CGPoint(x: width - margin, y: height / 2)
        case .upLeft:
            return CGPoint(x: margin, y: margin)
        case .upRight:
            return CGPoint(x: width - margin, y: margin)
        case .downLeft:
            return CGPoint(x: margin, y: height - margin)
        case .downRight:
            return CGPoint(x: width - margin, y: height - margin)
        case .center:
            return CGPoint(x: width / 2, y: height / 2)
        }
    }
}
