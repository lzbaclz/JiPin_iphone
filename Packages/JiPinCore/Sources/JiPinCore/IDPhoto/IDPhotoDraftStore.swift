import Foundation
import CoreGraphics
import CryptoKit
import ImageIO
import Darwin

public enum IDPhotoDraftStoreError: LocalizedError, Equatable {
    case incomplete, missingSource, sourceChanged, invalidSource, invalidMask, invalidAnalysis, diskFull
    public var errorDescription: String? {
        switch self {
        case .incomplete: return "证件照草稿尚未保存完成，或文件已经损坏。"
        case .missingSource: return "证件照原片丢失或损坏，无法恢复，请重新导入照片。"
        case .sourceChanged: return "原片与已有草稿不一致，已有草稿仍保留。换照片时请创建新草稿。"
        case .invalidSource: return "无法读取这张照片，请选择有效的图片后重试。"
        case .invalidMask: return "人像边缘数据无效，请重新识别后保存。已有草稿仍保留。"
        case .invalidAnalysis: return "人像分析记录无效，已有草稿仍保留。请重新识别后保存。"
        case .diskFull: return "存储空间不足，本次草稿未写入，已有草稿仍保留。"
        }
    }
}

public struct IDPhotoLoadedDraft: Sendable {
    public var project: IDPhotoProject
    public var sourceData: Data
    public var maskData: Data?
    public var faceRegions: [IDPhotoFaceRegion]
    public var maskIssue: String?
    public var algorithmVersion: String
}

public struct IDPhotoDraftSummary: Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var template: IDPhotoTemplate
    public var createdAt: Date
    public var updatedAt: Date
    public var thumbnailPath: URL?
}

/// Separate from Collage Drafts/SharedAssets. Failed staging never modifies a previously committed draft.
/// Methods are synchronous and can run on a worker queue. File locks also serialize multiple store instances.
public final class IDPhotoDraftStore: @unchecked Sendable {
    public static let shared = IDPhotoDraftStore()
    public let containerURL: URL
    public var draftsRoot: URL { containerURL.appendingPathComponent("IDPhotoDrafts", isDirectory: true) }
    private let fileManager: FileManager
    private let mutex = NSRecursiveLock()
    private let commitDirectory: @Sendable (URL, URL) throws -> Void
    private var lockDepth = 0
    private static let sourceByteLimit = 128 * 1_024 * 1_024
    private static let maskByteLimit = 32 * 1_024 * 1_024
    private static let jsonByteLimit = 24 * 1_024 * 1_024

    public convenience init(containerURL: URL? = nil, fileManager: FileManager = .default) {
        self.init(containerURL: containerURL, fileManager: fileManager, commit: { try Self.atomicCommit($0, $1) })
    }

    // A failing commit can be injected by focused storage tests after all staged files have been written.
    init(containerURL: URL? = nil, fileManager: FileManager = .default,
         commit: @escaping @Sendable (URL, URL) throws -> Void) {
        self.fileManager = fileManager
        self.containerURL = containerURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JiPin", isDirectory: true)
        self.commitDirectory = commit
    }

    public func prepare() throws {
        try transaction {
            try createDirectories()
            for directory in try fileManager.contentsOfDirectory(at: draftsRoot, includingPropertiesForKeys: nil)
                where directory.lastPathComponent.hasPrefix(".") && directory.lastPathComponent.hasSuffix(".tmp") {
                try? fileManager.removeItem(at: directory)
            }
        }
    }

    public func save(project: IDPhotoProject, sourceData: Data, maskData: Data?, faceRegions: [IDPhotoFaceRegion],
                     thumbnailJPEG: Data? = nil, algorithmVersion: String = "vision-person-v1") throws {
        try transaction {
            try createDirectories()
            try project.validate()
            guard let sourceSize = Self.validImageSize(sourceData, maxBytes: Self.sourceByteLimit, maxSide: 16_384, maxPixels: 67_108_864)
            else { throw IDPhotoDraftStoreError.invalidSource }
            guard (1...128).contains(algorithmVersion.count), faceRegions.count <= 32 else { throw IDPhotoDraftStoreError.invalidAnalysis }
            do { try faceRegions.forEach { try $0.validate() } } catch { throw IDPhotoDraftStoreError.invalidAnalysis }
            let maskSize: CGSize?
            if let maskData {
                guard let size = Self.validImageSize(maskData, maxBytes: Self.maskByteLimit, maxSide: 4_096, maxPixels: 8_388_608)
                else { throw IDPhotoDraftStoreError.invalidMask }
                maskSize = size
            } else { maskSize = nil }
            let sourceDigest = Self.digest(sourceData)
            let destination = directory(project.id)
            if fileManager.fileExists(atPath: destination.path) {
                guard fileManager.fileExists(atPath: destination.appendingPathComponent(".complete").path) else {
                    throw IDPhotoDraftStoreError.incomplete
                }
                _ = try readProject(destination, expectedID: project.id)
                let previous = try readManifest(destination)
                guard previous.sourceDigest == sourceDigest else { throw IDPhotoDraftStoreError.sourceChanged }
            }
            let staged = draftsRoot.appendingPathComponent(".\(project.id.uuidString).\(UUID().uuidString).tmp", isDirectory: true)
            defer { try? fileManager.removeItem(at: staged) }
            do {
                try fileManager.createDirectory(at: staged, withIntermediateDirectories: true)
                try sourceData.write(to: staged.appendingPathComponent("source.image"), options: .atomic)
                if let maskData { try maskData.write(to: staged.appendingPathComponent("mask.png"), options: .atomic) }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                let projectJSON = try encoder.encode(project)
                guard projectJSON.count <= Self.jsonByteLimit else { throw IDPhotoValidationError.invalidProject }
                try projectJSON.write(to: staged.appendingPathComponent("project.json"), options: .atomic)
                let manifest = Manifest(schemaVersion: 1, sourceDigest: sourceDigest, sourceSize: sourceSize,
                                        maskDigest: maskData.map(Self.digest), maskSize: maskSize,
                                        faceRegions: faceRegions, algorithmVersion: algorithmVersion)
                try encoder.encode(manifest).write(to: staged.appendingPathComponent("analysis.json"), options: .atomic)
                if let thumbnailJPEG, thumbnailJPEG.count <= 4 * 1_024 * 1_024,
                   Self.validImageSize(thumbnailJPEG, maxBytes: 4 * 1_024 * 1_024, maxSide: 2_048, maxPixels: 4_194_304) != nil {
                    try thumbnailJPEG.write(to: staged.appendingPathComponent("thumbnail.jpg"), options: .atomic)
                }
                try Data().write(to: staged.appendingPathComponent(".complete"), options: .atomic)
                try commitDirectory(staged, destination)
                // After RENAME_SWAP the staging path owns the old revision; defer safely removes that revision.
            } catch {
                let ns = error as NSError
                if (ns.domain == NSCocoaErrorDomain && ns.code == NSFileWriteOutOfSpaceError)
                    || (ns.domain == NSPOSIXErrorDomain && ns.code == Int(ENOSPC)) { throw IDPhotoDraftStoreError.diskFull }
                throw error
            }
        }
    }

    public func load(id: UUID) throws -> IDPhotoLoadedDraft {
        try transaction {
            let folder = directory(id)
            let project = try readProject(folder, expectedID: id)
            let manifest = try readManifest(folder)
            guard let source = try? boundedRead(folder.appendingPathComponent("source.image"), limit: Self.sourceByteLimit),
                  Self.digest(source) == manifest.sourceDigest,
                  let sourceSize = Self.validImageSize(source, maxBytes: Self.sourceByteLimit, maxSide: 16_384, maxPixels: 67_108_864),
                  sourceSize == manifest.sourceSize else { throw IDPhotoDraftStoreError.missingSource }
            var mask: Data?
            var issue: String?
            if let maskDigest = manifest.maskDigest {
                if let candidate = try? boundedRead(folder.appendingPathComponent("mask.png"), limit: Self.maskByteLimit),
                   Self.digest(candidate) == maskDigest,
                   let maskSize = Self.validImageSize(candidate, maxBytes: Self.maskByteLimit, maxSide: 4_096, maxPixels: 8_388_608),
                   maskSize == manifest.maskSize {
                    mask = candidate
                } else {
                    issue = "人像蒙版丢失或损坏。原片和编辑参数已保留，请重新识别并检查边缘后再换底导出。"
                }
            }
            return IDPhotoLoadedDraft(project: project, sourceData: source, maskData: mask,
                                      faceRegions: manifest.faceRegions, maskIssue: issue, algorithmVersion: manifest.algorithmVersion)
        }
    }

    public func listDrafts() -> [IDPhotoDraftSummary] {
        (try? transaction {
            guard fileManager.fileExists(atPath: draftsRoot.path) else { return [] }
            return try fileManager.contentsOfDirectory(at: draftsRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .compactMap { url -> IDPhotoDraftSummary? in
                    guard let id = UUID(uuidString: url.lastPathComponent), let project = try? readProject(url, expectedID: id) else { return nil }
                    let thumbnail = url.appendingPathComponent("thumbnail.jpg")
                    return IDPhotoDraftSummary(id: id, name: project.name, template: project.template,
                                               createdAt: project.createdAt, updatedAt: project.updatedAt,
                                               thumbnailPath: fileManager.fileExists(atPath: thumbnail.path) ? thumbnail : nil)
                }.sorted { $0.updatedAt > $1.updatedAt }
        }) ?? []
    }

    public func delete(id: UUID) throws {
        try transaction {
            let path = directory(id)
            if fileManager.fileExists(atPath: path.path) { try fileManager.removeItem(at: path) }
        }
    }

    public func thumbnailData(id: UUID) -> Data? {
        try? transaction { try boundedRead(directory(id).appendingPathComponent("thumbnail.jpg"), limit: 4 * 1_024 * 1_024) }
    }

    private struct Manifest: Codable {
        var schemaVersion: Int
        var sourceDigest: String
        var sourceSize: CGSize
        var maskDigest: String?
        var maskSize: CGSize?
        var faceRegions: [IDPhotoFaceRegion]
        var algorithmVersion: String
    }

    private func readManifest(_ folder: URL) throws -> Manifest {
        let value = try JSONDecoder().decode(Manifest.self, from: boundedRead(folder.appendingPathComponent("analysis.json"), limit: 1_024 * 1_024))
        guard value.schemaVersion == 1 else { throw IDPhotoValidationError.unsupportedVersion }
        guard value.sourceDigest.count == 64, value.maskDigest == nil || value.maskDigest?.count == 64,
              value.sourceSize.width.isFinite, value.sourceSize.height.isFinite, value.sourceSize.width > 0,
              value.sourceSize.height > 0, (1...128).contains(value.algorithmVersion.count),
              value.faceRegions.count <= 32 else { throw IDPhotoDraftStoreError.incomplete }
        return value
    }

    private func readProject(_ folder: URL, expectedID: UUID) throws -> IDPhotoProject {
        guard fileManager.fileExists(atPath: folder.appendingPathComponent(".complete").path) else { throw IDPhotoDraftStoreError.incomplete }
        let project = try JSONDecoder().decode(IDPhotoProject.self, from: boundedRead(folder.appendingPathComponent("project.json"), limit: Self.jsonByteLimit))
        guard project.id == expectedID else { throw IDPhotoValidationError.invalidProject }
        return project
    }

    private func directory(_ id: UUID) -> URL { draftsRoot.appendingPathComponent(id.uuidString, isDirectory: true) }
    private func boundedRead(_ url: URL, limit: Int) throws -> Data {
        let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, let count = info.fileSize, count <= limit else {
            throw IDPhotoDraftStoreError.incomplete
        }
        let bytes = try Data(contentsOf: url)
        guard bytes.count <= limit else { throw IDPhotoDraftStoreError.incomplete }
        return bytes
    }
    private static func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }

    private static func validImageSize(_ data: Data, maxBytes: Int, maxSide: Int, maxPixels: Int) -> CGSize? {
        guard !data.isEmpty, data.count <= maxBytes,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0, width <= maxSide, height <= maxSide, width * height <= maxPixels,
              ImageIOHelpers.thumbnail(from: data, maxLongSide: 16) != nil else { return nil }
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation) ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }
    private func createDirectories() throws {
        try fileManager.createDirectory(at: draftsRoot, withIntermediateDirectories: true)
        var url = draftsRoot
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        mutex.lock(); defer { mutex.unlock() }
        if lockDepth > 0 { return try operation() }
        try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let descriptor = open(containerURL.appendingPathComponent(".jipin-idphoto-store.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw Self.posixError() }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 { if errno != EINTR { throw Self.posixError() } }
        lockDepth = 1
        defer { lockDepth = 0; flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private static func atomicCommit(_ staged: URL, _ destination: URL) throws {
        let flags = FileManager.default.fileExists(atPath: destination.path) ? RENAME_SWAP : RENAME_EXCL
        guard renamex_np(staged.path, destination.path, UInt32(flags)) == 0 else { throw posixError() }
    }
    private static func posixError() -> NSError { NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
}
