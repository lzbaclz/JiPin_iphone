import SwiftUI
import UIKit
import JiPinCore

/// UIKit recognizers share a transaction and use the renderer's exact source/output
/// transform. Inspection zoom is separate from the exported composition.
struct IDPhotoCropView: UIViewRepresentable {
    var image: UIImage?
    var project: IDPhotoProject
    var sourceSize: CGSize
    var isBrush: Bool
    var isComparing: Bool
    var restores: Bool
    var brushDiameter: Double
    var enabled: Bool
    var onBegin: () -> Void
    var onCrop: (IDPhotoCrop) -> Void
    var onEnd: () -> Void
    var onStroke: (IDPhotoBrushStroke) -> Void

    func makeUIView(context: Context) -> IDPhotoCanvasView { IDPhotoCanvasView() }
    func updateUIView(_ view: IDPhotoCanvasView, context: Context) {
        view.configure(self)
    }
}

final class IDPhotoCanvasView: UIView, UIGestureRecognizerDelegate {
    private let photo = UIImageView()
    private let guide = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let cursor = CAShapeLayer()
    private var configuration: IDPhotoCropView?
    private var crop = IDPhotoCrop()
    private var contentRect = CGRect.zero
    private var inspectionScale: CGFloat = 1
    private var inspectionOffset = CGPoint.zero
    private var activeRecognizers: Set<ObjectIdentifier> = []
    private var brushPoints: [CGPoint] = []
    private var visualPoints: [CGPoint] = []
    private var strokeRadius = 0.01
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    private lazy var twoPan = UIPanGestureRecognizer(target: self, action: #selector(inspected(_:)))
    private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
    private lazy var rotation = UIRotationGestureRecognizer(target: self, action: #selector(rotated(_:)))
    private lazy var brushTap = UITapGestureRecognizer(target: self, action: #selector(dotted(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.secondarySystemGroupedBackground
        clipsToBounds = true
        photo.contentMode = .scaleToFill
        addSubview(photo)
        guide.strokeColor = UIColor.white.withAlphaComponent(0.65).cgColor
        guide.fillColor = UIColor.clear.cgColor
        guide.lineWidth = 1; guide.lineDashPattern = [5, 5]
        layer.addSublayer(guide)
        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.lineCap = .round; strokeLayer.lineJoin = .round
        layer.addSublayer(strokeLayer)
        cursor.strokeColor = UIColor.white.cgColor; cursor.fillColor = UIColor.clear.cgColor; cursor.lineWidth = 1.5
        layer.addSublayer(cursor)
        for recognizer in [pan, twoPan, pinch, rotation, brushTap] {
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = true
            addGestureRecognizer(recognizer)
        }
        brushTap.require(toFail: pan)
        twoPan.minimumNumberOfTouches = 2; twoPan.maximumNumberOfTouches = 2
        isAccessibilityElement = true
        accessibilityIdentifier = "idphoto-preview"
        accessibilityLabel = "证件照成品预览"
        accessibilityHint = "可在尺寸面板使用放大、缩小、方向和位置按钮精确调整。"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ value: IDPhotoCropView) {
        if configuration?.isBrush != value.isBrush {
            inspectionScale = 1; inspectionOffset = .zero
            brushPoints.removeAll(); visualPoints.removeAll()
            updateStroke()
        }
        configuration = value; crop = value.project.crop
        photo.image = value.image
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = value.isBrush ? 1 : 2
        twoPan.isEnabled = value.isBrush && value.enabled && !value.isComparing
        pan.isEnabled = value.enabled && !value.isComparing
        pinch.isEnabled = value.enabled && !value.isComparing
        rotation.isEnabled = !value.isBrush && value.enabled && !value.isComparing
        brushTap.isEnabled = value.isBrush && value.enabled && !value.isComparing
        guide.isHidden = value.isBrush || value.isComparing || activeRecognizers.isEmpty
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let cfg = configuration else { return }
        let output = cfg.project.template.pixelSize
        let available = bounds.insetBy(dx: 16, dy: 10)
        let factor = min(available.width / output.width, available.height / output.height)
        let size = CGSize(width: output.width * factor, height: output.height * factor)
        contentRect = CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        photo.transform = .identity
        photo.frame = contentRect
        if cfg.isBrush {
            photo.transform = CGAffineTransform(scaleX: inspectionScale, y: inspectionScale)
            photo.center = CGPoint(x: contentRect.midX + inspectionOffset.x, y: contentRect.midY + inspectionOffset.y)
        }
        let path = UIBezierPath(rect: contentRect)
        path.move(to: CGPoint(x: contentRect.midX, y: contentRect.minY)); path.addLine(to: CGPoint(x: contentRect.midX, y: contentRect.maxY))
        path.move(to: CGPoint(x: contentRect.minX, y: contentRect.minY + contentRect.height * 0.08))
        path.addLine(to: CGPoint(x: contentRect.maxX, y: contentRect.minY + contentRect.height * 0.08))
        guide.path = path.cgPath
    }

    private func outputPoint(_ point: CGPoint) -> CGPoint {
        guard let cfg = configuration, contentRect.width > 0 else { return .zero }
        let viewPoint = cfg.isBrush ? CGPoint(x: (point.x - contentRect.midX - inspectionOffset.x) / inspectionScale + contentRect.midX,
                                               y: (point.y - contentRect.midY - inspectionOffset.y) / inspectionScale + contentRect.midY) : point
        return CGPoint(x: (viewPoint.x - contentRect.minX) / contentRect.width * CGFloat(cfg.project.template.width),
                       y: (viewPoint.y - contentRect.minY) / contentRect.height * CGFloat(cfg.project.template.height))
    }

    private func sourcePoint(_ point: CGPoint) -> CGPoint? {
        guard let cfg = configuration else { return nil }
        let output = outputPoint(point)
        guard output.x >= 0, output.y >= 0, output.x <= CGFloat(cfg.project.template.width), output.y <= CGFloat(cfg.project.template.height) else { return nil }
        let result = IDPhotoGeometry.normalizedSourcePoint(fromOutput: output, sourceSize: cfg.sourceSize,
                                                          outputSize: cfg.project.template.pixelSize, crop: crop)
        guard (0...1).contains(result.x), (0...1).contains(result.y) else { return nil }
        return result
    }

    private func begin(_ gesture: UIGestureRecognizer) {
        if activeRecognizers.isEmpty { configuration?.onBegin() }
        activeRecognizers.insert(ObjectIdentifier(gesture)); guide.isHidden = configuration?.isBrush == true
    }
    private func end(_ gesture: UIGestureRecognizer) {
        activeRecognizers.remove(ObjectIdentifier(gesture))
        if activeRecognizers.isEmpty { configuration?.onEnd(); guide.isHidden = true }
    }

    private func submitCrop(_ value: IDPhotoCrop) {
        crop = value.clamped
        configuration?.onCrop(crop)
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        guard let cfg = configuration else { return }
        if cfg.isBrush { brush(gesture); return }
        if gesture.state == .began { begin(gesture) }
        if gesture.state == .began || gesture.state == .changed {
            let delta = gesture.translation(in: self)
            let outputDelta = CGPoint(x: delta.x / max(contentRect.width, 1) * CGFloat(cfg.project.template.width),
                                      y: delta.y / max(contentRect.height, 1) * CGFloat(cfg.project.template.height))
            let inverse = IDPhotoGeometry.transform(sourceSize: cfg.sourceSize, outputSize: cfg.project.template.pixelSize, crop: crop).inverted()
            let zero = CGPoint.zero.applying(inverse), moved = outputDelta.applying(inverse)
            var value = crop
            value.centerX -= Double((moved.x - zero.x) / cfg.sourceSize.width)
            value.centerY -= Double((moved.y - zero.y) / cfg.sourceSize.height)
            submitCrop(value)
            gesture.setTranslation(.zero, in: self)
        }
        if [.ended, .cancelled, .failed].contains(gesture.state) { end(gesture) }
    }

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        guard let cfg = configuration else { return }
        if cfg.isBrush {
            if gesture.state == .began || gesture.state == .changed {
                let old = inspectionScale
                inspectionScale = min(6, max(1, inspectionScale * gesture.scale))
                let anchor = gesture.location(in: self)
                let multiplier = inspectionScale / old
                inspectionOffset = CGPoint(x: (inspectionOffset.x - anchor.x + contentRect.midX) * multiplier + anchor.x - contentRect.midX,
                                           y: (inspectionOffset.y - anchor.y + contentRect.midY) * multiplier + anchor.y - contentRect.midY)
                clampInspection(); gesture.scale = 1; setNeedsLayout()
            }
            return
        }
        if gesture.state == .began { begin(gesture) }
        if gesture.state == .began || gesture.state == .changed {
            let anchor = outputPoint(gesture.location(in: self))
            anchoredAdjustment(anchor: anchor) { $0.zoom *= Double(gesture.scale) }
            gesture.scale = 1
        }
        if [.ended, .cancelled, .failed].contains(gesture.state) { end(gesture) }
    }

    @objc private func rotated(_ gesture: UIRotationGestureRecognizer) {
        if gesture.state == .began { begin(gesture) }
        if gesture.state == .began || gesture.state == .changed {
            let anchor = outputPoint(gesture.location(in: self))
            anchoredAdjustment(anchor: anchor) { $0.rotationDegrees += Double(gesture.rotation * 180 / .pi) }
            gesture.rotation = 0
        }
        if [.ended, .cancelled, .failed].contains(gesture.state) { end(gesture) }
    }

    private func anchoredAdjustment(anchor: CGPoint, change: (inout IDPhotoCrop) -> Void) {
        guard let cfg = configuration else { return }
        let size = cfg.sourceSize, output = cfg.project.template.pixelSize
        let previous = anchor.applying(IDPhotoGeometry.transform(sourceSize: size, outputSize: output, crop: crop).inverted())
        var value = crop; change(&value); value = value.clamped
        let after = anchor.applying(IDPhotoGeometry.transform(sourceSize: size, outputSize: output, crop: value).inverted())
        value.centerX += Double((previous.x - after.x) / size.width)
        value.centerY += Double((previous.y - after.y) / size.height)
        submitCrop(value)
    }

    @objc private func inspected(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began || gesture.state == .changed {
            let delta = gesture.translation(in: self)
            inspectionOffset.x += delta.x; inspectionOffset.y += delta.y
            clampInspection(); gesture.setTranslation(.zero, in: self); setNeedsLayout()
        }
    }

    private func clampInspection() {
        let x = contentRect.width * (inspectionScale - 1) / 2
        let y = contentRect.height * (inspectionScale - 1) / 2
        inspectionOffset.x = min(x, max(-x, inspectionOffset.x))
        inspectionOffset.y = min(y, max(-y, inspectionOffset.y))
    }

    private func brush(_ gesture: UIPanGestureRecognizer) {
        guard let cfg = configuration else { return }
        if gesture.state == .began {
            brushPoints = []; visualPoints = []
            let transform = IDPhotoGeometry.transform(sourceSize: cfg.sourceSize, outputSize: cfg.project.template.pixelSize, crop: crop)
            let sourceToOutputScale = hypot(transform.a, transform.b)
            let outputToViewScale = contentRect.width / CGFloat(cfg.project.template.width) * inspectionScale
            strokeRadius = min(0.25, max(0.0001, cfg.brushDiameter / 2 / Double(sourceToOutputScale * outputToViewScale * min(cfg.sourceSize.width, cfg.sourceSize.height))))
        }
        if gesture.state == .began || gesture.state == .changed || gesture.state == .ended {
            let point = gesture.location(in: self)
            if let normalized = sourcePoint(point), brushPoints.count < 8192 {
                brushPoints.append(normalized); visualPoints.append(point)
                updateStroke()
            }
        }
        if gesture.state == .ended {
            if !brushPoints.isEmpty {
                cfg.onStroke(IDPhotoBrushStroke(points: brushPoints, radius: strokeRadius, restores: cfg.restores))
            }
            brushPoints = []; visualPoints = []; updateStroke()
        } else if [.cancelled, .failed].contains(gesture.state) {
            brushPoints = []; visualPoints = []; updateStroke()
        }
    }

    @objc private func dotted(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let cfg = configuration,
              let normalized = sourcePoint(gesture.location(in: self)) else { return }
        let transform = IDPhotoGeometry.transform(sourceSize: cfg.sourceSize, outputSize: cfg.project.template.pixelSize, crop: crop)
        let scale = hypot(transform.a, transform.b) * contentRect.width / CGFloat(cfg.project.template.width) * inspectionScale
        let radius = min(0.25, max(0.0001, cfg.brushDiameter / 2 / Double(scale * min(cfg.sourceSize.width, cfg.sourceSize.height))))
        cfg.onStroke(IDPhotoBrushStroke(points: [normalized], radius: radius, restores: cfg.restores))
    }

    private func updateStroke() {
        guard let first = visualPoints.first, let cfg = configuration else {
            strokeLayer.path = nil; cursor.path = nil; return
        }
        let path = UIBezierPath(); path.move(to: first)
        for point in visualPoints.dropFirst() { path.addLine(to: point) }
        strokeLayer.path = path.cgPath
        strokeLayer.lineWidth = cfg.brushDiameter
        strokeLayer.strokeColor = (cfg.restores ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.32).cgColor
        if let point = visualPoints.last {
            cursor.path = UIBezierPath(ovalIn: CGRect(x: point.x - cfg.brushDiameter / 2, y: point.y - cfg.brushDiameter / 2,
                                                      width: cfg.brushDiameter, height: cfg.brushDiameter)).cgPath
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if configuration?.isBrush == true {
            return (gestureRecognizer === twoPan && otherGestureRecognizer === pinch) || (gestureRecognizer === pinch && otherGestureRecognizer === twoPan)
        }
        return true
    }
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard configuration?.enabled == true else { return false }
        if gestureRecognizer === pan, configuration?.isBrush == true {
            return sourcePoint(gestureRecognizer.location(in: self)) != nil
        }
        return bounds.contains(gestureRecognizer.location(in: self))
    }
}
