import JiPinCore
import SwiftUI
import UIKit.UIGestureRecognizerSubclass

/// A single recognizer owns all fingers, so adding/lifting a finger rebases the pose instead of
/// ending another recognizer's undo transaction or changing which photograph is being edited.
final class CanvasTouchRecognizer: UIGestureRecognizer {
    var firstContact: ((CGPoint) -> Void)?
    var notify: ((CanvasTouchRecognizer) -> Void)?
    var tap: ((CGPoint, Int) -> Void)?
    var canMove = false
    var canSwap = false
    private var fingers: [UITouch] = []
    private var holdTimer: Timer?
    private var firstPoint = CGPoint.zero
    private var referenceDistance: CGFloat = 1
    private var lastAngle: CGFloat = 0
    private var accumulatedAngle: CGFloat = 0
    private(set) var anchor = CGPoint.zero
    private(set) var centroid = CGPoint.zero
    private(set) var scale: CGFloat = 1
    private(set) var degrees: Double = 0
    private(set) var rebased = false
    private(set) var swapping = false
    var fingerCount: Int { min(fingers.count, 2) }
    private var isTracking: Bool { state == .possible || state == .began || state == .changed }

    private func points() -> [CGPoint] { fingers.prefix(2).map { $0.location(in: nil) } }
    private func rebase() {
        let p = points(); guard let first = p.first else { return }
        centroid = p.count == 2 ? CGPoint(x: (first.x + p[1].x) / 2, y: (first.y + p[1].y) / 2) : first
        anchor = centroid; scale = 1; degrees = 0; accumulatedAngle = 0
        if p.count == 2 {
            referenceDistance = max(hypot(p[1].x - first.x, p[1].y - first.y), 12)
            lastAngle = atan2(p[1].y - first.y, p[1].x - first.x)
        }
        rebased = true
    }
    private func measure() {
        let p = points(); guard let first = p.first else { return }
        centroid = p.count == 2 ? CGPoint(x: (first.x + p[1].x) / 2, y: (first.y + p[1].y) / 2) : first
        if p.count == 2 {
            scale = max(hypot(p[1].x - first.x, p[1].y - first.y), 1) / referenceDistance
            let angle = atan2(p[1].y - first.y, p[1].x - first.x)
            var delta = angle - lastAngle
            if delta > .pi { delta -= 2 * .pi }; if delta < -.pi { delta += 2 * .pi }
            accumulatedAngle += delta; lastAngle = angle
            degrees = Double(accumulatedAngle * 180 / .pi)
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTracking else { return }
        let fresh = fingers.isEmpty
        fingers.append(contentsOf: touches.sorted { $0.timestamp < $1.timestamp })
        if fresh {
            firstPoint = fingers[0].location(in: nil)
            firstContact?(firstPoint)
            if canSwap {
                let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
                    guard let self, self.state == .possible, self.fingerCount == 1 else { return }
                    self.swapping = true; self.state = .began; self.notify?(self)
                }
                holdTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        rebase()
        if fingerCount > 1 { holdTimer?.invalidate(); holdTimer = nil }
        if state == .began || state == .changed { state = .changed; notify?(self) }
        else if fingerCount == 2 { state = .began; notify?(self) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTracking else { return }
        rebased = false; measure()
        if state == .possible {
            guard hypot(centroid.x - firstPoint.x, centroid.y - firstPoint.y) > 3 else { return }
            holdTimer?.invalidate(); holdTimer = nil
            // Yield a one-finger browse to the ancestor scroll view. Once failed, later
            // touch callbacks must not restart an editing gesture or commit a tap.
            guard canMove else { state = .failed; return }
            state = .began
        } else { state = .changed }
        notify?(self)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTracking else { return }
        holdTimer?.invalidate(); holdTimer = nil
        rebased = false; measure()
        let wasPossible = state == .possible
        if !wasPossible { state = .changed; notify?(self) }
        fingers.removeAll { touches.contains($0) }
        if fingers.isEmpty {
            if wasPossible { tap?(centroid, touches.first?.tapCount ?? 1); state = .failed }
            else { state = .ended; notify?(self) }
        } else if !wasPossible {
            rebase(); state = .changed; notify?(self)
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard isTracking else { return }
        state = .cancelled; notify?(self)
    }
    override func reset() {
        super.reset(); holdTimer?.invalidate(); holdTimer = nil
        fingers = []; scale = 1; degrees = 0; rebased = false; swapping = false
    }
}

struct CanvasTouchSurface: UIViewRepresentable {
    @ObservedObject var session: EditorSession
    var canvasSize: CGSize
    @Binding var canvasZoom: CGFloat
    var description: String

    final class Surface: UIView {
        final class PhotoTarget: UIAccessibilityElement {
            var select: (() -> Void)?
            override func accessibilityActivate() -> Bool { select?(); return true }
        }
        let touch = CanvasTouchRecognizer()
        var canvasTarget: PhotoTarget?
        var photoTargets: [UUID: PhotoTarget] = [:]
        var stickerTargets: [UUID: PhotoTarget] = [:]

        var normalizedVisibleCenter: CGPoint? {
            guard window != nil, bounds.width > 0, bounds.height > 0 else { return nil }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    // SwiftUI can extend the scroll view beneath its safe-area tool panels.
                    // Convert its usable viewport into unscaled canvas coordinates; UIKit
                    // accounts for both the current content offset and the canvas zoom.
                    let viewport = scroll.bounds.inset(by: scroll.adjustedContentInset)
                    let visible = bounds.intersection(convert(viewport, from: scroll))
                    guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
                    return CGPoint(x: (visible.midX - bounds.minX) / bounds.width,
                                   y: (visible.midY - bounds.minY) / bounds.height)
                }
                ancestor = view.superview
            }
            return nil
        }
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true; backgroundColor = .clear
            addGestureRecognizer(touch)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    scroll.panGestureRecognizer.require(toFail: touch)
                    scroll.delaysContentTouches = false
                    break
                }
                ancestor = view.superview
            }
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> Surface {
        let surface = Surface()
        context.coordinator.surface = surface
        surface.touch.firstContact = { [weak coordinator = context.coordinator] in coordinator?.prepare(at: $0) }
        surface.touch.tap = { [weak coordinator = context.coordinator] in coordinator?.tap(at: $0, count: $1) }
        surface.touch.notify = { [weak coordinator = context.coordinator] in coordinator?.handle($0) }
        return surface
    }
    func updateUIView(_ view: Surface, context: Context) {
        context.coordinator.parent = self
        session.canvasInsertionPoint = { [weak view] in view?.normalizedVisibleCenter }
        let enabled = !session.isDrawingTool && context.environment.isEnabled
        if view.touch.isEnabled != enabled { view.touch.isEnabled = enabled }
        let frames = session.photoFrames(canvasSize: canvasSize)
        let canvas = view.canvasTarget ?? Surface.PhotoTarget(accessibilityContainer: view)
        canvas.accessibilityIdentifier = "editor-canvas"
        canvas.accessibilityLabel = "拼图画布"
        canvas.accessibilityValue = description
        canvas.accessibilityHint = session.isDrawingTool ? "在画布上拖动即可绘制" : session.project.mode == .longStrip
            ? "在照片上单指滑动浏览长图，双指平移、缩放和旋转照片；长按后拖动交换照片。文字和贴纸可直接拖动。"
            : "拖动平移照片，双指缩放旋转；长按后拖动交换照片。"
        canvas.accessibilityTraits = [.image, .allowsDirectInteraction]
        canvas.accessibilityFrameInContainerSpace = CGRect(origin: .zero, size: canvasSize)
        view.canvasTarget = canvas
        let photos = session.project.photoLayers.enumerated().compactMap { index, object -> Surface.PhotoTarget? in
            guard object.isVisible else { return nil }
            let element = view.photoTargets[object.id] ?? Surface.PhotoTarget(accessibilityContainer: view)
            view.photoTargets[object.id] = element
            element.accessibilityIdentifier = "canvas-photo-\(index)"
            element.accessibilityLabel = "照片 \(index + 1)"
            element.accessibilityTraits = object.id == session.selectedID ? [.image, .button, .selected] : [.image, .button]
            element.accessibilityFrameInContainerSpace = session.usesLayoutPhotoFrame(object) ? (frames[object.id] ?? .zero) : LayoutEngine.rotatedFrame(object.transform, canvasSize: canvasSize)
            element.select = { [weak session] in
                guard let session else { return }
                session.select(object.id, activatingTool: session.project.mode != .longStrip)
            }
            return element
        }
        view.photoTargets = view.photoTargets.filter { session.project.object(id: $0.key) != nil }
        let stickers = session.project.visibleObjects.filter { $0.kind == .sticker }.enumerated().map { index, object in
            let element = view.stickerTargets[object.id] ?? Surface.PhotoTarget(accessibilityContainer: view)
            view.stickerTargets[object.id] = element
            element.accessibilityIdentifier = "canvas-sticker-\(index)"
            element.accessibilityLabel = object.displayName
            element.accessibilityTraits = object.id == session.selectedID ? [.image, .button, .selected] : [.image, .button]
            element.accessibilityFrameInContainerSpace = LayoutEngine.rotatedFrame(object.transform, canvasSize: canvasSize)
            element.select = { [weak session] in session?.select(object.id) }
            return element
        }
        view.stickerTargets = view.stickerTargets.filter { session.project.object(id: $0.key) != nil }
        view.accessibilityElements = session.isDrawingTool ? [canvas] : [canvas] + photos + stickers
    }
    static func dismantleUIView(_ view: Surface, coordinator: Coordinator) {
        if coordinator.parent.session.isGestureActive { coordinator.parent.session.endGesture() }
        view.touch.isEnabled = false
        view.removeGestureRecognizer(view.touch)
    }

    @MainActor final class Coordinator: NSObject {
        var parent: CanvasTouchSurface
        weak var surface: Surface?
        private var target: UUID?
        private var pose: CanvasManipulation?
        private var zoom: CGFloat = 1
        private var projectID: UUID?
        private var defersPhotoSelection = false
        init(_ parent: CanvasTouchSurface) { self.parent = parent }
        private func local(_ point: CGPoint) -> CGPoint { surface?.convert(point, from: nil) ?? point }
        func prepare(at point: CGPoint) {
            let session = parent.session
            projectID = session.project.id
            target = session.hitTest(local(point), canvasSize: parent.canvasSize)
            let object = target.flatMap { session.project.object(id: $0) }
            defersPhotoSelection = session.project.mode == .longStrip && (object == nil || object?.kind == .photo)
            // Scrolling must not select each photo crossed, switch the tool panel, or
            // resize the viewport. A tap, two fingers, or a hold explicitly edits instead.
            if !defersPhotoSelection { session.select(target) }
            surface?.touch.canMove = object?.isLocked == false && !defersPhotoSelection
            surface?.touch.canSwap = object.map(session.usesLayoutPhotoFrame) == true && object?.isLocked == false
            pose = nil; zoom = parent.canvasZoom
        }
        func tap(at point: CGPoint, count: Int) {
            if defersPhotoSelection { parent.session.select(target, activatingTool: false) }
            guard count == 2, parent.session.selected?.kind == .text else { return }
            parent.session.activeTool = .text; parent.session.wantsTextFocus = true
        }
        private func baseline(_ gesture: CanvasTouchRecognizer) {
            let session = parent.session
            if let object = session.selected, !object.isLocked {
                let cell = session.usesLayoutPhotoFrame(object) ? session.photoFrames(canvasSize: parent.canvasSize)[object.id] : nil
                pose = CanvasManipulation(object: object, canvas: parent.canvasSize, cell: cell,
                    imageSize: object.photo.flatMap { session.assets.pixelSizes[$0.assetID] } ?? CGSize(width: 1000, height: 1000), anchor: local(gesture.anchor))
            } else { pose = nil; zoom = parent.canvasZoom }
        }
        func handle(_ gesture: CanvasTouchRecognizer) {
            let session = parent.session
            guard session.project.id == projectID else { return }
            if gesture.state == .began && defersPhotoSelection { session.select(target, activatingTool: false) }
            guard session.selectedID == target else { return }
            if gesture.state == .changed && !session.isGestureActive { gesture.state = .cancelled; return }
            switch gesture.state {
            case .began, .changed:
                if gesture.state == .began {
                    session.beginGesture(); baseline(gesture)
                    if gesture.swapping { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                } else if gesture.rebased { baseline(gesture) }
                if gesture.swapping { return }
                if let pose {
                    guard session.selected?.isLocked != true else { session.endGesture(); return }
                    var next = pose.applying(centroid: local(gesture.centroid), scale: gesture.scale, rotation: gesture.degrees,
                                            snapAngles: session.project.snapEnabled && abs(gesture.degrees) > 2)
                    if pose.cell == nil && gesture.fingerCount == 1 {
                        let snapped = LayoutEngine.snap(next.transform, canvasSize: parent.canvasSize,
                            others: session.project.objects.filter { $0.id != target }.map(\.transform), enabled: session.project.snapEnabled)
                        next.transform = snapped.0; session.guides = snapped.1
                    }
                    session.updateSelected {
                        $0.transform = next.transform
                        if let crop = next.photo?.crop { $0.photo?.crop = crop }
                    }
                } else { parent.canvasZoom = min(max(zoom * gesture.scale, 0.4), 4) }
            case .ended:
                if gesture.swapping, let target,
                   let end = session.hitTest(local(gesture.centroid), canvasSize: parent.canvasSize), target != end,
                   let object = session.project.object(id: end), session.usesLayoutPhotoFrame(object), !object.isLocked {
                    session.swapPhotos(a: target, b: end)
                    session.select(end, activatingTool: session.project.mode != .longStrip)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                session.endGesture(); pose = nil
            case .cancelled:
                session.cancelGesture(); pose = nil
            default: break
            }
        }
    }
}
