import UIKit

/// Confined to a rendering actor. Geometry changes reuse pixels instead of decoding/filtering again.
final class PreviewAssets: AssetProviding {
    private var library: DataAssetLibrary
    let sourceSide: CGFloat
    private let cache = NSCache<Key, Pixels>()
    private(set) var decodeCount = 0
    private(set) var effectCount = 0

    private struct Effect: Hashable {
        var crop: PhotoCrop
        var filter: String?
        var intensity: Double
        var color: ColorAdjust
        var mosaics: [MosaicStroke]
        init(_ photo: PhotoPayload) {
            crop = photo.crop; crop.offsetX = 0; crop.offsetY = 0; crop.zoom = 1
            filter = photo.filterID; intensity = photo.filterIntensity
            color = photo.colorAdjust; mosaics = photo.mosaics
        }
    }
    private final class Key: NSObject {
        let id: UUID
        let effect: Effect?
        init(_ id: UUID, effect: Effect? = nil) { self.id = id; self.effect = effect }
        override var hash: Int { var hash = Hasher(); hash.combine(id); hash.combine(effect); return hash.finalize() }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Key else { return false }
            return id == other.id && effect == other.effect
        }
    }
    private final class Pixels: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    init(_ library: DataAssetLibrary) {
        self.library = DataAssetLibrary(images: library.images)
        sourceSide = min(1800, sqrt(10_485_760 / CGFloat(max(library.images.count, 1))))
        cache.totalCostLimit = 80 * 1024 * 1024
    }
    func attachImages(_ images: [UUID: Data]) { library.images = images }
    func releaseInput() { library.images = [:] }
    func imageData(for id: UUID) -> Data? { library.images[id] }
    func decodedImage(for id: UUID, maxLongSide: CGFloat) -> CGImage? {
        let key = Key(id)
        if let value = cache.object(forKey: key) { return value.image }
        guard let data = library.images[id], let image = ImageIOHelpers.thumbnail(from: data, maxLongSide: sourceSide) else { return nil }
        decodeCount += 1
        cache.setObject(Pixels(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
    func processedPhoto(_ payload: PhotoPayload, maxLongSide: CGFloat, targetSize: CGSize) -> CGImage? {
        let effect = Effect(payload), key = Key(payload.assetID, effect: effect)
        if let value = cache.object(forKey: key) { return value.image }
        guard let source = decodedImage(for: payload.assetID, maxLongSide: sourceSide) else { return nil }
        var normalized = payload; normalized.crop = effect.crop
        let image = PhotoEffects.shared.apply(to: source, payload: normalized, targetSize: targetSize)
        if image !== source {
            effectCount += 1
            cache.setObject(Pixels(image), forKey: key, cost: image.bytesPerRow * image.height)
        }
        return image
    }
}
