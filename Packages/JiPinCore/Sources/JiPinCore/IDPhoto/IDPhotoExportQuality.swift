import Foundation
import CoreGraphics

public enum IDPhotoExportQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case highDefinition, compressed
    public var id: String { rawValue }
    public var title: String { self == .highDefinition ? "高清" : "压缩" }
    public var jpegQuality: Double { self == .highDefinition ? 0.98 : 0.80 }
}

/// Fixed document sizes have a larger keepsake output and a compact submission
/// output. Custom pixel dimensions remain exact in both choices.
public struct IDPhotoExportConfiguration: Sendable {
    public let width: Int
    public let height: Int
    public let ppi: Int
    public let quality: IDPhotoExportQuality
    public var pixelSize: CGSize { CGSize(width: width, height: height) }
    public var pixelDescription: String { "\(width) × \(height) px" }
    public var summary: String { "\(quality.title) · \(pixelDescription) · \(ppi) ppi" }

    public func requiresUpscaling(sourceSize: CGSize, crop: IDPhotoCrop) -> Bool {
        guard sourceSize.width.isFinite, sourceSize.height.isFinite,
              sourceSize.width > 0, sourceSize.height > 0 else { return false }
        let scale = max(pixelSize.width / sourceSize.width, pixelSize.height / sourceSize.height)
        return scale * crop.clamped.zoom > 1.01
    }

    public init(template: IDPhotoTemplate, quality: IDPhotoExportQuality) throws {
        try template.validate()
        let scale: Int
        if quality == .highDefinition && !template.isCustom {
            // Integer scaling preserves exactly the same crop and print size.
            // Bound valid but non-catalog snapshots as well as built-in templates.
            scale = max(1, min(4, 4096 / max(template.width, template.height),
                               Int(sqrt(8_388_608 / Double(template.width * template.height)))))
        } else { scale = 1 }
        width = template.width * scale
        height = template.height * scale
        ppi = template.ppi * scale
        self.quality = quality
    }
}
