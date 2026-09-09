import CoreGraphics
import Foundation

public struct CanvasSpec: Codable, Hashable, Sendable {
    public var aspectWidth: Double
    public var aspectHeight: Double
    public var isCustom: Bool

    public init(aspectWidth: Double, aspectHeight: Double, isCustom: Bool = false) {
        self.aspectWidth = max(aspectWidth, 0.01)
        self.aspectHeight = max(aspectHeight, 0.01)
        self.isCustom = isCustom
    }

    public var ratio: Double { aspectWidth / aspectHeight }

    public func size(fitting width: CGFloat) -> CGSize {
        CGSize(width: width, height: width / ratio)
    }

    public func size(maxLongSide: CGFloat) -> CGSize {
        if aspectWidth >= aspectHeight {
            return CGSize(width: maxLongSide, height: maxLongSide / ratio)
        }
        return CGSize(width: maxLongSide * ratio, height: maxLongSide)
    }

    public static let square = CanvasSpec(aspectWidth: 1, aspectHeight: 1)
    public static let portrait34 = CanvasSpec(aspectWidth: 3, aspectHeight: 4)
    public static let landscape43 = CanvasSpec(aspectWidth: 4, aspectHeight: 3)
    public static let portrait916 = CanvasSpec(aspectWidth: 9, aspectHeight: 16)
    public static let landscape169 = CanvasSpec(aspectWidth: 16, aspectHeight: 9)

    public static let presets: [CanvasSpec] = [
        .square, .portrait34, .landscape43, .portrait916, .landscape169
    ]

    public var title: String {
        if isCustom { return "自定义 \(trimmed(aspectWidth)):\(trimmed(aspectHeight))" }
        return "\(trimmed(aspectWidth)):\(trimmed(aspectHeight))"
    }

    private func trimmed(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2f", value)
    }
}

public struct NormalizedRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func cgRect(in size: CGSize) -> CGRect {
        CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    public static func from(_ rect: CGRect, in size: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: rect.minX / size.width,
            y: rect.minY / size.height,
            width: rect.width / size.width,
            height: rect.height / size.height
        )
    }
}

public struct CanvasTransform: Codable, Hashable, Sendable {
    public var centerX: Double
    public var centerY: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var scaleX: Double
    public var scaleY: Double

    public init(
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        width: Double = 0.4,
        height: Double = 0.4,
        rotation: Double = 0,
        scaleX: Double = 1,
        scaleY: Double = 1
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
        self.rotation = rotation
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    public var rect: NormalizedRect {
        NormalizedRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }

    public func cgRect(in size: CGSize) -> CGRect {
        let w = width * size.width * abs(scaleX)
        let h = height * size.height * abs(scaleY)
        return CGRect(
            x: centerX * size.width - w / 2,
            y: centerY * size.height - h / 2,
            width: w,
            height: h
        )
    }
}

public struct StrokeStyle: Codable, Hashable, Sendable {
    public var colorHex: String
    public var width: Double
    public init(colorHex: String = "#FFFFFF", width: Double = 0) {
        self.colorHex = colorHex
        self.width = width
    }
}

public struct ShadowStyle: Codable, Hashable, Sendable {
    public var colorHex: String
    public var radius: Double
    public var offsetY: Double
    public init(colorHex: String = "#00000088", radius: Double = 0, offsetY: Double = 0) {
        self.colorHex = colorHex
        self.radius = radius
        self.offsetY = offsetY
    }
}

public struct ColorAdjust: Codable, Hashable, Sendable {
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var temperature: Double

    public init(brightness: Double = 0, contrast: Double = 1, saturation: Double = 1, temperature: Double = 0) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
    }

    public var isIdentity: Bool {
        abs(brightness) < 0.001
            && abs(contrast - 1) < 0.001
            && abs(saturation - 1) < 0.001
            && abs(temperature) < 0.001
    }
}

public enum PhotoContentMode: String, Codable, Sendable {
    case fill
    case fit
}

public struct PhotoCrop: Codable, Hashable, Sendable {
    public var top: Double
    public var bottom: Double
    public var left: Double
    public var right: Double
    public var offsetX: Double
    public var offsetY: Double
    public var zoom: Double

    public init(
        top: Double = 0,
        bottom: Double = 0,
        left: Double = 0,
        right: Double = 0,
        offsetX: Double = 0,
        offsetY: Double = 0,
        zoom: Double = 1
    ) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.zoom = max(zoom, 1)
    }

    public static let identity = PhotoCrop()
}

public struct MosaicStroke: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var points: [CGPoint]
    public var radius: Double

    public init(id: UUID = UUID(), points: [CGPoint] = [], radius: Double = 0.04) {
        self.id = id
        self.points = points
        self.radius = radius
    }
}

public struct CoverBlock: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var rect: NormalizedRect
    public var colorHex: String

    public init(id: UUID = UUID(), rect: NormalizedRect, colorHex: String = "#1C1A17") {
        self.id = id
        self.rect = rect
        self.colorHex = colorHex
    }
}

public struct PhotoPayload: Codable, Hashable, Sendable {
    public var assetID: UUID
    public var slotID: String?
    public var crop: PhotoCrop
    public var contentMode: PhotoContentMode
    public var cornerRadius: Double
    public var stroke: StrokeStyle
    public var shadow: ShadowStyle
    public var filterID: String?
    public var filterIntensity: Double
    public var colorAdjust: ColorAdjust
    public var mosaics: [MosaicStroke]
    public var coverBlocks: [CoverBlock]
    public var polaroid: Bool

    public init(
        assetID: UUID,
        slotID: String? = nil,
        crop: PhotoCrop = .identity,
        contentMode: PhotoContentMode = .fill,
        cornerRadius: Double = 0,
        stroke: StrokeStyle = StrokeStyle(),
        shadow: ShadowStyle = ShadowStyle(),
        filterID: String? = nil,
        filterIntensity: Double = 1,
        colorAdjust: ColorAdjust = ColorAdjust(),
        mosaics: [MosaicStroke] = [],
        coverBlocks: [CoverBlock] = [],
        polaroid: Bool = false
    ) {
        self.assetID = assetID
        self.slotID = slotID
        self.crop = crop
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.stroke = stroke
        self.shadow = shadow
        self.filterID = filterID
        self.filterIntensity = filterIntensity
        self.colorAdjust = colorAdjust
        self.mosaics = mosaics
        self.coverBlocks = coverBlocks
        self.polaroid = polaroid
    }
}

public enum TextAlignmentKind: String, Codable, Sendable {
    case leading, center, trailing
}

public struct TextPayload: Codable, Hashable, Sendable {
    public var text: String
    public var fontName: String
    public var fontSize: Double
    public var colorHex: String
    public var alignment: TextAlignmentKind
    public var lineSpacing: Double
    public var stroke: StrokeStyle
    public var shadow: ShadowStyle
    public var backgroundHex: String?

    public init(
        text: String,
        fontName: String = ".AppleSystemUIFont",
        fontSize: Double = 0.06,
        colorHex: String = "#1C1A17",
        alignment: TextAlignmentKind = .center,
        lineSpacing: Double = 1.15,
        stroke: StrokeStyle = StrokeStyle(width: 0),
        shadow: ShadowStyle = ShadowStyle(),
        backgroundHex: String? = nil
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.stroke = stroke
        self.shadow = shadow
        self.backgroundHex = backgroundHex
    }
}

public struct StickerPayload: Codable, Hashable, Sendable {
    public var stickerID: String
    public var assetID: UUID?
    public var tintHex: String?

    public init(stickerID: String, assetID: UUID? = nil, tintHex: String? = nil) {
        self.stickerID = stickerID
        self.assetID = assetID
        self.tintHex = tintHex
    }
}

public struct ShapePayload: Codable, Hashable, Sendable {
    public var shapeID: String
    public var fillHex: String
    public var stroke: StrokeStyle

    public init(shapeID: String, fillHex: String = "#FF5A36", stroke: StrokeStyle = StrokeStyle(width: 0)) {
        self.shapeID = shapeID
        self.fillHex = fillHex
        self.stroke = stroke
    }
}

public struct DoodleStroke: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var points: [CGPoint]
    public var colorHex: String
    public var lineWidth: Double
    public var opacity: Double
    public var isEraser: Bool
    public var kind: Kind

    public enum Kind: String, Codable, Sendable {
        case freehand, line, arrow
    }

    public init(
        id: UUID = UUID(),
        points: [CGPoint] = [],
        colorHex: String = "#FF5A36",
        lineWidth: Double = 0.012,
        opacity: Double = 1,
        isEraser: Bool = false,
        kind: Kind = .freehand
    ) {
        self.id = id
        self.points = points
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.isEraser = isEraser
        self.kind = kind
    }
}

public struct DoodlePayload: Codable, Hashable, Sendable {
    public var strokes: [DoodleStroke]
    public init(strokes: [DoodleStroke] = []) {
        self.strokes = strokes
    }
}

public enum LayerKind: String, Codable, Sendable {
    case photo, text, sticker, shape, doodle
}

public struct LayerObject: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: LayerKind
    public var zIndex: Int
    public var isLocked: Bool
    public var isVisible: Bool
    public var opacity: Double
    public var transform: CanvasTransform
    public var photo: PhotoPayload?
    public var text: TextPayload?
    public var sticker: StickerPayload?
    public var shape: ShapePayload?
    public var doodle: DoodlePayload?

    public init(
        id: UUID = UUID(),
        kind: LayerKind,
        zIndex: Int,
        isLocked: Bool = false,
        isVisible: Bool = true,
        opacity: Double = 1,
        transform: CanvasTransform = CanvasTransform(),
        photo: PhotoPayload? = nil,
        text: TextPayload? = nil,
        sticker: StickerPayload? = nil,
        shape: ShapePayload? = nil,
        doodle: DoodlePayload? = nil
    ) {
        self.id = id
        self.kind = kind
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.isVisible = isVisible
        self.opacity = opacity
        self.transform = transform
        self.photo = photo
        self.text = text
        self.sticker = sticker
        self.shape = shape
        self.doodle = doodle
    }

    public var displayName: String {
        switch kind {
        case .photo: return "照片"
        case .text: return text.map { String($0.text.prefix(12)) } ?? "文字"
        case .sticker: return "贴纸"
        case .shape: return "形状"
        case .doodle: return "涂鸦"
        }
    }

    public static func photo(assetID: UUID, slotID: String?, zIndex: Int, transform: CanvasTransform) -> LayerObject {
        LayerObject(
            kind: .photo,
            zIndex: zIndex,
            transform: transform,
            photo: PhotoPayload(assetID: assetID, slotID: slotID)
        )
    }
}

public enum BackgroundKind: String, Codable, Sendable {
    case solid, gradient, texture, image
}

public struct BackgroundSpec: Codable, Hashable, Sendable {
    public var kind: BackgroundKind
    public var presetID: String?
    public var colorHex: String
    public var secondaryHex: String?
    public var imageAssetID: UUID?
    public var isHidden: Bool

    public init(
        kind: BackgroundKind = .solid,
        presetID: String? = "solid-cream",
        colorHex: String = "#F4F1EA",
        secondaryHex: String? = nil,
        imageAssetID: UUID? = nil,
        isHidden: Bool = false
    ) {
        self.kind = kind
        self.presetID = presetID
        self.colorHex = colorHex
        self.secondaryHex = secondaryHex
        self.imageAssetID = imageAssetID
        self.isHidden = isHidden
    }

    public static let cream = BackgroundSpec()
}

public enum StripDirection: String, Codable, Sendable, CaseIterable {
    case vertical, horizontal
    public var title: String { self == .vertical ? "纵向" : "横向" }
}

public struct LongStripSpec: Codable, Hashable, Sendable {
    public var direction: StripDirection
    public var spacing: Double
    public init(direction: StripDirection = .vertical, spacing: Double = 0) {
        self.direction = direction
        self.spacing = spacing
    }
}

public enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case jpeg, png
    public var title: String { self == .jpeg ? "JPEG" : "PNG" }
}

public enum ExportQuality: String, Codable, Sendable, CaseIterable {
    case standard, hd
    public var title: String { self == .standard ? "标准" : "高清" }
}

public struct ExportPreference: Codable, Hashable, Sendable {
    public var format: ExportFormat
    public var quality: ExportQuality
    public var transparentBackground: Bool

    public init(format: ExportFormat = .jpeg, quality: ExportQuality = .standard, transparentBackground: Bool = false) {
        self.format = format
        self.quality = quality
        self.transparentBackground = transparentBackground
    }
}

public struct CollageProject: Codable, Hashable, Sendable, Identifiable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var mode: CollageMode
    public var canvas: CanvasSpec
    public var background: BackgroundSpec
    public var layoutID: String?
    public var customLayoutCells: [NormalizedRect]?
    public var posterID: String?
    public var longStrip: LongStripSpec?
    public var objects: [LayerObject]
    public var photoOrder: [UUID]
    public var spacing: Double
    public var outerMargin: Double
    public var snapEnabled: Bool
    public var exportPreference: ExportPreference
    public var createdAt: Date
    public var updatedAt: Date
    public var originatedFromExtension: Bool

    public init(
        schemaVersion: Int = JiPin.schemaVersion,
        id: UUID = UUID(),
        name: String = "未命名拼图",
        mode: CollageMode,
        canvas: CanvasSpec = .square,
        background: BackgroundSpec = .cream,
        layoutID: String? = nil,
        posterID: String? = nil,
        longStrip: LongStripSpec? = nil,
        objects: [LayerObject] = [],
        photoOrder: [UUID] = [],
        spacing: Double = 0.012,
        outerMargin: Double = 0.02,
        snapEnabled: Bool = true,
        exportPreference: ExportPreference = ExportPreference(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        originatedFromExtension: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.mode = mode
        self.canvas = canvas
        self.background = background
        self.layoutID = layoutID
        self.customLayoutCells = nil
        self.posterID = posterID
        self.longStrip = longStrip
        self.objects = objects
        self.photoOrder = photoOrder
        self.spacing = spacing
        self.outerMargin = outerMargin
        self.snapEnabled = snapEnabled
        self.exportPreference = exportPreference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.originatedFromExtension = originatedFromExtension
    }

    public var visibleObjects: [LayerObject] {
        objects.filter(\.isVisible).sorted { $0.zIndex < $1.zIndex }
    }

    public var photoLayers: [LayerObject] {
        var remaining = objects.filter { $0.kind == .photo }
        let ordered = photoOrder.compactMap { assetID -> LayerObject? in
            guard let index = remaining.firstIndex(where: { $0.photo?.assetID == assetID }) else { return nil }
            return remaining.remove(at: index)
        }
        return ordered + remaining
    }

    public var textCount: Int {
        objects.filter { $0.kind == .text }.count
    }

    public mutating func touch() {
        updatedAt = Date()
    }

    public func object(id: UUID) -> LayerObject? {
        objects.first { $0.id == id }
    }

    public mutating func updateObject(id: UUID, _ body: (inout LayerObject) -> Void) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        body(&objects[index])
        touch()
    }
}

public struct DraftSummary: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var mode: CollageMode
    public var updatedAt: Date
    public var createdAt: Date
    public var photoCount: Int
    public var byteSize: Int64
    public var thumbnailPath: URL?
    public var isIncomplete: Bool
    public var originatedFromExtension: Bool

    public init(
        id: UUID,
        name: String,
        mode: CollageMode,
        updatedAt: Date,
        createdAt: Date,
        photoCount: Int,
        byteSize: Int64,
        thumbnailPath: URL?,
        isIncomplete: Bool,
        originatedFromExtension: Bool
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.photoCount = photoCount
        self.byteSize = byteSize
        self.thumbnailPath = thumbnailPath
        self.isIncomplete = isIncomplete
        self.originatedFromExtension = originatedFromExtension
    }
}

public struct ImportedPhoto: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var filename: String
    public var data: Data
    public var pixelSize: CGSize
    public var utType: String
    public var loadFailed: Bool
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        filename: String,
        data: Data,
        pixelSize: CGSize,
        utType: String,
        loadFailed: Bool = false,
        failureReason: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.data = data
        self.pixelSize = pixelSize
        self.utType = utType
        self.loadFailed = loadFailed
        self.failureReason = failureReason
    }
}

public struct ModeCopyPreview: Sendable {
    public var target: CollageMode
    public var keptPhotos: Int
    public var droppedKinds: [String]
    public var warnings: [String]
}

public enum ExportLimitDecision: Equatable, Sendable {
    case ok(CGSize)
    case needsChoice(computed: CGSize, scaled: CGSize)
}
