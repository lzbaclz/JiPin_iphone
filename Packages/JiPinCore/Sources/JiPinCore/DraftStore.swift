import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import CryptoKit
import Darwin
import UIKit

public enum DraftStoreError: LocalizedError, Equatable {
    case incomplete, missingProject, encodingFailed, appGroupUnavailable, diskFull
    case missingAssets, conflictingAsset, unsupportedVersion

    public var errorDescription: String? {
        switch self {
        case .incomplete: return "草稿尚未写入完成，无法打开。"
        case .missingProject: return "找不到草稿文件。"
        case .encodingFailed: return "无法保存草稿。"
        case .appGroupUnavailable: return "共享存储不可用，请检查极拼的 App Group 配置。"
        case .diskFull: return "存储空间不足，这次没有写入。已有草稿仍保留。"
        case .missingAssets: return "部分照片或装饰素材缺失，已有草稿仍保留。请替换缺失素材后重试。"
        case .conflictingAsset: return "素材内容发生冲突，已有草稿和照片仍保留。"
        case .unsupportedVersion: return "此草稿由更新版本的极拼创建，请更新 App 后打开。"
        }
    }
}

public struct LoadedDraft: Sendable {
    public var project: CollageProject
    public var assets: [UUID: Data]
}

/// All reads and writes use the same process lock and App Group file lock.
/// Assets are immutable; the only commit point is an atomic directory rename.
public final class DraftStore: @unchecked Sendable {
    public static let shared = DraftStore()
    public let appGroupID: String
    public let containerURL: URL
    private let fileManager: FileManager
    private let groupAvailable: Bool
    private let mutex = NSRecursiveLock()
    private var lockDepth = 0
    private var assetDigests: [UUID: SHA256.Digest] = [:]
    private let commitDirectory: @Sendable (URL, URL) throws -> Void

    public convenience init(
        appGroupID: String = JiPin.appGroupID,
        fileManager: FileManager = .default,
        overridesContainer: URL? = nil
    ) {
        self.init(appGroupID: appGroupID, fileManager: fileManager,
                  overridesContainer: overridesContainer, commit: { try Self.atomicCommit($0, $1) })
    }

    // Injectable commit operation lets fault tests exercise real disk writes and rollback.
    init(
        appGroupID: String = JiPin.appGroupID,
        fileManager: FileManager = .default,
        overridesContainer: URL? = nil,
        commit: @escaping @Sendable (URL, URL) throws -> Void
    ) {
        self.appGroupID = appGroupID
        self.fileManager = fileManager
        self.commitDirectory = commit
        let shared = overridesContainer ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        groupAvailable = shared != nil
        containerURL = shared ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public var isUsingAppGroup: Bool { groupAvailable }
    public var draftsRoot: URL { containerURL.appendingPathComponent("Drafts", isDirectory: true) }
    public var sharedAssetsRoot: URL { containerURL.appendingPathComponent("SharedAssets", isDirectory: true) }
    public var cacheRoot: URL { containerURL.appendingPathComponent("ExportCache", isDirectory: true) }

    public func prepare() throws {
        try transaction {
            try createDirectories()
            // A writer killed before/after commit leaves only hidden staging directories.
            let directories = try fileManager.contentsOfDirectory(at: draftsRoot, includingPropertiesForKeys: [.isDirectoryKey])
            for directory in directories where directory.lastPathComponent.hasSuffix(".tmp") {
                if (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    try? fileManager.removeItem(at: directory)
                }
            }
        }
    }

    private func createDirectories() throws {
        for directory in [draftsRoot, sharedAssetsRoot, cacheRoot] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var protected = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protected.setResourceValues(values)
        }
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        mutex.lock()
        defer { mutex.unlock() }
        if lockDepth > 0 { return try operation() }
        try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let descriptor = open(containerURL.appendingPathComponent(".jipin-store.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw Self.posixError() }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            if errno != EINTR { throw Self.posixError() }
        }
        lockDepth = 1
        defer {
            lockDepth = 0
            flock(descriptor, LOCK_UN)
        }
        return try operation()
    }

    static func atomicCommit(_ staged: URL, _ destination: URL) throws {
        let flags = FileManager.default.fileExists(atPath: destination.path) ? RENAME_SWAP : RENAME_EXCL
        guard renamex_np(staged.path, destination.path, UInt32(flags)) == 0 else { throw posixError() }
    }

    private static func posixError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }

    public func listDrafts() -> [DraftSummary] {
        (try? transaction { listUnlocked() }) ?? []
    }

    private func listUnlocked() -> [DraftSummary] {
        guard let dirs = try? fileManager.contentsOfDirectory(at: draftsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return dirs.compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent),
                  fileManager.fileExists(atPath: completeMarker(in: url).path),
                  let project = try? loadProject(from: url), project.id == id else { return nil }
            let thumb = url.appendingPathComponent("thumbnail.jpg")
            let shared = referencedAssetIDs(in: project).reduce(Int64(0)) { total, id in
                total + Int64(sharedAssetFile(id: id).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? 0)
            }
            return DraftSummary(
                id: id, name: project.name, mode: project.mode,
                updatedAt: project.updatedAt, createdAt: project.createdAt,
                photoCount: project.photoOrder.count, byteSize: directorySize(url) + shared,
                thumbnailPath: fileManager.fileExists(atPath: thumb.path) ? thumb : nil,
                isIncomplete: false, originatedFromExtension: project.originatedFromExtension
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(project: CollageProject, assets: [UUID: Data], thumbnailJPEG: Data?) throws {
        try transaction {
            try createDirectories()
            let staged = draftsRoot.appendingPathComponent(".\(project.id.uuidString).\(UUID().uuidString).tmp", isDirectory: true)
            // After a swap, staged holds the previous version. Cleanup cannot undo a commit.
            defer { try? fileManager.removeItem(at: staged) }
            do {
                guard project.schemaVersion <= JiPin.schemaVersion else { throw DraftStoreError.unsupportedVersion }
                try fileManager.createDirectory(at: staged, withIntermediateDirectories: true)
                for id in referencedAssetIDs(in: project) {
                    if let bytes = assets[id], !bytes.isEmpty {
                        try writeSharedAsset(id: id, data: bytes)
                    } else if sharedAssetFile(id: id) == nil {
                        guard let legacy = legacyAssetData(projectURL: draftURL(project.id), assetID: id) else {
                            throw DraftStoreError.missingAssets
                        }
                        try writeSharedAsset(id: id, data: legacy)
                    }
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(project).write(to: staged.appendingPathComponent("project.json"), options: .atomic)
                if let thumbnailJPEG {
                    try thumbnailJPEG.write(to: staged.appendingPathComponent("thumbnail.jpg"), options: .atomic)
                }
                try Data().write(to: completeMarker(in: staged), options: .atomic)
                try commitDirectory(staged, draftURL(project.id))
                // A cleanup error must never report an already committed draft as lost.
                try? garbageCollectSharedAssets()
            } catch {
                let ns = error as NSError
                if (ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError)
                    || (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC)) {
                    throw DraftStoreError.diskFull
                }
                throw error
            }
        }
    }

    public func load(id: UUID) throws -> LoadedDraft {
        try transaction {
            let url = draftURL(id)
            guard fileManager.fileExists(atPath: completeMarker(in: url).path) else { throw DraftStoreError.incomplete }
            let project = try loadProject(from: url)
            guard project.id == id else { throw DraftStoreError.missingProject }
            var assets: [UUID: Data] = [:]
            for id in referencedAssetIDs(in: project) {
                if let file = sharedAssetFile(id: id) {
                    assets[id] = try? Data(contentsOf: file)
                } else {
                    assets[id] = legacyAssetData(projectURL: url, assetID: id)
                }
            }
            return LoadedDraft(project: project, assets: assets)
        }
    }

    public func duplicate(id: UUID) throws -> UUID {
        try transaction {
            let loaded = try load(id: id)
            var copy = loaded.project
            copy.id = UUID()
            copy.name += " 副本"
            copy.createdAt = Date()
            copy.updatedAt = copy.createdAt
            try save(project: copy, assets: loaded.assets, thumbnailJPEG: thumbnailData(id: id))
            return copy.id
        }
    }

    public func rename(id: UUID, to name: String) throws {
        try transaction {
            var loaded = try load(id: id)
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            loaded.project.name = trimmed
            loaded.project.touch()
            try save(project: loaded.project, assets: loaded.assets, thumbnailJPEG: thumbnailData(id: id))
        }
    }

    public func delete(id: UUID) throws {
        try transaction {
            let url = draftURL(id)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
            try? garbageCollectSharedAssets()
        }
    }

    public func thumbnailData(id: UUID) -> Data? {
        try? transaction { try Data(contentsOf: draftURL(id).appendingPathComponent("thumbnail.jpg")) }
    }

    public func clearExportCache() throws {
        try transaction {
            if fileManager.fileExists(atPath: cacheRoot.path) { try fileManager.removeItem(at: cacheRoot) }
            try createDirectories()
        }
    }

    public func draftsSize() -> Int64 {
        (try? transaction { directorySize(draftsRoot) + directorySize(sharedAssetsRoot) }) ?? 0
    }

    public func cacheSize() -> Int64 { (try? transaction { directorySize(cacheRoot) }) ?? 0 }

    public func assetData(projectID: UUID, assetID: UUID) -> Data? {
        try? transaction {
            if let file = sharedAssetFile(id: assetID) { return try Data(contentsOf: file) }
            return legacyAssetData(projectURL: draftURL(projectID), assetID: assetID)
        }
    }

    public func referencedAssetIDs(in project: CollageProject) -> Set<UUID> {
        var referenced = Set(project.photoOrder)
        for object in project.objects {
            if let photo = object.photo { referenced.insert(photo.assetID) }
            if let extra = object.sticker?.assetID { referenced.insert(extra) }
        }
        if let bg = project.background.imageAssetID { referenced.insert(bg) }
        return referenced
    }

    public func sharedAssetFileCount() -> Int {
        (try? transaction {
            try fileManager.contentsOfDirectory(at: sharedAssetsRoot, includingPropertiesForKeys: nil)
                .filter { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }.count
        }) ?? 0
    }

    private func draftURL(_ id: UUID) -> URL { draftsRoot.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func completeMarker(in url: URL) -> URL { url.appendingPathComponent(".complete") }

    private func loadProject(from url: URL) throws -> CollageProject {
        let file = url.appendingPathComponent("project.json")
        guard fileManager.fileExists(atPath: file.path) else { throw DraftStoreError.missingProject }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(CollageProject.self, from: Data(contentsOf: file))
        guard project.schemaVersion <= JiPin.schemaVersion else { throw DraftStoreError.unsupportedVersion }
        return project
    }

    private func directorySize(_ url: URL) -> Int64 {
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private func suggestedExtension(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        return "dat"
    }

    private func writeSharedAsset(id: UUID, data: Data) throws {
        let digest = SHA256.hash(data: data)
        if let existing = sharedAssetFile(id: id) {
            if assetDigests[id] != digest {
                guard try Data(contentsOf: existing) == data else { throw DraftStoreError.conflictingAsset }
            }
        } else {
            try data.write(to: sharedAssetsRoot.appendingPathComponent("\(id.uuidString).\(suggestedExtension(for: data))"), options: .atomic)
        }
        assetDigests[id] = digest
    }

    private func sharedAssetFile(id: UUID) -> URL? {
        ["jpg", "png", "dat"].map { sharedAssetsRoot.appendingPathComponent("\(id.uuidString).\($0)") }
            .first { fileManager.fileExists(atPath: $0.path) }
    }

    private func legacyAssetData(projectURL: URL, assetID: UUID) -> Data? {
        let directory = projectURL.appendingPathComponent("assets", isDirectory: true)
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.first { $0.deletingPathExtension().lastPathComponent == assetID.uuidString }
            .flatMap { try? Data(contentsOf: $0) }
    }

    private func garbageCollectSharedAssets() throws {
        var live = Set<UUID>()
        let directories = try fileManager.contentsOfDirectory(at: draftsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for directory in directories where UUID(uuidString: directory.lastPathComponent) != nil {
            guard fileManager.fileExists(atPath: completeMarker(in: directory).path) else { continue }
            // Be conservative: an unreadable or future-version draft may still own assets.
            guard let project = try? loadProject(from: directory) else { return }
            live.formUnion(referencedAssetIDs(in: project))
        }
        for file in try fileManager.contentsOfDirectory(at: sharedAssetsRoot, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !live.contains(id) else { continue }
            try fileManager.removeItem(at: file)
            assetDigests[id] = nil
        }
    }
}

public enum ImageIOHelpers {
    public static func typeIdentifier(of data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return UTType.image.identifier }
        return type as String
    }

    public static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly: return true
        default: return false
        }
    }

    /// Working copies retain PNG alpha, bake orientation, strip metadata and bound decode memory.
    public static func sanitizedImageData(
        from data: Data,
        jpegQuality: CGFloat = 0.95,
        maxLongSide: CGFloat = 8192,
        maxPixelCount: CGFloat = 16_777_216
    ) -> Data? {
        autoreleasepool {
            let size = pixelSize(of: data)
            guard size.width > 0, size.height > 0, maxLongSide > 0, maxPixelCount > 0 else { return nil }
            let longest = max(size.width, size.height)
            let scale = min(1, maxLongSide / longest, sqrt(maxPixelCount / (size.width * size.height)))
            guard let image = thumbnail(from: data, maxLongSide: max(1, floor(longest * scale))) else { return nil }
            if typeIdentifier(of: data) == UTType.png.identifier || hasAlpha(image) {
                return pngData(from: image)
            }
            return jpegData(from: image, quality: jpegQuality)
        }
    }

    /// UIImage's orientation is not necessarily reflected in its cgImage pixels.
    public static func sanitizedImageData(from image: UIImage, maxLongSide: CGFloat = 4096, maxPixelCount: CGFloat = 4_194_304) -> Data? {
        let sourceSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let factor = min(1, maxLongSide / max(sourceSize.width, sourceSize.height), sqrt(maxPixelCount / (sourceSize.width * sourceSize.height)))
        let size = CGSize(width: max(1, floor(sourceSize.width * factor)), height: max(1, floor(sourceSize.height * factor)))
        let alpha = image.cgImage.map(hasAlpha) ?? true
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = !alpha
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = rendered.cgImage else { return nil }
        return alpha ? pngData(from: cgImage) : jpegData(from: cgImage, quality: 0.95)
    }

    public static func pixelSize(of data: Data) -> CGSize {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = props[kCGImagePropertyPixelHeight] as? NSNumber
        else { return .zero }
        var size = CGSize(width: width.doubleValue, height: height.doubleValue)
        if let orientation = props[kCGImagePropertyOrientation] as? UInt32, (5...8).contains(orientation) {
            size = CGSize(width: size.height, height: size.width)
        }
        return size
    }

    public static func storedPixelSize(of data: Data) -> CGSize {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = props[kCGImagePropertyPixelHeight] as? NSNumber
        else { return .zero }
        return CGSize(width: width.doubleValue, height: height.doubleValue)
    }

    public static func thumbnail(from data: Data, maxLongSide: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongSide,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func fullImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let stored = storedPixelSize(of: data)
        let maxSide = max(stored.width, stored.height, 1)
        let bakeOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let baked = CGImageSourceCreateThumbnailAtIndex(source, 0, bakeOptions as CFDictionary) {
            return baked
        }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: true] as CFDictionary)
    }

    public static func sRGBImage(from image: CGImage) -> CGImage {
        if image.colorSpace?.name == CGColorSpace.sRGB { return image }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return image }
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: bitmapInfo
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    public static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let srgb = sRGBImage(from: image)
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, srgb, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func jpegWithOrientation(from image: CGImage, orientation: UInt32) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, [
            kCGImageDestinationLossyCompressionQuality: 0.9,
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func containsGPS(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return false }
        return props[kCGImagePropertyGPSDictionary] != nil
    }

    public static func jpegWithGPS(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 31.2304,
            kCGImagePropertyGPSLongitude: 121.4737
        ]
        CGImageDestinationAddImage(dest, image, [
            kCGImageDestinationLossyCompressionQuality: 0.9,
            kCGImagePropertyGPSDictionary: gps
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func pngData(from image: CGImage) -> Data? {
        let srgb = sRGBImage(from: image)
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, srgb, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func strippedJPEG(from data: Data, quality: CGFloat) -> Data? {
        guard storedPixelSize(of: data) != .zero,
              let image = fullImage(from: data) ?? thumbnail(from: data, maxLongSide: 8192)
        else { return nil }
        return jpegData(from: image, quality: quality)
    }

    public static func heicData(from image: CGImage, quality: CGFloat = 0.9) -> Data? {
        let srgb = sRGBImage(from: image)
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, srgb, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
