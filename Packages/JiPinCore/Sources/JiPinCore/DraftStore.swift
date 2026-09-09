import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public enum DraftStoreError: LocalizedError, Equatable {
    case incomplete
    case missingProject
    case encodingFailed
    case appGroupUnavailable
    case diskFull

    public var errorDescription: String? {
        switch self {
        case .incomplete: return "草稿尚未写入完成，无法打开。"
        case .missingProject: return "找不到草稿文件。"
        case .encodingFailed: return "无法保存草稿。"
        case .appGroupUnavailable: return "共享存储不可用。"
        case .diskFull: return "存储空间不足，这次没有写入。已有草稿仍保留。"
        }
    }
}

public struct LoadedDraft: Sendable {
    public var project: CollageProject
    public var assets: [UUID: Data]
}

public final class DraftStore: @unchecked Sendable {
    public static let shared = DraftStore()

    public let appGroupID: String
    private let fileManager: FileManager
    private let overridesContainer: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let ioQueue = DispatchQueue(label: "com.jipin.drafts", qos: .userInitiated)

    public init(
        appGroupID: String = JiPin.appGroupID,
        fileManager: FileManager = .default,
        overridesContainer: URL? = nil
    ) {
        self.appGroupID = appGroupID
        self.fileManager = fileManager
        self.overridesContainer = overridesContainer
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public var isUsingAppGroup: Bool {
        if overridesContainer != nil { return true }
        guard let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return false
        }
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if groupURL.standardizedFileURL == documents.standardizedFileURL { return false }
        let probe = groupURL.appendingPathComponent(".jipin-group-ok")
        do {
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try fileManager.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    public var containerURL: URL {
        if let overridesContainer { return overridesContainer }
        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public var draftsRoot: URL {
        containerURL.appendingPathComponent("Drafts", isDirectory: true)
    }

    public var sharedAssetsRoot: URL {
        containerURL.appendingPathComponent("SharedAssets", isDirectory: true)
    }

    public var cacheRoot: URL {
        containerURL.appendingPathComponent("ExportCache", isDirectory: true)
    }

    public func prepare() throws {
        try fileManager.createDirectory(at: draftsRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sharedAssetsRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    public func listDrafts() -> [DraftSummary] {
        guard let dirs = try? fileManager.contentsOfDirectory(
            at: draftsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return dirs.compactMap { url -> DraftSummary? in
            let complete = fileManager.fileExists(atPath: completeMarker(in: url).path)
            guard complete else { return nil }
            guard let project = try? loadProject(from: url) else { return nil }
            let size = directorySize(url)
            let thumb = url.appendingPathComponent("thumbnail.jpg")
            let shared = referencedAssetIDs(in: project).reduce(Int64(0)) { total, id in
                total + Int64(sharedAssetFile(id: id).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? 0)
            }
            return DraftSummary(
                id: project.id,
                name: project.name,
                mode: project.mode,
                updatedAt: project.updatedAt,
                createdAt: project.createdAt,
                photoCount: project.photoOrder.count,
                byteSize: size + shared,
                thumbnailPath: fileManager.fileExists(atPath: thumb.path) ? thumb : nil,
                isIncomplete: false,
                originatedFromExtension: project.originatedFromExtension
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func save(
        project: CollageProject,
        assets: [UUID: Data],
        thumbnailJPEG: Data?
    ) throws {
        let tempURL = draftsRoot.appendingPathComponent("\(project.id.uuidString).tmp", isDirectory: true)
        do {
            try prepare()
            let finalURL = draftURL(project.id)
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)

            let data = try encoder.encode(project)
            try data.write(to: tempURL.appendingPathComponent("project.json"), options: .atomic)

            let referenced = referencedAssetIDs(in: project)
            for (id, payload) in assets where referenced.contains(id) {
                try writeSharedAsset(id: id, data: payload)
            }
            if let thumbnailJPEG {
                try thumbnailJPEG.write(to: tempURL.appendingPathComponent("thumbnail.jpg"), options: .atomic)
            }
            try Data().write(to: completeMarker(in: tempURL), options: .atomic)

            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: tempURL, to: finalURL)
            try garbageCollectSharedAssets()
        } catch {
            if fileManager.fileExists(atPath: tempURL.path) {
                try? fileManager.removeItem(at: tempURL)
            }
            let ns = error as NSError
            if ns.code == NSFileWriteOutOfSpaceError || (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC)) {
                throw DraftStoreError.diskFull
            }
            throw error
        }
    }

    public func load(id: UUID) throws -> LoadedDraft {
        let url = draftURL(id)
        guard fileManager.fileExists(atPath: completeMarker(in: url).path) else {
            throw DraftStoreError.incomplete
        }
        let project = try loadProject(from: url)
        var assets: [UUID: Data] = [:]
        for assetID in referencedAssetIDs(in: project) {
            if let data = assetData(projectID: id, assetID: assetID) {
                assets[assetID] = data
            }
        }
        return LoadedDraft(project: project, assets: assets)
    }

    public func duplicate(id: UUID) throws -> UUID {
        let loaded = try load(id: id)
        var copy = loaded.project
        copy.id = UUID()
        copy.name = loaded.project.name + " 副本"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        try save(project: copy, assets: loaded.assets, thumbnailJPEG: thumbnailData(id: id))
        return copy.id
    }

    public func rename(id: UUID, to name: String) throws {
        var loaded = try load(id: id)
        loaded.project.name = name
        loaded.project.touch()
        try save(project: loaded.project, assets: loaded.assets, thumbnailJPEG: thumbnailData(id: id))
    }

    public func delete(id: UUID) throws {
        let url = draftURL(id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try? garbageCollectSharedAssets()
    }

    public func thumbnailData(id: UUID) -> Data? {
        try? Data(contentsOf: draftURL(id).appendingPathComponent("thumbnail.jpg"))
    }

    public func clearExportCache() throws {
        if fileManager.fileExists(atPath: cacheRoot.path) {
            try fileManager.removeItem(at: cacheRoot)
        }
        try fileManager.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    public func draftsSize() -> Int64 {
        directorySize(draftsRoot) + directorySize(sharedAssetsRoot)
    }

    public func cacheSize() -> Int64 {
        directorySize(cacheRoot)
    }

    public func assetData(projectID: UUID, assetID: UUID) -> Data? {
        if let shared = sharedAssetFile(id: assetID), let data = try? Data(contentsOf: shared) {
            return data
        }
        return legacyAssetData(projectURL: draftURL(projectID), assetID: assetID)
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
        let files = (try? fileManager.contentsOfDirectory(at: sharedAssetsRoot, includingPropertiesForKeys: nil)) ?? []
        return files.filter { !$0.lastPathComponent.hasPrefix(".") }.count
    }

    private func draftURL(_ id: UUID) -> URL {
        draftsRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func completeMarker(in url: URL) -> URL {
        url.appendingPathComponent(".complete")
    }

    private func loadProject(from url: URL) throws -> CollageProject {
        let file = url.appendingPathComponent("project.json")
        guard fileManager.fileExists(atPath: file.path) else { throw DraftStoreError.missingProject }
        let data = try Data(contentsOf: file)
        return try decoder.decode(CollageProject.self, from: data)
    }

    private func directorySize(_ url: URL) -> Int64 {
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let file = enumerator?.nextObject() as? URL {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private func suggestedExtension(for data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        return "dat"
    }

    private func writeSharedAsset(id: UUID, data: Data) throws {
        try prepare()
        let ext = suggestedExtension(for: data)
        let dest = sharedAssetsRoot.appendingPathComponent("\(id.uuidString).\(ext)")
        try data.write(to: dest, options: .atomic)
        for leftover in matchingAssetFiles(in: sharedAssetsRoot, id: id) where leftover.lastPathComponent != dest.lastPathComponent {
            try fileManager.removeItem(at: leftover)
        }
    }

    private func sharedAssetFile(id: UUID) -> URL? {
        matchingAssetFiles(in: sharedAssetsRoot, id: id).first
    }

    private func legacyAssetData(projectURL: URL, assetID: UUID) -> Data? {
        let assetsDir = projectURL.appendingPathComponent("assets", isDirectory: true)
        return matchingAssetFiles(in: assetsDir, id: assetID).first.flatMap { try? Data(contentsOf: $0) }
    }

    private func matchingAssetFiles(in directory: URL, id: UUID) -> [URL] {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.deletingPathExtension().lastPathComponent == id.uuidString }
    }

    private func garbageCollectSharedAssets() throws {
        try prepare()
        var live = Set<UUID>()
        for summary in listDrafts() {
            guard let project = try? loadProject(from: draftURL(summary.id)) else { continue }
            live.formUnion(referencedAssetIDs(in: project))
        }
        let files = (try? fileManager.contentsOfDirectory(at: sharedAssetsRoot, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard let uuid = UUID(uuidString: name), !live.contains(uuid) else { continue }
            try fileManager.removeItem(at: file)
        }
    }
}

public enum ImageIOHelpers {
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
