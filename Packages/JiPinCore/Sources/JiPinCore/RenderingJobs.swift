import Foundation
import UIKit

public struct PreviewRequest: Hashable, Sendable {
    public var project: CollageProject
    public var pixelSize: CGSize
    public var assetRevision: UInt64

    public init(project: CollageProject, displaySize: CGSize, displayScale: CGFloat, zoom: CGFloat = 1, assetRevision: UInt64 = 0, interactive: Bool = false) {
        self.project = project
        self.assetRevision = assetRevision
        let scale = (interactive ? min(max(displayScale, 1), 1.5) : max(displayScale, 1)) * min(max(zoom, 1), 2)
        let requested = CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
        let longest = max(requested.width, requested.height, 1)
        let reduction = min(1, 16384 / longest, sqrt(8_388_608 / max(requested.width * requested.height, 1)))
        pixelSize = CGSize(width: max(1, floor(requested.width * reduction)), height: max(1, floor(requested.height * reduction)))
    }
}

/// Serial preview work avoids a backlog of concurrent full-canvas image decodes.
public actor PreviewRendering {
    public static let shared = PreviewRendering()
    private var cached: PreviewAssets?
    private var projectID: UUID?
    private var revision: UInt64?
    public init() {}

    public func render(_ request: PreviewRequest, assets: DataAssetLibrary) -> UIImage? {
        guard !Task.isCancelled, request.pixelSize.width >= 2, request.pixelSize.height >= 2 else { return nil }
        if cached == nil || projectID != request.project.id || revision != request.assetRevision {
            cached = PreviewAssets(assets); projectID = request.project.id; revision = request.assetRevision
        }
        cached?.attachImages(assets.images)
        defer { cached?.releaseInput() }
        return autoreleasepool {
            CollageRenderer.shared.render(project: request.project, assets: cached!, canvasSize: request.pixelSize, preview: true)
        }
    }
}

/// The complete thumbnail + disk transaction runs off the UI actor, in submission order.
public actor DraftWriting {
    public static let shared = DraftWriting()
    private var versions: [URL: Date] = [:]

    public func save(project: CollageProject, assets: DataAssetLibrary, store: DraftStore) throws {
        let key = store.containerURL.appendingPathComponent(project.id.uuidString)
        if let committed = versions[key], project.updatedAt < committed { return }
        try autoreleasepool {
            let size: CGSize
            if project.mode == .longStrip {
                let output = ExportGeometry.outputSize(for: project, assets: assets)
                let dimensions: CGSize
                switch output {
                case .ok(let value), .needsChoice(_, let value): dimensions = value
                }
                let scale = 512 / max(dimensions.width, dimensions.height, 1)
                size = CGSize(width: max(1, dimensions.width * scale), height: max(1, dimensions.height * scale))
            } else {
                size = project.canvas.size(maxLongSide: 512)
            }
            let thumbnail = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: true)
                .jpegData(compressionQuality: 0.8)
            try store.save(project: project, assets: assets.images, thumbnailJPEG: thumbnail, motions: assets.motions)
        }
        versions[key] = project.updatedAt
        if versions.count > 1024, let oldest = versions.min(by: { $0.value < $1.value })?.key { versions[oldest] = nil }
    }
}
