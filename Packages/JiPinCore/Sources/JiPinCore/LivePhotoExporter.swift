@preconcurrency import AVFoundation
import CoreImage
import Photos
import UIKit

/// A still frame anchors every source to the middle of the output. Short clips hold their end frames.
public enum LivePhotoTimeline {
    public static func sourceTime(outputTime: Double, coverTime: Double, source: LivePhotoSource) -> Double {
        min(max(source.stillTime + outputTime - coverTime, 0), max(source.duration - 1 / 600, 0))
    }
}

/// Decodes forward, keeping at most two sample buffers per source; never expands an entire movie into RAM.
private final class LiveFrameReader {
    private let reader: AVAssetReader
    private let output: AVAssetReaderVideoCompositionOutput
    private let context: CIContext
    private var current: CMSampleBuffer?
    private var next: CMSampleBuffer?
    private var cached: CGImage?

    init(clip: LivePhotoClip, maxSide: CGFloat, coverTime: Double, duration: Double, context: CIContext) async throws {
        self.context = context
        let asset = AVURLAsset(url: clip.url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw LivePhotoError.invalidVideo }
        let natural = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
        let bounds = CGRect(origin: .zero, size: natural).applying(transform).standardized
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width >= 2, bounds.height >= 2 else { throw LivePhotoError.invalidVideo }
        let scale = min(1, maxSide / max(bounds.width, bounds.height))
        let size = CGSize(width: max(2, floor(bounds.width * scale / 2) * 2), height: max(2, floor(bounds.height * scale / 2) * 2))
        let composition = AVMutableVideoComposition()
        composition.renderSize = size
        composition.frameDuration = CMTime(value: 1, timescale: LivePhotoPolicy.frameRate)
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(transform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: size.width / bounds.width, y: size.height / bounds.height)), at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = try await track.load(.timeRange)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]
        reader = try AVAssetReader(asset: asset)
        output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.videoComposition = composition
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw LivePhotoError.decodeFailed }
        reader.add(output)
        let start = LivePhotoTimeline.sourceTime(outputTime: 0, coverTime: coverTime, source: clip.source)
        let end = min(clip.source.duration, max(start + 1 / 30, clip.source.stillTime + duration - coverTime))
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                      end: CMTime(seconds: end, preferredTimescale: 600))
        guard reader.startReading() else { throw reader.error ?? LivePhotoError.decodeFailed }
        current = output.copyNextSampleBuffer()
        next = output.copyNextSampleBuffer()
        guard current != nil else { throw reader.error ?? LivePhotoError.decodeFailed }
    }

    deinit { reader.cancelReading() }

    func frame(at seconds: Double) throws -> CGImage {
        try Task.checkCancellation()
        while let upcoming = next, CMSampleBufferGetPresentationTimeStamp(upcoming).seconds <= seconds + 0.0001 {
            current = upcoming
            next = output.copyNextSampleBuffer()
            cached = nil
        }
        guard reader.status != .failed, reader.status != .cancelled else { throw reader.error ?? LivePhotoError.decodeFailed }
        if let cached { return cached }
        guard let current, let buffer = CMSampleBufferGetImageBuffer(current) else { throw LivePhotoError.decodeFailed }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else {
            throw LivePhotoError.decodeFailed
        }
        cached = cg
        return cg
    }
}

private final class LiveFrameAssets: AssetProviding {
    let library: DataAssetLibrary
    var frames: [UUID: CGImage] = [:]
    private var stills: [UUID: (requestedSide: CGFloat, image: CGImage)] = [:]
    let maxSide: CGFloat
    init(library: DataAssetLibrary, maxSide: CGFloat) { self.library = library; self.maxSide = maxSide }
    func imageData(for id: UUID) -> Data? { library.images[id] }
    func decodedImage(for id: UUID, maxLongSide: CGFloat) -> CGImage? {
        if let frame = frames[id] { return frame }
        let requestedSide = min(maxLongSide, maxSide)
        if let still = stills[id], still.requestedSide >= requestedSide { return still.image }
        let image = library.decodedImage(for: id, maxLongSide: requestedSide)
        if let image { stills[id] = (requestedSide, image) }
        return image
    }
}

public enum LivePhotoExporter {
    public static func outputSize(project: CollageProject, assets: DataAssetLibrary, maxSide: CGFloat = 1080) -> CGSize {
        let dimensions: CGSize
        switch ExportGeometry.outputSize(for: project, assets: assets) {
        case .ok(let size), .needsChoice(_, let size): dimensions = size
        }
        let scale = min(max(maxSide, 2), 1440) / max(dimensions.width, dimensions.height, 1)
        return CGSize(width: max(2, floor(dimensions.width * scale / 2) * 2), height: max(2, floor(dimensions.height * scale / 2) * 2))
    }

    /// Run from a detached task; this is CPU/video work and must not run on the UI actor.
    public static func render(project: CollageProject, assets: DataAssetLibrary, maxSide: CGFloat = 1080,
                              progress: (@Sendable (Double) async -> Void)? = nil) async throws -> LivePhotoExport {
        try Task.checkCancellation()
        let sources = project.resolvedLiveSources
        guard !sources.isEmpty else { throw LivePhotoError.noLivePhotos }
        guard sources.count <= LivePhotoPolicy.maxSources else { throw LivePhotoError.tooManySources }
        let settings = project.livePhotoSettings ?? LivePhotoSettings()
        let size = outputSize(project: project, assets: assets, maxSide: maxSide)
        let frameAssets = LiveFrameAssets(library: assets, maxSide: max(size.width, size.height))
        for id in project.photoOrder {
            guard let data = assets.images[id], ImageIOHelpers.pixelSize(of: data) != .zero else { throw DraftStoreError.missingAssets }
        }
        let context = CIContext(options: [.cacheIntermediates: false])
        defer { context.clearCaches() }
        // Bound simultaneous decoded source pixels even for nine overlapping full-canvas layers.
        let decodeSide = min(max(size.width, size.height), sqrt(4_194_304 / CGFloat(sources.count)))
        var readers: [UUID: LiveFrameReader] = [:]
        var clips: [UUID: LivePhotoClip] = [:]
        var prepared: [UUID: LivePhotoClip] = [:]
        for (index, source) in sources.enumerated() {
            try Task.checkCancellation()
            guard var clip = assets.motions[source.id], FileManager.default.fileExists(atPath: clip.url.path) else { throw LivePhotoError.missingResources }
            // Inspect bytes again: a stale or damaged draft cannot dictate decoder timing.
            clip.source = try await LivePhotoMedia.inspectMovie(clip.url, id: source.id)
            // Compositor renderSize bounds its OUTPUT, not the source decoder's surfaces. Reduce large
            // movies one at a time before opening multiple readers, so nine camera clips don't allocate
            // nine sets of full-resolution decoder buffers. These work files are deleted with their leases.
            let input: LivePhotoClip
            if sources.count > 1, max(clip.source.pixelSize.width, clip.source.pixelSize.height) > decodeSide * 1.5 {
                input = try await reducedClip(clip, maxSide: decodeSide, settings: settings, context: context)
            } else { input = clip }
            prepared[source.id] = input
            readers[source.id] = try await LiveFrameReader(clip: input, maxSide: decodeSide, coverTime: settings.coverTime,
                                                         duration: settings.safeDuration, context: context)
            clips[source.id] = clip
            await progress?(Double(index + 1) / Double(sources.count) * 0.25)
        }
        var opaque = project
        opaque.exportPreference.format = .jpeg
        opaque.exportPreference.transparentBackground = false
        let result = try await LivePhotoWriter.write(size: size, duration: settings.safeDuration, progress: { value in
            await progress?(0.25 + value * 0.63)
        }) { context, time in
            for (id, reader) in readers {
                guard let clip = prepared[id] else { throw LivePhotoError.missingResources }
                frameAssets.frames[id] = try reader.frame(at: LivePhotoTimeline.sourceTime(outputTime: time, coverTime: settings.coverTime, source: clip.source))
            }
            CollageRenderer.shared.draw(project: opaque, assets: frameAssets, canvasSize: size, preview: false, in: context)
        }
        readers.removeAll(); frameAssets.frames.removeAll(); prepared.removeAll()
        if let audioID = settings.audioSourceID {
            guard let clip = clips[audioID], clip.source.hasAudio else { throw LivePhotoError.missingResources }
            try await attachAudio(from: clip, to: result)
        }
        await progress?(0.94)
        // Apple's own parser is the final gate. Never save an ordinary movie labelled as Live.
        _ = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL, targetSize: CGSize(width: 240, height: 240))
        try Task.checkCancellation()
        await progress?(1)
        return result
    }

    private static func reducedClip(_ clip: LivePhotoClip, maxSide: CGFloat, settings: LivePhotoSettings, context: CIContext) async throws -> LivePhotoClip {
        let reader = try await LiveFrameReader(clip: clip, maxSide: maxSide, coverTime: settings.coverTime,
                                               duration: settings.safeDuration, context: context)
        let factor = maxSide / max(clip.source.pixelSize.width, clip.source.pixelSize.height)
        let size = CGSize(width: max(2, floor(clip.source.pixelSize.width * factor / 2) * 2),
                          height: max(2, floor(clip.source.pixelSize.height * factor / 2) * 2))
        let pair = try await LivePhotoWriter.write(size: size, duration: settings.safeDuration) { _, time in
            let image = try reader.frame(at: LivePhotoTimeline.sourceTime(outputTime: time, coverTime: settings.coverTime, source: clip.source))
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        let source = LivePhotoSource(id: clip.source.id, duration: pair.duration, stillTime: pair.coverTime, pixelSize: pair.size, hasAudio: false)
        return LivePhotoClip(source: source, url: pair.videoURL, lease: pair.lease)
    }

    static func attachAudio(from clip: LivePhotoClip, to result: LivePhotoExport) async throws {
        let composition = AVMutableComposition()
        let base = AVURLAsset(url: result.videoURL)
        let full = CMTimeRange(start: .zero, duration: CMTime(seconds: result.duration, preferredTimescale: 600))
        for type in [AVMediaType.video, .metadata] {
            for track in try await base.loadTracks(withMediaType: type) {
                guard let target = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw LivePhotoError.encodingFailed }
                let range = CMTimeRangeGetIntersection(try await track.load(.timeRange), otherRange: full)
                try target.insertTimeRange(range, of: track, at: range.start)
                if type == .video { target.preferredTransform = try await track.load(.preferredTransform) }
            }
        }
        let source = AVURLAsset(url: clip.url)
        guard let audio = try await source.loadTracks(withMediaType: .audio).first,
              let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw LivePhotoError.missingResources }
        let offset = clip.source.stillTime - result.coverTime
        let desired = CMTimeRange(start: CMTime(seconds: max(offset, 0), preferredTimescale: 600),
                                  end: CMTime(seconds: min(clip.source.duration, result.duration + offset), preferredTimescale: 600))
        let range = CMTimeRangeGetIntersection(try await audio.load(.timeRange), otherRange: desired)
        if range.duration.seconds > 0 {
            try target.insertTimeRange(range, of: audio, at: CMTime(seconds: max(range.start.seconds - offset, 0), preferredTimescale: 600))
        }
        let outputURL = result.lease.directory.appendingPathComponent("with-audio.mov")
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else { throw LivePhotoError.encodingFailed }
        exporter.outputURL = outputURL; exporter.outputFileType = .mov; exporter.timeRange = full
        exporter.metadata = [LivePhotoWriter.contentIdentifier(result.identifier)]
        final class CancellableExport: @unchecked Sendable {
            let session: AVAssetExportSession
            init(_ session: AVAssetExportSession) { self.session = session }
        }
        let cancellation = CancellableExport(exporter)
        await withTaskCancellationHandler { await exporter.export() } onCancel: { cancellation.session.cancelExport() }
        try Task.checkCancellation()
        guard exporter.status == .completed else { throw exporter.error ?? LivePhotoError.encodingFailed }
        _ = try FileManager.default.replaceItemAt(result.videoURL, withItemAt: outputURL)
    }
}

public enum LivePhotoLibrary {
    /// Adds the two resources in one PhotoKit transaction; requests only permission to add photos.
    @discardableResult public static func save(_ result: LivePhotoExport) async throws -> String {
        try Task.checkCancellation()
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw LivePhotoError.photoPermission }
        final class Created: @unchecked Sendable { var id = "" }
        let created = Created()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: result.imageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: result.videoURL, options: nil)
            created.id = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        }
        return created.id
    }
}
