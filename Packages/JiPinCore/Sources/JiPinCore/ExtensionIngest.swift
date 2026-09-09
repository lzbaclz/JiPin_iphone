import Foundation
import UniformTypeIdentifiers

public struct ExtensionIngestResult: Sendable {
    public var photos: [ImportedPhoto]
    public var failed: [ImportedPhoto]
    public var overflowCount: Int

    public init(photos: [ImportedPhoto], failed: [ImportedPhoto], overflowCount: Int) {
        self.photos = photos
        self.failed = failed
        self.overflowCount = overflowCount
    }
}

public enum ExtensionIngest {
    public static let decodeFailure = "照片无法解码。如果原图还在 iCloud，请联网后重试。"
    public static let readFailure = "无法读取这张照片。如果原图还在 iCloud，请联网后重试。"

    public static func isLikelyImage(typeIdentifiers: [String]) -> Bool {
        let imageHints: Set<String> = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.heic.identifier,
            UTType.gif.identifier,
            UTType.tiff.identifier,
            UTType.webP.identifier,
            UTType.rawImage.identifier,
            "public.heif",
            "public.jpeg-2000",
            "com.compuserve.gif",
            "com.apple.private.photos.thumbnail-internal"
        ]
        for identifier in typeIdentifiers {
            if imageHints.contains(identifier) { return true }
            if identifier.hasPrefix("public.image") { return true }
            if let type = UTType(identifier), type.conforms(to: .image) { return true }
        }
        return typeIdentifiers.contains(UTType.fileURL.identifier)
            || typeIdentifiers.contains(UTType.url.identifier)
    }

    public static func isLikelyImageProvider(_ provider: NSItemProvider) -> Bool {
        isLikelyImage(typeIdentifiers: provider.registeredTypeIdentifiers)
            || provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.heic.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }

    public static func process(_ items: [(filename: String, data: Data?)], jpegQuality: CGFloat = 0.92) -> ExtensionIngestResult {
        let overflowCount = max(items.count - PhotoLimits.extensionRange.upperBound, 0)
        var photos: [ImportedPhoto] = []
        var failed: [ImportedPhoto] = []
        for (index, item) in items.prefix(PhotoLimits.extensionRange.upperBound).enumerated() {
            let name = item.filename.isEmpty ? "照片 \(index + 1)" : item.filename
            guard let data = item.data, !data.isEmpty else {
                failed.append(
                    ImportedPhoto(
                        filename: name,
                        data: Data(),
                        pixelSize: .zero,
                        utType: UTType.image.identifier,
                        loadFailed: true,
                        failureReason: readFailure
                    )
                )
                continue
            }
            guard let stripped = ImageIOHelpers.sanitizedImageData(from: data, jpegQuality: jpegQuality, maxLongSide: 4096, maxPixelCount: 4_194_304) else {
                failed.append(
                    ImportedPhoto(
                        filename: name,
                        data: Data(),
                        pixelSize: .zero,
                        utType: UTType.image.identifier,
                        loadFailed: true,
                        failureReason: decodeFailure
                    )
                )
                continue
            }
            photos.append(
                ImportedPhoto(
                    filename: name,
                    data: stripped,
                    pixelSize: ImageIOHelpers.pixelSize(of: stripped),
                    utType: ImageIOHelpers.typeIdentifier(of: stripped)
                )
            )
        }
        return ExtensionIngestResult(photos: photos, failed: failed, overflowCount: overflowCount)
    }
}
