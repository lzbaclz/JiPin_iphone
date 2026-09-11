import UIKit

/// The two original examples ship as ready-to-read Live resources, so trying them never needs an encode.
public enum LivePhotoSamples {
    public static func make(count: Int = 2, progress: (@Sendable (Double) async -> Void)? = nil) async throws -> [ImportedPhoto] {
        let count = min(max(count, 0), LivePhotoPolicy.maxSources)
        var photos: [ImportedPhoto] = []
        for index in 0..<count {
            try Task.checkCancellation()
            let pair = try await sourcePair(index: index % 2) { value in
                await progress?((Double(index) + value * 0.8) / Double(count))
            }
            let id = UUID()
            let (lease, movie) = try MediaFileLease.leasedCopy(of: pair.video)
            let source = try await LivePhotoMedia.inspectMovie(movie, id: id)
            try Task.checkCancellation()
            guard let data = ImageIOHelpers.sanitizedImageData(from: try Data(contentsOf: pair.image)) else {
                throw LivePhotoError.missingResources
            }
            photos.append(ImportedPhoto(id: id, filename: "会动的小日常 \(index + 1)", data: data,
                                        pixelSize: ImageIOHelpers.pixelSize(of: data), utType: ImageIOHelpers.typeIdentifier(of: data),
                                        liveClip: LivePhotoClip(source: source, url: movie, lease: lease)))
            await progress?(Double(index + 1) / Double(count))
        }
        return photos
    }

    // A deterministic source exporter also permits development builds to regenerate the bundled originals.
    // Publish a complete directory atomically; concurrent callers can only read a matching still/movie pair.
    static func sourcePair(index: Int, progress: (@Sendable (Double) async -> Void)? = nil) async throws -> (image: URL, video: URL) {
        if let image = Bundle.module.url(forResource: "sample-\(index)", withExtension: "jpg", subdirectory: "LiveSamples"),
           let video = Bundle.module.url(forResource: "sample-\(index)", withExtension: "mov", subdirectory: "LiveSamples") {
            return (image, video)
        }
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JiPin-Live-Samples-v1", isDirectory: true)
        let directory = root.appendingPathComponent("sample-\(index)", isDirectory: true)
        let image = directory.appendingPathComponent("still.jpg"), video = directory.appendingPathComponent("motion.mov")
        if FileManager.default.fileExists(atPath: image.path), FileManager.default.fileExists(atPath: video.path) { return (image, video) }
        let pair = try await renderPair(index: index, progress: progress)
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do { try FileManager.default.moveItem(at: pair.lease.directory, to: directory) }
        catch {
            guard FileManager.default.fileExists(atPath: image.path), FileManager.default.fileExists(atPath: video.path) else { throw error }
        }
        return (image, video)
    }

    private static func renderPair(index: Int, progress: (@Sendable (Double) async -> Void)?) async throws -> LivePhotoExport {
        return try await LivePhotoWriter.write(size: CGSize(width: 720, height: 960), duration: 3, progress: progress) { cg, time in
                cg.scaleBy(x: 2, y: 2)
                let colors = ["#F9DDD9", "#DDECE7", "#E3E1F2"]
                cg.setFillColor(OriginalStickerArt.color(colors[index % colors.count]))
                cg.fill(CGRect(x: 0, y: 0, width: 360, height: 480))
                cg.setFillColor(OriginalStickerArt.color("#FFF8EC"))
                cg.fillEllipse(in: CGRect(x: -40, y: 320, width: 450, height: 240))
                let wave = sin(time * .pi * 2 / 3 + Double(index))
                OriginalStickerArt.draw("cloud", in: CGRect(x: 20 + wave * 35, y: 38, width: 120, height: 100), context: cg)
                OriginalStickerArt.draw(index.isMultiple(of: 2) ? "bunny" : "bear",
                                        in: CGRect(x: 75, y: 170 + wave * 30, width: 210, height: 210), context: cg)
                OriginalStickerArt.draw(index.isMultiple(of: 2) ? "daisy" : "rainbow",
                                        in: CGRect(x: 248, y: 94 - wave * 18, width: 70, height: 80), context: cg)
                cg.setFillColor(OriginalStickerArt.color("#DCA783"))
                for n in 0..<5 { cg.fillEllipse(in: CGRect(x: 32 + n * 68, y: 436, width: 8, height: 8)) }
            }
    }
}
