import Foundation
import CoreGraphics

public enum IDPhotoBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case white, red, blue
    case blueWhite = "blue-white"
    case lightGray = "light-gray"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .white: return "白底"
        case .red: return "红底"
        case .blue: return "蓝底"
        case .blueWhite: return "蓝白渐变"
        case .lightGray: return "浅灰底"
        }
    }
    public var topHex: String {
        switch self {
        case .white: return "#FFFFFF"
        case .red: return "#D9363E"
        case .blue: return "#438EDB"
        case .blueWhite: return "#66A9E6"
        case .lightGray: return "#E6E8EB"
        }
    }
    public var bottomHex: String? { self == .blueWhite ? "#FFFFFF" : nil }
}

public struct IDPhotoAdjustments: Codable, Hashable, Sendable {
    public var brightness: Double
    public var smoothing: Double
    public var temperature: Double

    public init(brightness: Double = 0, smoothing: Double = 0, temperature: Double = 0) {
        self.brightness = finiteClamp(brightness, -20...20, fallback: 0)
        self.smoothing = finiteClamp(smoothing, 0...30, fallback: 0)
        self.temperature = finiteClamp(temperature, -10...10, fallback: 0)
    }
    public static let natural = Self(brightness: 5, smoothing: 6)
    public var isIdentity: Bool { brightness == 0 && smoothing == 0 && temperature == 0 }
    public var clamped: Self { .init(brightness: brightness, smoothing: smoothing, temperature: temperature) }
    public func validate() throws {
        guard brightness.isFinite, smoothing.isFinite, temperature.isFinite,
              (-20...20).contains(brightness), (0...30).contains(smoothing), (-10...10).contains(temperature)
        else { throw IDPhotoValidationError.invalidAdjustments }
    }
    private enum CodingKeys: String, CodingKey { case brightness, smoothing, temperature }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        brightness = try c.decode(Double.self, forKey: .brightness)
        smoothing = try c.decode(Double.self, forKey: .smoothing)
        temperature = try c.decode(Double.self, forKey: .temperature)
        try validate()
    }
}

/// Center selects a point in the upright source image. Rotation is clockwise in top-left coordinates.
public struct IDPhotoCrop: Codable, Hashable, Sendable {
    public var centerX: Double
    public var centerY: Double
    public var zoom: Double
    public var rotationDegrees: Double

    public init(centerX: Double = 0.5, centerY: Double = 0.5, zoom: Double = 1, rotationDegrees: Double = 0) {
        self.centerX = finiteClamp(centerX, 0...1, fallback: 0.5)
        self.centerY = finiteClamp(centerY, 0...1, fallback: 0.5)
        self.zoom = finiteClamp(zoom, 1...8, fallback: 1)
        self.rotationDegrees = finiteClamp(rotationDegrees, -180...180, fallback: 0)
    }
    public var clamped: Self { .init(centerX: centerX, centerY: centerY, zoom: zoom, rotationDegrees: rotationDegrees) }
    public func validate() throws {
        guard centerX.isFinite, centerY.isFinite, zoom.isFinite, rotationDegrees.isFinite,
              (0...1).contains(centerX), (0...1).contains(centerY), (1...8).contains(zoom),
              (-180...180).contains(rotationDegrees) else { throw IDPhotoValidationError.invalidCrop }
    }
    private enum CodingKeys: String, CodingKey { case centerX, centerY, zoom, rotationDegrees }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        centerX = try c.decode(Double.self, forKey: .centerX); centerY = try c.decode(Double.self, forKey: .centerY)
        zoom = try c.decode(Double.self, forKey: .zoom); rotationDegrees = try c.decode(Double.self, forKey: .rotationDegrees)
        try validate()
    }
}

public struct IDPhotoBrushStroke: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Points and radius remain in source coordinates even when the preview is magnified or rotated.
    public var points: [CGPoint]
    public var radius: Double
    public var restores: Bool

    public init(id: UUID = UUID(), points: [CGPoint], radius: Double, restores: Bool) {
        self.id = id; self.points = points; self.radius = radius; self.restores = restores
    }
    public func validate() throws {
        guard (1...8_192).contains(points.count), radius.isFinite, (0.0001...0.25).contains(radius),
              points.allSatisfy(Self.validPoint) else { throw IDPhotoValidationError.invalidStroke }
    }
    static func validPoint(_ p: CGPoint) -> Bool {
        p.x.isFinite && p.y.isFinite && (0...1).contains(p.x) && (0...1).contains(p.y)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id); hasher.combine(radius); hasher.combine(restores)
        for point in points { hasher.combine(point.x); hasher.combine(point.y) }
    }
    private enum CodingKeys: String, CodingKey { case id, points, radius, restores }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); points = try c.decode([CGPoint].self, forKey: .points)
        radius = try c.decode(Double.self, forKey: .radius); restores = try c.decode(Bool.self, forKey: .restores)
        try validate()
    }
}

/// Face landmarks are stored in the same upright, normalized, top-left coordinates as mask edits.
public struct IDPhotoFaceRegion: Codable, Hashable, Sendable {
    public var faceRect: CGRect
    public var protectedPolygons: [[CGPoint]]
    public var skinPolygon: [CGPoint]?

    public init(faceRect: CGRect, protectedPolygons: [[CGPoint]] = [], skinPolygon: [CGPoint]? = nil) {
        self.faceRect = faceRect; self.protectedPolygons = protectedPolygons; self.skinPolygon = skinPolygon
    }
    public func validate() throws {
        let values = [faceRect.origin.x, faceRect.origin.y, faceRect.width, faceRect.height]
        guard values.allSatisfy(\.isFinite), faceRect.width > 0, faceRect.height > 0,
              faceRect.minX >= 0, faceRect.minY >= 0, faceRect.maxX <= 1.00001, faceRect.maxY <= 1.00001,
              protectedPolygons.count <= 32 else { throw IDPhotoValidationError.invalidFaceRegion }
        for polygon in protectedPolygons + (skinPolygon.map { [$0] } ?? []) {
            guard (3...512).contains(polygon.count), polygon.allSatisfy(IDPhotoBrushStroke.validPoint)
            else { throw IDPhotoValidationError.invalidFaceRegion }
        }
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(faceRect.origin.x); hasher.combine(faceRect.origin.y)
        hasher.combine(faceRect.width); hasher.combine(faceRect.height)
        for polygon in protectedPolygons { for point in polygon { hasher.combine(point.x); hasher.combine(point.y) } }
        if let skinPolygon { for point in skinPolygon { hasher.combine(point.x); hasher.combine(point.y) } }
    }
    private enum CodingKeys: String, CodingKey { case faceRect, protectedPolygons, skinPolygon }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        faceRect = try c.decode(CGRect.self, forKey: .faceRect)
        protectedPolygons = try c.decode([[CGPoint]].self, forKey: .protectedPolygons)
        skinPolygon = try c.decodeIfPresent([CGPoint].self, forKey: .skinPolygon)
        try validate()
    }
}

public struct IDPhotoProject: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1
    public var id: UUID
    public var name: String
    public var template: IDPhotoTemplate
    public var crop: IDPhotoCrop
    public var background: IDPhotoBackground
    public var keepOriginalBackground: Bool
    public var adjustments: IDPhotoAdjustments
    public var exportQuality: IDPhotoExportQuality
    public var strokes: [IDPhotoBrushStroke]
    public var createdAt: Date
    public var updatedAt: Date
    public var schemaVersion: Int

    public init(id: UUID = UUID(), name: String = "证件照", template: IDPhotoTemplate = IDPhotoTemplateCatalog.defaultTemplate,
                crop: IDPhotoCrop = .init(), background: IDPhotoBackground = .white, keepOriginalBackground: Bool = false,
                adjustments: IDPhotoAdjustments = .init(), strokes: [IDPhotoBrushStroke] = [], createdAt: Date = Date(),
                updatedAt: Date? = nil, schemaVersion: Int = 1, exportQuality: IDPhotoExportQuality = .highDefinition) {
        self.id = id; self.name = name; self.template = template; self.crop = crop; self.background = background
        self.keepOriginalBackground = keepOriginalBackground; self.adjustments = adjustments; self.strokes = strokes
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.schemaVersion = schemaVersion
        self.exportQuality = exportQuality
    }

    public mutating func touch() { updatedAt = Date() }
    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else { throw IDPhotoValidationError.unsupportedVersion }
        guard (1...200).contains(name.count), createdAt.timeIntervalSince1970.isFinite,
              updatedAt.timeIntervalSince1970.isFinite, strokes.count <= 500,
              strokes.reduce(0, { $0 + $1.points.count }) <= 250_000,
              Set(strokes.map(\.id)).count == strokes.count else { throw IDPhotoValidationError.invalidProject }
        try template.validate(); try crop.validate(); try adjustments.validate()
        try strokes.forEach { try $0.validate() }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, template, crop, background, keepOriginalBackground, adjustments, strokes, createdAt, updatedAt, schemaVersion, exportQuality
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else { throw IDPhotoValidationError.unsupportedVersion }
        id = try c.decode(UUID.self, forKey: .id); name = try c.decode(String.self, forKey: .name)
        template = try c.decode(IDPhotoTemplate.self, forKey: .template); crop = try c.decode(IDPhotoCrop.self, forKey: .crop)
        background = try c.decode(IDPhotoBackground.self, forKey: .background)
        keepOriginalBackground = try c.decode(Bool.self, forKey: .keepOriginalBackground)
        adjustments = try c.decode(IDPhotoAdjustments.self, forKey: .adjustments)
        exportQuality = try c.decodeIfPresent(IDPhotoExportQuality.self, forKey: .exportQuality) ?? .highDefinition
        strokes = try c.decode([IDPhotoBrushStroke].self, forKey: .strokes)
        createdAt = try c.decode(Date.self, forKey: .createdAt); updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        try validate()
    }
}

public enum IDPhotoGeometry {
    /// Maps upright source pixels into output pixels, both with top-left origins. No anisotropic scaling.
    public static func transform(sourceSize: CGSize, outputSize: CGSize, crop: IDPhotoCrop) -> CGAffineTransform {
        guard validSize(sourceSize), validSize(outputSize) else { return .identity }
        let crop = crop.clamped
        let scale = max(outputSize.width / sourceSize.width, outputSize.height / sourceSize.height) * crop.zoom
        let angle = crop.rotationDegrees * .pi / 180
        let a = cos(angle) * scale, b = sin(angle) * scale
        let c = -b, d = a
        let x = sourceSize.width * crop.centerX, y = sourceSize.height * crop.centerY
        return CGAffineTransform(a: a, b: b, c: c, d: d,
                                 tx: outputSize.width / 2 - a * x - c * y,
                                 ty: outputSize.height / 2 - b * x - d * y)
    }

    public static func outputPoint(fromNormalizedSource point: CGPoint, sourceSize: CGSize, outputSize: CGSize, crop: IDPhotoCrop) -> CGPoint {
        CGPoint(x: point.x * sourceSize.width, y: point.y * sourceSize.height)
            .applying(transform(sourceSize: sourceSize, outputSize: outputSize, crop: crop))
    }

    /// Does not clamp outside points: the brush caller can discard them instead of drawing an edge streak.
    public static func normalizedSourcePoint(fromOutput point: CGPoint, sourceSize: CGSize, outputSize: CGSize, crop: IDPhotoCrop) -> CGPoint {
        guard validSize(sourceSize), validSize(outputSize) else { return .zero }
        let p = point.applying(transform(sourceSize: sourceSize, outputSize: outputSize, crop: crop).inverted())
        return CGPoint(x: p.x / sourceSize.width, y: p.y / sourceSize.height)
    }

    /// Suggested framing only. A face box is expanded toward the hair; it is not treated as a full head.
    public static func autoCrop(face: IDPhotoFaceRegion?, sourceSize: CGSize, outputSize: CGSize,
                                personBounds: CGRect? = nil, headBounds: CGRect? = nil) -> IDPhotoCrop {
        guard let face, (try? face.validate()) != nil, validSize(sourceSize), validSize(outputSize) else { return .init() }
        let rect = face.faceRect
        var top = max(0, rect.minY - rect.height * 0.30)
        if let personBounds, !personBounds.isNull, personBounds.minY.isFinite,
           personBounds.minY >= 0, personBounds.minY <= rect.minY {
            // Bound the estimated hair extension so an unrelated object above the person cannot dominate the crop.
            top = max(rect.minY - rect.height * 0.55, min(top, personBounds.minY))
            top = max(0, top)
        }
        // A head-only connected matte band includes wide/curly hair without letting
        // shoulders, raised arms or a held object determine the portrait's scale.
        let reliableHead = headBounds.flatMap { bounds -> CGRect? in
            let components = [bounds.minX, bounds.minY, bounds.width, bounds.height]
            guard components.allSatisfy(\.isFinite), bounds.width > 0, bounds.height > 0,
                  bounds.minX >= 0, bounds.minY >= 0, bounds.maxX <= 1.00001, bounds.maxY <= 1.00001,
                  bounds.minY <= rect.minY, bounds.maxY >= rect.midY,
                  bounds.minX <= rect.midX, bounds.maxX >= rect.midX,
                  bounds.width <= rect.width * 4, bounds.height <= rect.height * 3 else { return nil }
            return bounds
        }
        if let reliableHead { top = min(top, reliableHead.minY) }
        let headHeight = max(0.02, rect.maxY - top) * sourceSize.height
        var wantedScale = outputSize.height * 0.60 / headHeight
        if let reliableHead {
            let halfWidth = max(rect.midX - reliableHead.minX, reliableHead.maxX - rect.midX) * sourceSize.width
            wantedScale = min(wantedScale, outputSize.width * 0.92 / max(halfWidth * 2, 1))
        }
        let baseScale = max(outputSize.width / sourceSize.width, outputSize.height / sourceSize.height)
        let zoom = finiteClamp(wantedScale / baseScale, 1...8, fallback: 1)
        let sourceWindowHeight = outputSize.height / (baseScale * zoom)
        let sourceWindowWidth = outputSize.width / (baseScale * zoom)
        let centerY = top * sourceSize.height + sourceWindowHeight * 0.42
        let xMargin = min(0.5, sourceWindowWidth / sourceSize.width / 2)
        let yMargin = min(0.5, sourceWindowHeight / sourceSize.height / 2)
        return IDPhotoCrop(centerX: min(max(rect.midX, xMargin), 1 - xMargin),
                           centerY: min(max(centerY / sourceSize.height, yMargin), 1 - yMargin), zoom: zoom)
    }

    private static func validSize(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }
}

private func finiteClamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
    value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
}
