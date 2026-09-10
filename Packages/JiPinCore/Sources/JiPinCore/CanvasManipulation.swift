import CoreGraphics
import Foundation

/// One pose and one focal point for translation, scale and rotation together.
public struct CanvasManipulation {
    public let original: LayerObject
    public let canvas: CGSize
    public let cell: CGRect?
    public let imageSize: CGSize
    public let anchor: CGPoint

    public init(object: LayerObject, canvas: CGSize, cell: CGRect?, imageSize: CGSize, anchor: CGPoint) {
        original = object; self.canvas = canvas; self.cell = cell; self.imageSize = imageSize; self.anchor = anchor
    }

    public func applying(centroid: CGPoint, scale: CGFloat, rotation: Double, snapAngles: Bool = false) -> LayerObject {
        guard scale.isFinite, scale > 0, rotation.isFinite, centroid.x.isFinite, centroid.y.isFinite else { return original }
        var next = original
        let angle = Self.normalizedAngle(original.transform.rotation + rotation)
        let snapped = (angle / 90).rounded() * 90
        next.transform.rotation = snapAngles && abs(angle - snapped) < 1.5 ? snapped : angle
        let delta = next.transform.rotation - original.transform.rotation
        if let cell, var photo = original.photo {
            let frame = LayoutEngine.photoDrawFrame(photo, cell: cell)
            let cropped = LayoutEngine.croppedSize(imageSize, crop: photo.crop)
            let old = LayoutEngine.fittedRect(imageSize: cropped, in: frame, mode: photo.contentMode,
                                              crop: photo.crop, rotation: original.transform.rotation, fixedFrame: true)
            var unitCrop = photo.crop; unitCrop.zoom = 1
            let base = LayoutEngine.fittedRect(imageSize: cropped, in: frame, mode: photo.contentMode,
                                               crop: unitCrop, rotation: next.transform.rotation, fixedFrame: true)
            photo.crop.zoom = min(max(Double(old.width * scale / max(base.width, 1)), 1), 4)
            let effectiveScale = base.width * photo.crop.zoom / max(old.width, 1)
            let origin = CGPoint(x: frame.midX, y: frame.midY)
            let flip: CGFloat = original.transform.scaleX < 0 ? -1 : 1
            let centerDelta = Self.rotate(CGPoint(x: photo.crop.offsetX * frame.width * flip, y: photo.crop.offsetY * frame.height), degrees: original.transform.rotation)
            let center = CGPoint(x: origin.x + centerDelta.x, y: origin.y + centerDelta.y)
            let moved = Self.rotate(CGPoint(x: (center.x - anchor.x) * effectiveScale, y: (center.y - anchor.y) * effectiveScale), degrees: delta)
            let local = Self.rotate(CGPoint(x: centroid.x + moved.x - origin.x, y: centroid.y + moved.y - origin.y), degrees: -next.transform.rotation)
            photo.crop.offsetX = local.x * flip / max(frame.width, 1)
            photo.crop.offsetY = local.y / max(frame.height, 1)
            photo.crop = Self.clampedCrop(photo, imageSize: imageSize, frame: frame, rotation: next.transform.rotation)
            next.photo = photo
        } else {
            let width = max(original.transform.width, 0.001), height = max(original.transform.height, 0.001)
            let factor = min(max(Double(scale), max(0.02 / width, 0.02 / height)), min(4 / width, 4 / height))
            let center = CGPoint(x: original.transform.centerX * canvas.width, y: original.transform.centerY * canvas.height)
            let moved = Self.rotate(CGPoint(x: (center.x - anchor.x) * factor, y: (center.y - anchor.y) * factor), degrees: delta)
            next.transform.centerX = (centroid.x + moved.x) / max(canvas.width, 1)
            next.transform.centerY = (centroid.y + moved.y) / max(canvas.height, 1)
            next.transform.width = width * factor; next.transform.height = height * factor
        }
        return next
    }

    public static func clampedCrop(_ photo: PhotoPayload, imageSize: CGSize, frame: CGRect, rotation: Double) -> PhotoCrop {
        var crop = photo.crop
        let rect = LayoutEngine.fittedRect(imageSize: LayoutEngine.croppedSize(imageSize, crop: crop), in: frame,
                                           mode: photo.contentMode, crop: crop, rotation: rotation, fixedFrame: true)
        let angle = rotation * .pi / 180, c = abs(cos(angle)), s = abs(sin(angle))
        let coverWidth = frame.width * c + frame.height * s
        let coverHeight = frame.height * c + frame.width * s
        let x = photo.contentMode == .fill ? max(0, (rect.width - coverWidth) / 2) : (rect.width + coverWidth) * 0.45
        let y = photo.contentMode == .fill ? max(0, (rect.height - coverHeight) / 2) : (rect.height + coverHeight) * 0.45
        crop.offsetX = min(max(crop.offsetX, -x / max(frame.width, 1)), x / max(frame.width, 1))
        crop.offsetY = min(max(crop.offsetY, -y / max(frame.height, 1)), y / max(frame.height, 1))
        return crop
    }
    public static func normalizedAngle(_ angle: Double) -> Double {
        let result = angle.truncatingRemainder(dividingBy: 360)
        return result > 180 ? result - 360 : result < -180 ? result + 360 : result
    }
    private static func rotate(_ point: CGPoint, degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180, c = cos(a), s = sin(a)
        return CGPoint(x: point.x * c - point.y * s, y: point.x * s + point.y * c)
    }
}
