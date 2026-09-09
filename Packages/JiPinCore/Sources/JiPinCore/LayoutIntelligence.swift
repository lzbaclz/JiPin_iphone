import CoreGraphics
import Foundation

public struct LayoutRecommendation: Identifiable, Hashable, Sendable {
    public var id: String { layout.id }
    public let layout: CollageGridLayout
    /// Geometric estimate for centered fill, not a subject- or face-detection score.
    public let retainedArea: Double
}

public enum LayoutRecommender {
    public static func ranked(photoSizes: [CGSize], canvas: CanvasSpec, spacing: Double = 0.012,
                              margin: Double = 0.02) -> [LayoutRecommendation] {
        let canvasSize = canvas.size(maxLongSide: 1000)
        let unit = min(canvasSize.width, canvasSize.height)
        return CollageGridLayoutCatalog.layouts(forPhotoCount: photoSizes.count).map { layout in
            let frames = LayoutEngine.frames(layout: layout, canvasSize: canvasSize,
                                             spacing: spacing * unit, margin: margin * unit)
            let scores = zip(photoSizes, frames).map { photo, frame -> Double in
                guard photo.width.isFinite, photo.height.isFinite, photo.width > 0, photo.height > 0 else { return 0.5 }
                let a = photo.width / photo.height, b = frame.width / max(frame.height, 1)
                return Double(min(a / b, b / a))
            }
            return LayoutRecommendation(layout: layout, retainedArea: scores.reduce(0, +) / Double(max(scores.count, 1)))
        }.sorted {
            if abs($0.retainedArea - $1.retainedArea) > 0.00001 { return $0.retainedArea > $1.retainedArea }
            return $0.id < $1.id
        }
    }
}

public struct LayoutDivider: Identifiable, Hashable, Sendable {
    public enum Axis: String, Sendable { case vertical, horizontal }
    public var id: String { "\(axis.rawValue)-\(index)" }
    public let axis: Axis
    public let index: Int
    public let position: Double
    public let lower: Double
    public let upper: Double
    public var title: String { "\(axis == .vertical ? "竖线" : "横线") \(index + 1)" }
}

public enum LayoutDividerEngine {
    private static let epsilon = 0.00001
    private static let minimum = 0.035

    public static func dividers(in cells: [NormalizedRect]) -> [LayoutDivider] {
        var result: [LayoutDivider] = []
        for axis in [LayoutDivider.Axis.vertical, .horizontal] {
            let ends = cells.flatMap { cell -> [Double] in
                axis == .vertical ? [cell.x, cell.x + cell.width] : [cell.y, cell.y + cell.height]
            }
            var positions: [Double] = []
            for value in ends.sorted() where value > epsilon && value < 1 - epsilon {
                if positions.last.map({ abs($0 - value) > epsilon }) ?? true { positions.append(value) }
            }
            for (index, position) in positions.enumerated() {
                var lower = index > 0 ? positions[index - 1] + minimum : minimum
                var upper = index + 1 < positions.count ? positions[index + 1] - minimum : 1 - minimum
                for cell in cells {
                    let start = axis == .vertical ? cell.x : cell.y
                    let end = start + (axis == .vertical ? cell.width : cell.height)
                    if abs(end - position) < epsilon { lower = max(lower, start + minimum) }
                    if abs(start - position) < epsilon { upper = min(upper, end - minimum) }
                }
                if lower < upper { result.append(.init(axis: axis, index: index, position: position, lower: lower, upper: upper)) }
            }
        }
        return result
    }

    public static func moving(_ divider: LayoutDivider, to value: Double, in cells: [NormalizedRect]) -> [NormalizedRect] {
        guard value.isFinite else { return cells }
        let value = min(max(value, divider.lower), divider.upper)
        let next = cells.map { cell -> NormalizedRect in
            var cell = cell
            if divider.axis == .vertical {
                let end = cell.x + cell.width
                if abs(cell.x - divider.position) < epsilon { cell.x = value; cell.width = end - value }
                else if abs(end - divider.position) < epsilon { cell.width = value - cell.x }
            } else {
                let end = cell.y + cell.height
                if abs(cell.y - divider.position) < epsilon { cell.y = value; cell.height = end - value }
                else if abs(end - divider.position) < epsilon { cell.height = value - cell.y }
            }
            return cell
        }
        return isValid(next) ? next : cells
    }

    public static func isValid(_ cells: [NormalizedRect]) -> Bool {
        guard !cells.isEmpty else { return false }
        var area = 0.0
        for (i, cell) in cells.enumerated() {
            guard [cell.x, cell.y, cell.width, cell.height].allSatisfy(\.isFinite),
                  cell.x >= -epsilon, cell.y >= -epsilon, cell.width > 0, cell.height > 0,
                  cell.x + cell.width <= 1 + epsilon, cell.y + cell.height <= 1 + epsilon else { return false }
            area += cell.width * cell.height
            for other in cells.dropFirst(i + 1) {
                let w = min(cell.x + cell.width, other.x + other.width) - max(cell.x, other.x)
                let h = min(cell.y + cell.height, other.y + other.height) - max(cell.y, other.y)
                if w > epsilon && h > epsilon { return false }
            }
        }
        return abs(area - 1) < 0.0001
    }
}

public extension CollageProject {
    var resolvedGridLayout: CollageGridLayout? {
        guard let base = layoutID.flatMap(CollageGridLayoutCatalog.layout(id:)) else { return nil }
        guard let cells = customLayoutCells, cells.count == base.photoCount, LayoutDividerEngine.isValid(cells) else { return base }
        return CollageGridLayout(id: base.id, name: base.name, cells: cells)
    }
}
