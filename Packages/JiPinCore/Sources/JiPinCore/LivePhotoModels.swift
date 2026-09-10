import CoreGraphics
import Foundation

public enum LivePhotoPolicy {
    public static let maxSources = 9
    public static let maxMovieBytes: Int64 = 128 * 1024 * 1024
    public static let frameRate: Int32 = 30
    public static let durations: [Double] = [1.5, 2, 3]
}

public struct LivePhotoSource: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var duration: Double
    public var stillTime: Double
    public var pixelSize: CGSize
    public var hasAudio: Bool
    public init(id: UUID, duration: Double, stillTime: Double, pixelSize: CGSize, hasAudio: Bool) {
        self.id = id; self.duration = duration; self.stillTime = stillTime; self.pixelSize = pixelSize; self.hasAudio = hasAudio
    }
}

public struct LivePhotoSettings: Codable, Hashable, Sendable {
    public var duration: Double
    public var audioSourceID: UUID?
    public init(duration: Double = 3, audioSourceID: UUID? = nil) {
        self.duration = duration; self.audioSourceID = audioSourceID
    }
    public var safeDuration: Double { LivePhotoPolicy.durations.contains(duration) ? duration : 3 }
    public var coverTime: Double { Double(Int(safeDuration * 30) / 2) / 30 }
}

/// Immutable file ownership keeps imported videos alive during previews, undo and background saves.
/// A loaded draft leases a hard link, so removing its last on-disk reference cannot break editor undo.
public final class MediaFileLease: Hashable, @unchecked Sendable {
    public let directory: URL
    private let removesOnDeinit: Bool
    public init(directory: URL, removesOnDeinit: Bool = false) {
        self.directory = directory; self.removesOnDeinit = removesOnDeinit
    }
    public static func temporary(prefix: String = "JiPin-Live") throws -> MediaFileLease {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return MediaFileLease(directory: directory, removesOnDeinit: true)
    }
    public static func leasedCopy(of source: URL) throws -> (MediaFileLease, URL) {
        let lease = try temporary()
        let target = lease.directory.appendingPathComponent("motion.mov")
        do { try FileManager.default.linkItem(at: source, to: target) }
        catch { try FileManager.default.copyItem(at: source, to: target) }
        return (lease, target)
    }
    deinit { if removesOnDeinit { try? FileManager.default.removeItem(at: directory) } }
    public static func == (lhs: MediaFileLease, rhs: MediaFileLease) -> Bool { lhs.directory == rhs.directory }
    public func hash(into hasher: inout Hasher) { hasher.combine(directory) }
}

public struct LivePhotoClip: Hashable, Sendable {
    public var source: LivePhotoSource
    public let url: URL
    public let lease: MediaFileLease
    public init(source: LivePhotoSource, url: URL, lease: MediaFileLease) {
        self.source = source; self.url = url; self.lease = lease
    }
}

public enum LivePhotoError: LocalizedError {
    case missingResources, invalidVideo, resourceTooLarge, tooManySources, noLivePhotos
    case decodeFailed, encodingFailed, invalidPair, photoPermission, unsupportedSave
    public var errorDescription: String? {
        switch self {
        case .missingResources: return "Live 动态资源缺失，请重新选择这张照片。"
        case .invalidVideo: return "这张 Live 的动态视频无法读取，或长度超出支持范围。"
        case .resourceTooLarge: return "这张 Live 的资源过大，暂时无法导入。"
        case .tooManySources: return "每份 Live 拼图最多支持 9 个动态来源，请减少 Live 照片。"
        case .noLivePhotos: return "当前作品没有 Live 照片，可以先添加 Live，或导出静态图片。"
        case .decodeFailed: return "动态视频解码失败，请替换相关照片后重试。"
        case .encodingFailed: return "Live 生成失败，已有照片和草稿保留，可以重试。"
        case .invalidPair: return "系统未能识别生成的 Live Photo，尚未保存，请重试。"
        case .photoPermission: return "未获得添加照片权限。可在系统设置中允许保存，或使用视频分享。"
        case .unsupportedSave: return "当前系统暂时不能保存 Live Photo。"
        }
    }
}

public extension CollageProject {
    var resolvedLiveSources: [LivePhotoSource] {
        let active = Set(photoLayers.compactMap { $0.photo?.assetID })
        var seen = Set<UUID>()
        return (liveSources ?? []).filter { active.contains($0.id) && seen.insert($0.id).inserted }
    }
    var hasLivePhotos: Bool { !resolvedLiveSources.isEmpty }
}
