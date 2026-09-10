import AVFoundation
import Photos
import UIKit

/// Bridges cancellable callback APIs without double-resuming when cancellation races completion.
final class MediaRequest<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    private var cancellation: (() -> Void)?
    private var cancelled = false
    func register(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation; self.continuation = nil
        lock.unlock(); continuation?.resume(with: result)
    }
    func onCancel(_ action: @escaping () -> Void) {
        lock.lock(); cancellation = action; let run = cancelled; lock.unlock()
        if run { action() }
    }
    func cancel() {
        lock.lock(); cancelled = true; let action = cancellation; lock.unlock()
        finish(.failure(CancellationError())); action?()
    }
}

private final class MediaResourceSink: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: FileHandle?
    private var bytes: Int64 = 0
    let limit: Int64
    init(url: URL, limit: Int64) throws {
        self.limit = limit
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw LivePhotoError.missingResources }
        handle = try FileHandle(forWritingTo: url)
    }
    func append(_ data: Data) throws {
        lock.lock(); defer { lock.unlock() }
        guard let handle else { return }
        bytes += Int64(data.count)
        guard bytes <= limit else { throw LivePhotoError.resourceTooLarge }
        try handle.write(contentsOf: data)
    }
    func close() {
        lock.lock(); defer { lock.unlock() }
        try? handle?.close(); handle = nil
    }
    deinit { close() }
}

public enum LivePhotoMedia {
    public static let stillTimeKey = "com.apple.quicktime.still-image-time"

    public static func importPhoto(_ live: PHLivePhoto, id: UUID = UUID(), name: String = "Live Photo",
                                   maxStillPixels: CGFloat = 16_777_216) async throws -> ImportedPhoto {
        try Task.checkCancellation()
        let resources = PHAssetResource.assetResources(for: live)
        guard let photo = resources.first(where: { $0.type == .fullSizePhoto }) ?? resources.first(where: { $0.type == .photo }),
              let movie = resources.first(where: { $0.type == .fullSizePairedVideo }) ?? resources.first(where: { $0.type == .pairedVideo })
        else { throw LivePhotoError.missingResources }
        let lease = try MediaFileLease.temporary()
        let photoURL = lease.directory.appendingPathComponent("original-photo")
        let movieURL = lease.directory.appendingPathComponent("motion.mov")
        try await writeResource(photo, to: photoURL, limit: 100 * 1024 * 1024)
        try await writeResource(movie, to: movieURL, limit: LivePhotoPolicy.maxMovieBytes)
        try Task.checkCancellation()
        let source = try await inspectMovie(movieURL, id: id)
        guard let data = ImageIOHelpers.sanitizedImageData(from: try Data(contentsOf: photoURL, options: .mappedIfSafe),
                                                          maxLongSide: 8192, maxPixelCount: maxStillPixels) else {
            throw LivePhotoError.missingResources
        }
        try? FileManager.default.removeItem(at: photoURL)
        return ImportedPhoto(id: id, filename: name, data: data, pixelSize: ImageIOHelpers.pixelSize(of: data),
                             utType: ImageIOHelpers.typeIdentifier(of: data), liveClip: LivePhotoClip(source: source, url: movieURL, lease: lease))
    }

    public static func load(from provider: NSItemProvider) async throws -> PHLivePhoto {
        let request = MediaRequest<PHLivePhoto>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.register(continuation)
                let progress = provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                    if let error { request.finish(.failure(error)) }
                    else if let live = object as? PHLivePhoto { request.finish(.success(live)) }
                    else { request.finish(.failure(LivePhotoError.missingResources)) }
                }
                request.onCancel { progress.cancel() }
            }
        } onCancel: { request.cancel() }
    }

    public static func request(imageURL: URL, videoURL: URL, targetSize: CGSize = CGSize(width: 720,height: 720)) async throws -> PHLivePhoto {
        let request = MediaRequest<PHLivePhoto>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.register(continuation)
                let token = PHLivePhoto.request(withResourceFileURLs: [imageURL, videoURL], placeholderImage: nil,
                                                targetSize: targetSize, contentMode: .aspectFit) { live, info in
                    if let error = info[PHLivePhotoInfoErrorKey] as? Error { request.finish(.failure(error)); return }
                    if (info[PHLivePhotoInfoCancelledKey] as? Bool) == true { request.finish(.failure(CancellationError())); return }
                    if (info[PHLivePhotoInfoIsDegradedKey] as? Bool) == true { return }
                    if let live { request.finish(.success(live)) }
                    else { request.finish(.failure(LivePhotoError.invalidPair)) }
                }
                request.onCancel { PHLivePhoto.cancelRequest(withRequestID: token) }
            }
        } onCancel: { request.cancel() }
    }

    private static func writeResource(_ resource: PHAssetResource, to url: URL, limit: Int64) async throws {
        let sink = try MediaResourceSink(url: url, limit: limit)
        let request = MediaRequest<Void>()
        let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = true
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.register(continuation)
                let token = PHAssetResourceManager.default().requestData(for: resource, options: options) { data in
                    do { try sink.append(data) }
                    catch { sink.close(); request.finish(.failure(error)); request.cancel() }
                } completionHandler: { error in
                    sink.close()
                    if let error { request.finish(.failure(error)) } else { request.finish(.success(())) }
                }
                request.onCancel { sink.close(); PHAssetResourceManager.default().cancelDataRequest(token) }
            }
        } onCancel: { request.cancel() }
        try Task.checkCancellation()
    }

    public static func inspectMovie(_ url: URL, id: UUID) async throws -> LivePhotoSource {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration >= 0.1, duration <= 60,
              let track = try await asset.loadTracks(withMediaType: .video).first else { throw LivePhotoError.invalidVideo }
        let natural = try await track.load(.naturalSize), transform = try await track.load(.preferredTransform)
        let frame = CGRect(origin: .zero, size: natural).applying(transform).standardized
        guard frame.width >= 2, frame.height >= 2 else { throw LivePhotoError.invalidVideo }
        let still = try await stillImageTime(in: asset) ?? duration / 2
        let audio = try await asset.loadTracks(withMediaType: .audio)
        return LivePhotoSource(id: id, duration: duration, stillTime: min(max(still, 0), duration), pixelSize: frame.size, hasAudio: !audio.isEmpty)
    }

    public static func stillImageTime(in asset: AVAsset) async throws -> Double? {
        for track in try await asset.loadTracks(withMediaType: .metadata) {
            try Task.checkCancellation()
            let descriptions = try await track.load(.formatDescriptions)
            let identifiers = descriptions.flatMap { CMMetadataFormatDescriptionGetIdentifiers($0) as? [String] ?? [] }
            guard identifiers.contains(where: { $0.contains(stillTimeKey) }) else { continue }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            guard reader.canAdd(output) else { continue }
            reader.add(output)
            let adaptor = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: output)
            guard reader.startReading() else { continue }
            defer { reader.cancelReading() }
            while let group = adaptor.nextTimedMetadataGroup() {
                if group.items.contains(where: { ($0.key as? String) == stillTimeKey || $0.identifier?.rawValue.contains(stillTimeKey) == true }) {
                    let time = group.timeRange.start.seconds
                    if time.isFinite { return time }
                }
            }
        }
        return nil
    }
}
