import Foundation
import UIKit

public enum PageLength: String, CaseIterable, Identifiable, Sendable {
    case square, reading, story
    public var id: String { rawValue }
    public var title: String {
        switch self { case .square: return "方形"; case .reading: return "阅读"; case .story: return "长页" }
    }
    public var factor: CGFloat {
        switch self { case .square: return 1; case .reading: return 1.25; case .story: return 16 / 9 }
    }
}

public enum PagedExportError: LocalizedError {
    case invalidSize, tooLarge, failedPage(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidSize: return "无法确定分页尺寸。"
        case .tooLarge: return "内容超过 80 页或 1.2 亿像素，请减少照片或改用标准尺寸。"
        case .failedPage(let index): return "第 \(index + 1) 页生成失败，尚未交付任何分页文件。"
        }
    }
}

public struct PageExportPlan: Hashable, Sendable {
    public let canvasSize: CGSize
    public let regions: [CGRect]
    public let direction: StripDirection

    public static func make(size: CGSize, direction: StripDirection, length: PageLength) throws -> PageExportPlan {
        guard size.width.isFinite, size.height.isFinite, size.width >= 1, size.height >= 1 else { throw PagedExportError.invalidSize }
        let size = CGSize(width: ceil(size.width), height: ceil(size.height))
        guard size.width * size.height <= 120_000_000 else { throw PagedExportError.tooLarge }
        let vertical = direction == .vertical
        let cross = vertical ? size.width : size.height
        let long = vertical ? size.height : size.width
        let step = max(floor(cross * length.factor), 1)
        guard cross <= 4096, step <= 8192 else { throw PagedExportError.invalidSize }
        let count = Int(ceil(long / step))
        guard count <= 80 else { throw PagedExportError.tooLarge }
        let regions = (0..<count).map { index -> CGRect in
            let offset = CGFloat(index) * step
            let remainder = min(step, long - offset)
            return vertical ? CGRect(x: 0, y: offset, width: cross, height: remainder)
                : CGRect(x: offset, y: 0, width: remainder, height: cross)
        }
        return PageExportPlan(canvasSize: size, regions: regions, direction: direction)
    }

    public static func make(project: CollageProject, assets: AssetProviding, length: PageLength) throws -> PageExportPlan {
        let size: CGSize
        switch ExportGeometry.outputSize(for: project, assets: assets) {
        case .ok(let value), .needsChoice(let value, _): size = value
        }
        return try make(size: size, direction: project.longStrip?.direction ?? .vertical, length: length)
    }
}

public struct ExportedPages: Sendable {
    public let directory: URL
    public let files: [URL]
    public let byteCount: Int64
    public func remove() { try? FileManager.default.removeItem(at: directory) }
}

public enum PagedExporter {
    /// Writes one bounded bitmap at a time. The incomplete batch is deleted on cancellation or failure.
    public static func export(project: CollageProject, assets: DataAssetLibrary, plan: PageExportPlan,
                              directory: URL = FileManager.default.temporaryDirectory) throws -> ExportedPages {
        try export(project: project, assets: assets, plan: plan, directory: directory,
                   writePage: { data, file in try data.write(to: file, options: .atomic) })
    }

    static func export(project: CollageProject, assets: DataAssetLibrary, plan: PageExportPlan,
                       directory: URL, writePage: (Data, URL) throws -> Void) throws -> ExportedPages {
        let location = directory.appendingPathComponent("JiPin-pages-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: location) } }
        var files: [URL] = []
        var bytes: Int64 = 0
        for (index, region) in plan.regions.enumerated() {
            try Task.checkCancellation()
            let data: Data = try autoreleasepool {
                let image = renderPage(project: project, assets: assets, plan: plan, region: region)
                guard let cg = image.cgImage,
                      let data = project.exportPreference.format == .png ? ImageIOHelpers.pngData(from: cg)
                        : ImageIOHelpers.jpegData(from: cg, quality: JiPin.jpegQuality) else { throw PagedExportError.failedPage(index) }
                return data
            }
            let suffix = project.exportPreference.format == .png ? "png" : "jpg"
            let file = location.appendingPathComponent(String(format: "%02d", index + 1) + "-极拼." + suffix)
            try writePage(data, file)
            files.append(file); bytes += Int64(data.count)
        }
        try Task.checkCancellation()
        completed = true
        return ExportedPages(directory: location, files: files, byteCount: bytes)
    }

    public static func renderPage(project: CollageProject, assets: AssetProviding, plan: PageExportPlan, region: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1; format.opaque = !CollageRenderer.allowsTransparent(project); format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: region.size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: -region.minX, y: -region.minY)
            cg.clip(to: region)
            CollageRenderer.shared.draw(project: project, assets: assets, canvasSize: plan.canvasSize,
                                        preview: false, visibleRect: region, in: cg)
        }
    }
}
