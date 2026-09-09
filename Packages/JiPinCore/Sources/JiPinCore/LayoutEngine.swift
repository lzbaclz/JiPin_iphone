import CoreGraphics
import Foundation

public struct CollageGridLayout: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var photoCount: Int
    public var cells: [NormalizedRect]

    public init(id: String, name: String, cells: [NormalizedRect]) {
        self.id = id
        self.name = name
        self.cells = cells
        self.photoCount = cells.count
    }
}

public enum CollageGridLayoutCatalog {
    public static let all: [CollageGridLayout] = makeAll()

    public static func layouts(forPhotoCount count: Int) -> [CollageGridLayout] {
        all.filter { $0.photoCount == count }
    }

    public static func layout(id: String) -> CollageGridLayout? {
        all.first { $0.id == id }
    }

    public static func defaultLayout(forPhotoCount count: Int) -> CollageGridLayout? {
        layouts(forPhotoCount: count).first
    }

    public static var coveredCounts: Set<Int> {
        Set(all.map(\.photoCount))
    }

    private static func makeAll() -> [CollageGridLayout] {
        var layouts: [CollageGridLayout] = []
        func add(_ id: String, _ name: String, _ cells: [NormalizedRect]) {
            layouts.append(CollageGridLayout(id: id, name: name, cells: cells))
        }

        add("g2-h", "左右对开", grid(rows: 1, cols: 2))
        add("g2-v", "上下对开", grid(rows: 2, cols: 1))
        add("g2-left-wide", "左大右小", [
            NormalizedRect(x: 0, y: 0, width: 0.66, height: 1),
            NormalizedRect(x: 0.66, y: 0, width: 0.34, height: 1)
        ])
        add("g2-right-wide", "左小右大", [
            NormalizedRect(x: 0, y: 0, width: 0.34, height: 1),
            NormalizedRect(x: 0.34, y: 0, width: 0.66, height: 1)
        ])
        add("g2-top-wide", "上大下小", [
            NormalizedRect(x: 0, y: 0, width: 1, height: 0.66),
            NormalizedRect(x: 0, y: 0.66, width: 1, height: 0.34)
        ])
        add("g2-bottom-wide", "上小下大", [
            NormalizedRect(x: 0, y: 0, width: 1, height: 0.34),
            NormalizedRect(x: 0, y: 0.34, width: 1, height: 0.66)
        ])

        add("g3-h", "三列横排", grid(rows: 1, cols: 3))
        add("g3-v", "三行竖排", grid(rows: 3, cols: 1))
        add("g3-top-one", "上一下二", [
            NormalizedRect(x: 0, y: 0, width: 1, height: 0.55),
            NormalizedRect(x: 0, y: 0.55, width: 0.5, height: 0.45),
            NormalizedRect(x: 0.5, y: 0.55, width: 0.5, height: 0.45)
        ])
        add("g3-bottom-one", "上二下一", [
            NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.45),
            NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.45),
            NormalizedRect(x: 0, y: 0.45, width: 1, height: 0.55)
        ])
        add("g3-left-one", "左一右二", [
            NormalizedRect(x: 0, y: 0, width: 0.58, height: 1),
            NormalizedRect(x: 0.58, y: 0, width: 0.42, height: 0.5),
            NormalizedRect(x: 0.58, y: 0.5, width: 0.42, height: 0.5)
        ])

        add("g4-grid", "四分格", grid(rows: 2, cols: 2))
        add("g4-h", "四列横排", grid(rows: 1, cols: 4))
        add("g4-v", "四行竖排", grid(rows: 4, cols: 1))
        add("g4-top-one", "上一下三", [
            NormalizedRect(x: 0, y: 0, width: 1, height: 0.58),
            NormalizedRect(x: 0, y: 0.58, width: 1 / 3, height: 0.42),
            NormalizedRect(x: 1 / 3, y: 0.58, width: 1 / 3, height: 0.42),
            NormalizedRect(x: 2 / 3, y: 0.58, width: 1 / 3, height: 0.42)
        ])
        add("g4-left-hero", "左主图三分屏", [
            NormalizedRect(x: 0, y: 0, width: 0.62, height: 1),
            NormalizedRect(x: 0.62, y: 0, width: 0.38, height: 1 / 3),
            NormalizedRect(x: 0.62, y: 1 / 3, width: 0.38, height: 1 / 3),
            NormalizedRect(x: 0.62, y: 2 / 3, width: 0.38, height: 1 / 3)
        ])

        add("g5-2-3", "上二下三", [
            NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5),
            NormalizedRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
            NormalizedRect(x: 0, y: 0.5, width: 1 / 3, height: 0.5),
            NormalizedRect(x: 1 / 3, y: 0.5, width: 1 / 3, height: 0.5),
            NormalizedRect(x: 2 / 3, y: 0.5, width: 1 / 3, height: 0.5)
        ])
        add("g5-1-4", "上一下四", [
            NormalizedRect(x: 0, y: 0, width: 1, height: 0.55),
            NormalizedRect(x: 0, y: 0.55, width: 0.25, height: 0.45),
            NormalizedRect(x: 0.25, y: 0.55, width: 0.25, height: 0.45),
            NormalizedRect(x: 0.5, y: 0.55, width: 0.25, height: 0.45),
            NormalizedRect(x: 0.75, y: 0.55, width: 0.25, height: 0.45)
        ])
        add("g5-hero-quad", "左主图四宫", [
            NormalizedRect(x: 0, y: 0, width: 0.5, height: 1),
            NormalizedRect(x: 0.5, y: 0, width: 0.25, height: 0.5),
            NormalizedRect(x: 0.75, y: 0, width: 0.25, height: 0.5),
            NormalizedRect(x: 0.5, y: 0.5, width: 0.25, height: 0.5),
            NormalizedRect(x: 0.75, y: 0.5, width: 0.25, height: 0.5)
        ])

        add("g6-2x3", "两行三列", grid(rows: 2, cols: 3))
        add("g6-3x2", "三行两列", grid(rows: 3, cols: 2))
        add("g6-hero", "上主图下五", stacked([
            (0, 0.52, 1),
            (0.52, 0.48, 5)
        ]))

        add("g7-3-4", "上三下四", stacked([
            (0, 0.5, 3),
            (0.5, 0.5, 4)
        ]))
        add("g7-hero", "上主图下六", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.4)]
            cells.append(contentsOf: grid(rows: 2, cols: 3).map {
                NormalizedRect(x: $0.x, y: 0.4 + $0.y * 0.6, width: $0.width, height: $0.height * 0.6)
            })
            return cells
        }())

        add("g8-2x4", "两行四列", grid(rows: 2, cols: 4))
        add("g8-4x2", "四行两列", grid(rows: 4, cols: 2))
        add("g8-3-5", "上三下五", stacked([
            (0, 0.42, 3),
            (0.42, 0.58, 5)
        ]))
        add("g8-hero", "上主图下七", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.4)]
            cells.append(contentsOf: stacked([(0.4, 0.6, 7)]))
            return cells
        }())
        add("g9-3x3", "九宫格", grid(rows: 3, cols: 3))
        add("g9-1-8", "上一下八", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.4)]
            cells.append(contentsOf: stacked([(0.4, 0.6, 8)]))
            return cells
        }())
        add("g9-3-6", "上三下六", stacked([
            (0, 0.4, 3),
            (0.4, 0.6, 6)
        ]))
        add("g9-left-hero", "左主图八宫", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 0.5, height: 1)]
            cells.append(contentsOf: grid(rows: 4, cols: 2).map {
                NormalizedRect(x: 0.5 + $0.x * 0.5, y: $0.y, width: $0.width * 0.5, height: $0.height)
            })
            return cells
        }())
        add("g10-2x5", "两行五列", grid(rows: 2, cols: 5))
        add("g10-hero", "上主图下九", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.4)]
            cells.append(contentsOf: stacked([(0.4, 0.6, 9)]))
            return cells
        }())
        add("g11-mixed", "三加四加四", stacked([
            (0, 0.34, 3),
            (0.34, 0.33, 4),
            (0.67, 0.33, 4)
        ]))
        add("g11-hero", "上主图下十", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.38)]
            cells.append(contentsOf: stacked([(0.38, 0.62, 10)]))
            return cells
        }())
        add("g12-3x4", "三行四列", grid(rows: 3, cols: 4))
        add("g12-2x6", "两行六列", grid(rows: 2, cols: 6))
        add("g13-mixed", "四加五加四", stacked([
            (0, 0.34, 4),
            (0.34, 0.33, 5),
            (0.67, 0.33, 4)
        ]))
        add("g13-hero", "上主图下十二", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.36)]
            cells.append(contentsOf: stacked([(0.36, 0.64, 12)]))
            return cells
        }())
        add("g14-2x7", "两行七列", grid(rows: 2, cols: 7))
        add("g14-7x2", "七行两列", grid(rows: 7, cols: 2))
        add("g15-3x5", "三行五列", grid(rows: 3, cols: 5))
        add("g15-hero", "上主图下十四", {
            var cells = [NormalizedRect(x: 0, y: 0, width: 1, height: 0.34)]
            cells.append(contentsOf: stacked([(0.34, 0.66, 14)]))
            return cells
        }())
        add("g16-4x4", "十六宫格", grid(rows: 4, cols: 4))
        add("g16-2x8", "两行八列", grid(rows: 2, cols: 8))

        return layouts
    }

    private static func stacked(_ rows: [(y: Double, height: Double, cols: Int)]) -> [NormalizedRect] {
        var cells: [NormalizedRect] = []
        for row in rows {
            let width = 1 / Double(row.cols)
            for col in 0..<row.cols {
                cells.append(NormalizedRect(x: Double(col) * width, y: row.y, width: width, height: row.height))
            }
        }
        return cells
    }

    private static func grid(rows: Int, cols: Int) -> [NormalizedRect] {
        var cells: [NormalizedRect] = []
        let w = 1 / Double(cols)
        let h = 1 / Double(rows)
        for r in 0..<rows {
            for c in 0..<cols {
                cells.append(NormalizedRect(x: Double(c) * w, y: Double(r) * h, width: w, height: h))
            }
        }
        return cells
    }
}

public enum LayoutEngine {
    public static func frames(
        layout: CollageGridLayout,
        canvasSize: CGSize,
        spacing: CGFloat,
        margin: CGFloat
    ) -> [CGRect] {
        let inset = CGRect(origin: .zero, size: canvasSize).insetBy(dx: margin, dy: margin)
        guard inset.width > 1, inset.height > 1 else { return [] }
        let halfGap = spacing / 2
        return layout.cells.map { cell in
            var rect = CGRect(
                x: inset.minX + CGFloat(cell.x) * inset.width,
                y: inset.minY + CGFloat(cell.y) * inset.height,
                width: CGFloat(cell.width) * inset.width,
                height: CGFloat(cell.height) * inset.height
            )
            if spacing > 0 {
                let minX = rect.minX <= inset.minX + 0.5 ? 0 : halfGap
                let minY = rect.minY <= inset.minY + 0.5 ? 0 : halfGap
                let maxX = rect.maxX >= inset.maxX - 0.5 ? 0 : halfGap
                let maxY = rect.maxY >= inset.maxY - 0.5 ? 0 : halfGap
                rect = CGRect(
                    x: rect.minX + minX,
                    y: rect.minY + minY,
                    width: max(rect.width - minX - maxX, 1),
                    height: max(rect.height - minY - maxY, 1)
                )
            } else {
                rect = rect.insetBy(dx: -2, dy: -2)
            }
            return rect
        }
    }

    public static func longStripFrames(
        photos: [(id: UUID, pixelSize: CGSize, crop: PhotoCrop)],
        direction: StripDirection,
        canvasLong: CGFloat,
        spacing: CGFloat,
        margin: CGFloat
    ) -> (canvas: CGSize, frames: [UUID: CGRect]) {
        var frames: [UUID: CGRect] = [:]
        if direction == .vertical {
            let width = canvasLong
            let innerWidth = max(width - margin * 2, 1)
            var y = margin
            for photo in photos {
                let cropped = croppedSize(photo.pixelSize, crop: photo.crop)
                let height = innerWidth * (cropped.height / max(cropped.width, 1))
                frames[photo.id] = CGRect(x: margin, y: y, width: innerWidth, height: height)
                y += height + spacing
            }
            y = max(y - (photos.isEmpty ? 0 : spacing) + margin, 1)
            return (CGSize(width: width, height: y), frames)
        } else {
            let height = canvasLong
            let innerHeight = max(height - margin * 2, 1)
            var x = margin
            for photo in photos {
                let cropped = croppedSize(photo.pixelSize, crop: photo.crop)
                let width = innerHeight * (cropped.width / max(cropped.height, 1))
                frames[photo.id] = CGRect(x: x, y: margin, width: width, height: innerHeight)
                x += width + spacing
            }
            x = max(x - (photos.isEmpty ? 0 : spacing) + margin, 1)
            return (CGSize(width: x, height: height), frames)
        }
    }

    public static func croppedSize(_ size: CGSize, crop: PhotoCrop) -> CGSize {
        let width = size.width * CGFloat(max(1 - crop.left - crop.right, 0.02))
        let height = size.height * CGFloat(max(1 - crop.top - crop.bottom, 0.02))
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    public static func fittedRect(imageSize: CGSize, in frame: CGRect, mode: PhotoContentMode, crop: PhotoCrop, rotation: Double = 0, fixedFrame: Bool = false) -> CGRect {
        if fixedFrame && abs(rotation.truncatingRemainder(dividingBy: 360)) > 0.001 {
            let angle = CGFloat(rotation * .pi / 180)
            let c = abs(cos(angle)), s = abs(sin(angle))
            let factor: CGFloat
            if mode == .fill {
                factor = max((frame.width * c + frame.height * s) / max(imageSize.width, 1),
                             (frame.height * c + frame.width * s) / max(imageSize.height, 1))
            } else {
                factor = min(frame.width / max(imageSize.width * c + imageSize.height * s, 1),
                             frame.height / max(imageSize.height * c + imageSize.width * s, 1))
            }
            let size = CGSize(width: imageSize.width * factor * crop.zoom, height: imageSize.height * factor * crop.zoom)
            return CGRect(x: frame.midX - size.width / 2 + crop.offsetX * frame.width,
                          y: frame.midY - size.height / 2 + crop.offsetY * frame.height, width: size.width, height: size.height)
        }
        let imageRatio = imageSize.width / max(imageSize.height, 1)
        let frameRatio = frame.width / max(frame.height, 1)
        var rect: CGRect
        if mode == .fit {
            if imageRatio > frameRatio {
                let h = frame.width / imageRatio
                rect = CGRect(x: frame.minX, y: frame.midY - h / 2, width: frame.width, height: h)
            } else {
                let w = frame.height * imageRatio
                rect = CGRect(x: frame.midX - w / 2, y: frame.minY, width: w, height: frame.height)
            }
        } else {
            if imageRatio > frameRatio {
                let w = frame.height * imageRatio
                rect = CGRect(x: frame.midX - w / 2, y: frame.minY, width: w, height: frame.height)
            } else {
                let h = frame.width / imageRatio
                rect = CGRect(x: frame.minX, y: frame.midY - h / 2, width: frame.width, height: h)
            }
        }
        let zoom = crop.zoom
        rect = rect.insetBy(dx: -(rect.width * (zoom - 1) / 2), dy: -(rect.height * (zoom - 1) / 2))
        rect.origin.x += crop.offsetX * frame.width
        rect.origin.y += crop.offsetY * frame.height
        return rect
    }

    public static func photoDrawFrame(_ payload: PhotoPayload, cell: CGRect) -> CGRect {
        guard payload.polaroid else { return cell }
        let edge = min(cell.width, cell.height) * 0.035
        let bottom = cell.height * 0.12
        return CGRect(x: cell.minX + edge, y: cell.minY + edge, width: max(cell.width - edge * 2, 1), height: max(cell.height - bottom - edge, 1))
    }

    public static func canvasPointToPhoto(
        _ canvasPoint: CGPoint,
        payload: PhotoPayload,
        cell: CGRect,
        imageSize: CGSize,
        rotation: Double = 0,
        scaleX: Double = 1,
        scaleY: Double = 1
    ) -> CGPoint {
        let frame = photoDrawFrame(payload, cell: cell)
        var local = photoLocalPoint(
            canvasPoint,
            in: payload.slotID == nil ? cell : frame,
            rotation: rotation,
            scaleX: 1,
            scaleY: 1
        )
        if scaleX < 0 { local.x = frame.midX * 2 - local.x }
        let cropped = croppedSize(imageSize, crop: payload.crop)
        let fitted = fittedRect(imageSize: cropped, in: frame, mode: payload.contentMode, crop: payload.crop,
                                rotation: rotation, fixedFrame: payload.slotID != nil)
        let width = max(fitted.width, 1)
        let height = max(fitted.height, 1)
        let croppedPoint = CGPoint(
            x: min(max((local.x - fitted.minX) / width, 0), 1),
            y: min(max(scaleY < 0 ? 1 - (local.y - fitted.minY) / height : (local.y - fitted.minY) / height, 0), 1)
        )
        return photoPointFromCropped(croppedPoint, crop: payload.crop)
    }

    public static func photoPointFromCropped(_ cropped: CGPoint, crop: PhotoCrop) -> CGPoint {
        let spanX = max(1 - crop.left - crop.right, 0.02)
        let spanY = max(1 - crop.top - crop.bottom, 0.02)
        return CGPoint(
            x: crop.left + cropped.x * spanX,
            y: crop.top + cropped.y * spanY
        )
    }

    public static func unclampedCroppedPointFromPhoto(_ photo: CGPoint, crop: PhotoCrop) -> CGPoint {
        let spanX = max(1 - crop.left - crop.right, 0.02)
        let spanY = max(1 - crop.top - crop.bottom, 0.02)
        return CGPoint(
            x: (photo.x - crop.left) / spanX,
            y: (photo.y - crop.top) / spanY
        )
    }

    public static func croppedPointFromPhoto(_ photo: CGPoint, crop: PhotoCrop) -> CGPoint {
        let raw = unclampedCroppedPointFromPhoto(photo, crop: crop)
        return CGPoint(
            x: min(max(raw.x, 0), 1),
            y: min(max(raw.y, 0), 1)
        )
    }

    public static func croppedRectFromPhoto(_ rect: NormalizedRect, crop: PhotoCrop) -> NormalizedRect? {
        let origin = unclampedCroppedPointFromPhoto(CGPoint(x: rect.x, y: rect.y), crop: crop)
        let corner = unclampedCroppedPointFromPhoto(
            CGPoint(x: rect.x + rect.width, y: rect.y + rect.height),
            crop: crop
        )
        let mapped = CGRect(
            x: min(origin.x, corner.x),
            y: min(origin.y, corner.y),
            width: abs(corner.x - origin.x),
            height: abs(corner.y - origin.y)
        )
        let visible = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard mapped.intersects(visible) else { return nil }
        let clipped = mapped.intersection(visible)
        guard clipped.width > 0.0005, clipped.height > 0.0005 else { return nil }
        return NormalizedRect(
            x: clipped.minX,
            y: clipped.minY,
            width: clipped.width,
            height: clipped.height
        )
    }

    public static func photoLocalPoint(
        _ canvasPoint: CGPoint,
        in frame: CGRect,
        rotation: Double,
        scaleX: Double,
        scaleY: Double
    ) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = canvasPoint.x - center.x
        let dy = canvasPoint.y - center.y
        let radians = -rotation * .pi / 180
        var localX = dx * Foundation.cos(radians) - dy * Foundation.sin(radians)
        var localY = dx * Foundation.sin(radians) + dy * Foundation.cos(radians)
        if scaleX < 0 { localX = -localX }
        if scaleY < 0 { localY = -localY }
        return CGPoint(x: center.x + localX, y: center.y + localY)
    }

    public static func hitTest(
        _ point: CGPoint,
        objects: [LayerObject],
        canvasSize: CGSize,
        frames: [UUID: CGRect] = [:],
        layoutDrivenIDs: Set<UUID> = []
    ) -> UUID? {
        let ordered = objects.filter { $0.isVisible && !$0.isLocked }.sorted { $0.zIndex > $1.zIndex }
        for object in ordered {
            if layoutDrivenIDs.contains(object.id), let frame = frames[object.id] {
                if frame.contains(point) { return object.id }
                continue
            }
            if contains(point, transform: object.transform, canvasSize: canvasSize) {
                return object.id
            }
        }
        return nil
    }

    public static func contains(_ point: CGPoint, transform: CanvasTransform, canvasSize: CGSize) -> Bool {
        let rect = transform.cgRect(in: canvasSize)
        let radians = -transform.rotation * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let local = CGPoint(
            x: center.x + dx * Foundation.cos(radians) - dy * Foundation.sin(radians),
            y: center.y + dx * Foundation.sin(radians) + dy * Foundation.cos(radians)
        )
        return rect.contains(local)
    }

    public static func rotatedFrame(_ transform: CanvasTransform, canvasSize: CGSize) -> CGRect {
        let rect = transform.cgRect(in: canvasSize)
        if abs(transform.rotation) < 0.01 { return rect }
        let radians = transform.rotation * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ].map { corner -> CGPoint in
            let dx = corner.x - center.x
            let dy = corner.y - center.y
            return CGPoint(
                x: center.x + dx * Foundation.cos(radians) - dy * Foundation.sin(radians),
                y: center.y + dx * Foundation.sin(radians) + dy * Foundation.cos(radians)
            )
        }
        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        return CGRect(
            x: xs.min() ?? rect.minX,
            y: ys.min() ?? rect.minY,
            width: (xs.max() ?? rect.maxX) - (xs.min() ?? rect.minX),
            height: (ys.max() ?? rect.maxY) - (ys.min() ?? rect.minY)
        )
    }

    public static func snap(
        _ transform: CanvasTransform,
        canvasSize: CGSize,
        others: [CanvasTransform],
        enabled: Bool
    ) -> (CanvasTransform, [SnapGuide]) {
        guard enabled else { return (transform, []) }
        let threshold = JiPin.snapThreshold
        var result = transform
        var guides: [SnapGuide] = []
        let halfW = (transform.width * abs(transform.scaleX)) / 2
        let halfH = (transform.height * abs(transform.scaleY)) / 2
        var verticalTargets = [0.0, 0.5, 1.0]
        var horizontalTargets = [0.0, 0.5, 1.0]
        for other in others {
            let otherHalfW = (other.width * abs(other.scaleX)) / 2
            let otherHalfH = (other.height * abs(other.scaleY)) / 2
            verticalTargets.append(contentsOf: [other.centerX - otherHalfW, other.centerX, other.centerX + otherHalfW])
            horizontalTargets.append(contentsOf: [other.centerY - otherHalfH, other.centerY, other.centerY + otherHalfH])
        }
        if let snappedX = snapCenter(result.centerX, half: halfW, size: canvasSize.width, targets: verticalTargets, threshold: threshold) {
            result.centerX = snappedX.center
            guides.append(SnapGuide(axis: .vertical, position: snappedX.guide))
        }
        if let snappedY = snapCenter(result.centerY, half: halfH, size: canvasSize.height, targets: horizontalTargets, threshold: threshold) {
            result.centerY = snappedY.center
            guides.append(SnapGuide(axis: .horizontal, position: snappedY.guide))
        }
        return (result, guides)
    }

    private static func snapCenter(
        _ center: Double,
        half: Double,
        size: CGFloat,
        targets: [Double],
        threshold: Double
    ) -> (center: Double, guide: Double)? {
        var best: (distance: Double, center: Double, guide: Double)?
        let edges = [center - half, center, center + half]
        for target in targets {
            for edge in edges {
                let distance = abs(edge - target) * Double(size)
                guard distance <= threshold else { continue }
                if best == nil || distance < best!.distance {
                    best = (distance, center + (target - edge), target)
                }
            }
        }
        return best.map { (center: $0.center, guide: $0.guide) }
    }
}

public struct SnapGuide: Hashable, Sendable {
    public enum Axis: Hashable, Sendable { case horizontal, vertical }
    public var axis: Axis
    public var position: Double
}
