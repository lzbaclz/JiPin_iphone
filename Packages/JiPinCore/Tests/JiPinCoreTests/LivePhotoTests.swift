import AVFoundation
import ImageIO
import Photos
import UIKit
import XCTest
@testable import JiPinCore

final class LivePhotoTests: XCTestCase {
    private func fixture(color: UIColor = .red, duration: Double = 1.5, size: CGSize = CGSize(width: 160, height: 240)) async throws -> ImportedPhoto {
        let pair = try await LivePhotoWriter.write(size: size, duration: duration) { cg, time in
            cg.scaleBy(x: size.width / 160, y: size.height / 240)
            cg.setFillColor(color.cgColor); cg.fill(CGRect(x: 0, y: 0, width: 160, height: 240))
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(x: 10 + time * 80, y: 40, width: 30, height: 150))
        }
        let live = try await LivePhotoMedia.request(imageURL: pair.imageURL, videoURL: pair.videoURL)
        return try await LivePhotoMedia.importPhoto(live)
    }

    private func movieFrame(_ url: URL, at seconds: Double) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(value: Int64((seconds * 600).rounded()), timescale: 600)).image
    }

    private func difference(_ a: CGImage, _ b: CGImage, region: CGRect? = nil) throws -> Double {
        let rect = region ?? CGRect(x: 0, y: 0, width: a.width, height: a.height)
        let first = try XCTUnwrap(a.cropping(to: rect)), second = try XCTUnwrap(b.cropping(to: rect))
        func bytes(_ image: CGImage) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
            bytes.withUnsafeMutableBytes { buffer in
                let cg = CGContext(data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                cg.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            }
            return bytes
        }
        return zip(bytes(first), bytes(second)).map { abs(Double($0) - Double($1)) }.reduce(0, +) / 4096
    }

    func testLiveResourceImportRoundTripAndMixedCollageMovesOnlyLiveCell() async throws {
        let photo = try await fixture()
        XCTAssertNotNil(photo.liveClip)
        XCTAssertFalse(ImageIOHelpers.containsGPS(photo.data))
        let still = ImportedPhoto(filename: "still", data: photo.data, pixelSize: photo.pixelSize, utType: photo.utType)
        var project = ProjectFactory.make(mode: .template, photos: [photo, still])
        project.spacing = 0; project.outerMargin = 0
        project.livePhotoSettings = LivePhotoSettings(duration: 1.5)
        let assets = DataAssetLibrary(images: [photo.id: photo.data, still.id: still.data], motions: [photo.id: try XCTUnwrap(photo.liveClip)])
        let result = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 320)
        let first = try await movieFrame(result.videoURL, at: 0.1), last = try await movieFrame(result.videoURL, at: 1.3)
        let frames = CollageRenderer.shared.resolvedFrames(project: project, canvasSize: result.size, assets: assets)
        let moving = try XCTUnwrap(frames[project.photoLayers[0].id]).insetBy(dx: 3, dy: 3)
        let frozen = try XCTUnwrap(frames[project.photoLayers[1].id]).insetBy(dx: 3, dy: 3)
        XCTAssertGreaterThan(try difference(first, last, region: moving), 8)
        XCTAssertLessThan(try difference(first, last, region: frozen), 2)
        let cover = try XCTUnwrap(ImageIOHelpers.thumbnail(from: Data(contentsOf: result.imageURL), maxLongSide: 320))
        let middle = try await movieFrame(result.videoURL, at: result.coverTime)
        for (name, image) in [("live-cover", cover), ("live-middle", middle)] {
            let attachment = XCTAttachment(image: UIImage(cgImage: image)); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertLessThan(try difference(cover, middle), 4, "封面必须匹配中间帧，且方向一致")
    }

    func testMultipleLiveSourcesWorkAcrossAllModesWithDecorations() async throws {
        let photos = [try await fixture(), try await fixture(color: .blue)]
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                      motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
        for mode in CollageMode.allCases {
            var project = ProjectFactory.make(mode: mode, photos: photos)
            project.livePhotoSettings = LivePhotoSettings(duration: 1.5)
            project.objects[0].photo?.crop.left = 0.1
            project.objects[0].transform.rotation = 12
            project.objects[0].photo?.filterID = FilterCatalog.all[0].id
            project.decorationFrame = CanvasDecoration(frameID: DecorationFrameCatalog.all[0].id, width: 0.06)
            project.objects.append(LayerObject(kind: .sticker, zIndex: 80, transform: CanvasTransform(centerX: 0.8, centerY: 0.8, width: 0.18, height: 0.18), sticker: StickerPayload(stickerID: "cute-bunny")))
            let result = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 240)
            let live = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
            XCTAssertEqual(live.size, result.size, mode.rawValue)
            let first = try await movieFrame(result.videoURL, at: 0.1), last = try await movieFrame(result.videoURL, at: 1.3)
            XCTAssertGreaterThan(try difference(first, last), 3, mode.rawValue)
        }
    }

    func testTimelineAlignsCoverAndHoldsShortClips() {
        let source = LivePhotoSource(id: UUID(), duration: 1.5, stillTime: 0.5, pixelSize: CGSize(width: 160, height: 240), hasAudio: false)
        XCTAssertEqual(LivePhotoTimeline.sourceTime(outputTime: 0, coverTime: 1.5, source: source), 0)
        XCTAssertEqual(LivePhotoTimeline.sourceTime(outputTime: 1.5, coverTime: 1.5, source: source), 0.5)
        XCTAssertEqual(LivePhotoTimeline.sourceTime(outputTime: 3, coverTime: 1.5, source: source), 1.5 - 1 / 600, accuracy: 0.0001)
        XCTAssertEqual(LivePhotoSettings(duration: .nan).safeDuration, 3)
    }

    func testAudioRemainsInNativeLivePairAndMutedOutputDropsIt() async throws {
        let pair = try await LivePhotoWriter.write(size: CGSize(width: 160, height: 240), duration: 1.5) { cg, _ in
            cg.setFillColor(UIColor.orange.cgColor); cg.fill(CGRect(x: 0, y: 0, width: 160, height: 240))
        }
        let audioURL = pair.lease.directory.appendingPathComponent("tone.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 66_150)!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 440 * 2 * .pi / 44_100) * 0.1) }
        do {
            let file = try AVAudioFile(forWriting: audioURL, settings: format.settings)
            try file.write(from: buffer)
        }
        let audio = LivePhotoClip(source: LivePhotoSource(id: UUID(), duration: 1.5, stillTime: pair.coverTime, pixelSize: pair.size, hasAudio: true), url: audioURL, lease: pair.lease)
        try await LivePhotoExporter.attachAudio(from: audio, to: pair)
        let live = try await LivePhotoMedia.request(imageURL: pair.imageURL, videoURL: pair.videoURL)
        let photo = try await LivePhotoMedia.importPhoto(live)
        XCTAssertTrue(try XCTUnwrap(photo.liveClip).source.hasAudio)
        let assets = DataAssetLibrary(images: [photo.id: photo.data], motions: [photo.id: photo.liveClip!])
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.livePhotoSettings = LivePhotoSettings(duration: 1.5, audioSourceID: photo.id)
        let result = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 240)
        let tracks = try await AVURLAsset(url: result.videoURL).loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 1)
        project.livePhotoSettings?.audioSourceID = nil
        let muted = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 240)
        let mutedTracks = try await AVURLAsset(url: muted.videoURL).loadTracks(withMediaType: .audio)
        XCTAssertTrue(mutedTracks.isEmpty)
    }

    @MainActor func testDraftReopenModeCopyAndUndoRetainMotionAfterGarbageCollection() async throws {
        let photos = [try await fixture(), try await fixture(color: .blue)]
        let root = try MediaFileLease.temporary(prefix: "Live-Draft-Test")
        let store = DraftStore(overridesContainer: root.directory)
        let session = EditorSession(project: ProjectFactory.make(mode: .freeform, photos: photos), assets: AssetLibrary(photos: photos), store: store, autosaves: false)
        let saved = await session.persistNow(); XCTAssertTrue(saved)
        let loaded = try store.load(id: session.project.id)
        XCTAssertEqual(loaded.motions.count, 2)
        let copy = ProjectFactory.copy(project: loaded.project, to: .template, photos: photos)
        XCTAssertEqual(copy.resolvedLiveSources.count, 2)
        let reopened = EditorSession(project: loaded.project, assets: AssetLibrary(images: loaded.assets, motions: loaded.motions), store: store, autosaves: false)
        reopened.select(reopened.project.photoLayers[0].id)
        reopened.removeSelectedPhoto()
        let savedRemoval = await reopened.persistNow(); XCTAssertTrue(savedRemoval)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.motionFile(id: photos[0].id).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: loaded.motions[photos[0].id]!.url.path))
        reopened.undoLast()
        XCTAssertEqual(reopened.project.resolvedLiveSources.count, 2)
        let savedUndo = await reopened.persistNow(); XCTAssertTrue(savedUndo)
        XCTAssertEqual(try store.load(id: reopened.project.id).motions.count, 2)
    }

    func testMissingMotionAndWriteFailureNeverOverwriteSavedDraft() async throws {
        let photo = try await fixture()
        let root = try MediaFileLease.temporary(prefix: "Live-Atomic-Test")
        let store = DraftStore(overridesContainer: root.directory)
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        try store.save(project: project, assets: [photo.id: photo.data], thumbnailJPEG: nil, motions: [photo.id: photo.liveClip!])
        let failing = DraftStore(overridesContainer: root.directory, commit: { _, _ in throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)) })
        let originalName = project.name; project.name = "失败的修改"
        XCTAssertThrowsError(try failing.save(project: project, assets: [photo.id: photo.data], thumbnailJPEG: nil, motions: [photo.id: photo.liveClip!]))
        XCTAssertEqual(try store.load(id: project.id).project.name, originalName)
        let other = try await fixture(color: .blue)
        XCTAssertThrowsError(try store.save(project: project, assets: [photo.id: photo.data], thumbnailJPEG: nil, motions: [photo.id: other.liveClip!])) {
            XCTAssertEqual($0 as? DraftStoreError, .conflictingAsset)
        }
        try FileManager.default.removeItem(at: store.motionFile(id: photo.id))
        XCTAssertThrowsError(try store.save(project: project, assets: [photo.id: photo.data], thumbnailJPEG: nil))
        let loaded = try store.load(id: project.id)
        XCTAssertEqual(loaded.project.name, originalName)
        XCTAssertTrue(loaded.motions.isEmpty)
        XCTAssertTrue(loaded.project.hasLivePhotos)
    }

    func testV3DraftDecodesWithoutLiveFields() throws {
        var old = CollageProject(name: "旧草稿", mode: .freeform)
        old.schemaVersion = 3
        let bytes = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(CollageProject.self, from: bytes)
        XCTAssertFalse(decoded.hasLivePhotos)
        XCTAssertNil(decoded.livePhotoSettings)
    }

    func testCancelledWriterRemovesTemporaryPair() async throws {
        let task = Task {
            try await LivePhotoWriter.write(size: CGSize(width: 720, height: 960), duration: 3) { _, _ in }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("取消后不应返回成功文件") }
        catch is CancellationError { }
    }

    func testNativePhotoLibraryStoresAndReloadsLiveSubtype() async throws {
        // Dedicated simulator verification grants read access to the TEST HOST via simctl.
        // The shipping app only requests .addOnly and never calls the read authorization API.
        var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String == "Simulator PhotoKit round-trip test only." {
            authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard authorization == .authorized else {
            throw XCTSkip("Dedicated PhotoKit check: bundle=\(Bundle.main.bundleIdentifier ?? "nil"), photos=\(authorization.rawValue). Grant test-host permissions before running.")
        }
        let photo = try await fixture()
        let project = ProjectFactory.make(mode: .freeform, photos: [photo])
        let result = try await LivePhotoExporter.render(project: project, assets: DataAssetLibrary(images: [photo.id: photo.data], motions: [photo.id: photo.liveClip!]), maxSide: 320)
        let id = try await LivePhotoLibrary.save(result)
        let asset = try XCTUnwrap(PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject)
        XCTAssertTrue(asset.mediaSubtypes.contains(.photoLive))
        let resources = PHAssetResource.assetResources(for: asset)
        XCTAssertTrue(resources.contains { $0.type == .photo })
        XCTAssertTrue(resources.contains { $0.type == .pairedVideo })
        let native: PHLivePhoto = try await withCheckedThrowingContinuation { continuation in
            let options = PHLivePhotoRequestOptions(); options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestLivePhoto(for: asset, targetSize: CGSize(width: 320, height: 320), contentMode: .aspectFit, options: options) { live, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                if let live { continuation.resume(returning: live) }
                else { continuation.resume(throwing: LivePhotoError.invalidPair) }
            }
        }
        XCTAssertEqual(native.size, result.size)
    }

    func testNineLiveSourcesRenderAndTenthIsRejected() async throws {
        let base = try await fixture()
        let photos = (0..<10).map { _ -> ImportedPhoto in
            var photo = base; photo.id = UUID(); photo.liveClip?.source.id = photo.id
            return photo
        }
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                      motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
        var nine = ProjectFactory.make(mode: .template, photos: Array(photos.prefix(9)))
        nine.livePhotoSettings = LivePhotoSettings(duration: 1.5)
        let result = try await LivePhotoExporter.render(project: nine, assets: assets, maxSide: 1080)
        XCTAssertEqual(max(result.size.width, result.size.height), 1080)
        let ten = ProjectFactory.make(mode: .template, photos: photos)
        do { _ = try await LivePhotoExporter.render(project: ten, assets: assets, maxSide: 320); XCTFail("最多九个动态来源") }
        catch LivePhotoError.tooManySources { }
    }

    func testLargeInputsUseBoundedPreparationAndRetainMovement() async throws {
        let photos = [try await fixture(size: CGSize(width: 1080, height: 1440)), try await fixture(color: .blue, size: CGSize(width: 1080, height: 1440))]
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.livePhotoSettings = LivePhotoSettings(duration: 1.5)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                      motions: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.liveClip!) }))
        let result = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 320)
        let first = try await movieFrame(result.videoURL, at: 0.1), last = try await movieFrame(result.videoURL, at: 1.3)
        XCTAssertGreaterThan(try difference(first, last), 8)
        XCTAssertTrue(photos.allSatisfy { FileManager.default.fileExists(atPath: $0.liveClip!.url.path) })
    }

    func testPortraitCameraTrackTransformMatchesStaticPreviewOrientation() async throws {
        var photo = try await fixture()
        let original = try XCTUnwrap(photo.liveClip)
        let source = AVURLAsset(url: original.url)
        let composition = AVMutableComposition()
        let tracks = try await source.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let target = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        try target.insertTimeRange(try await track.load(.timeRange), of: track, at: .zero)
        target.preferredTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
        let lease = try MediaFileLease.temporary(prefix: "Live-Rotated-Test")
        let url = lease.directory.appendingPathComponent("portrait.mov")
        let export = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        export.outputURL = url; export.outputFileType = .mov
        await export.export()
        XCTAssertEqual(export.status, .completed)
        var metadata = try await LivePhotoMedia.inspectMovie(url, id: photo.id)
        XCTAssertEqual(metadata.pixelSize, CGSize(width: 240, height: 160))
        metadata.stillTime = original.source.stillTime
        let cg = try XCTUnwrap(ImageIOHelpers.thumbnail(from: photo.data, maxLongSide: 240))
        photo.data = try XCTUnwrap(ImageIOHelpers.sanitizedImageData(from: UIImage(cgImage: cg, scale: 1, orientation: .right)))
        photo.pixelSize = ImageIOHelpers.pixelSize(of: photo.data)
        photo.liveClip = LivePhotoClip(source: metadata, url: url, lease: lease)
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.livePhotoSettings = LivePhotoSettings(duration: 1.5)
        let assets = DataAssetLibrary(images: [photo.id: photo.data], motions: [photo.id: photo.liveClip!])
        let result = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 320)
        let reference = try XCTUnwrap(CollageRenderer.shared.render(project: project, assets: assets, canvasSize: result.size, preview: false).cgImage)
        let middle = try await movieFrame(result.videoURL, at: result.coverTime)
        XCTAssertLessThan(try difference(reference, middle), 5, "方向标记必须烘焙进每个视频帧")
    }

    func testCancellationDuringEncodingCleansIncompleteFiles() async throws {
        func files() throws -> Set<String> {
            Set(try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path).filter { $0.hasPrefix("JiPin-Live-Export-") })
        }
        let before = try files()
        let started = expectation(description: "writer has made frames")
        started.assertForOverFulfill = false
        let task = Task {
            try await LivePhotoWriter.write(size: CGSize(width: 720, height: 960), duration: 3, progress: { _ in
                started.fulfill()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }) { _, _ in }
        }
        await fulfillment(of: [started], timeout: 10)
        task.cancel()
        do { _ = try await task.value; XCTFail("取消后不能留下半成品") }
        catch is CancellationError { }
        XCTAssertEqual(try files(), before)
    }

    @MainActor func testLostMotionBlocksLiveButStillCoverCanBeExported() async throws {
        let photo = try await fixture()
        let session = EditorSession(project: ProjectFactory.make(mode: .freeform, photos: [photo]), assets: AssetLibrary(images: [photo.id: photo.data]), autosaves: false)
        XCTAssertFalse(session.missingAssetWarning)
        XCTAssertTrue(session.missingLiveAssetWarning)
        XCTAssertNotNil(CollageRenderer.shared.jpegData(project: session.project, assets: session.assets.snapshot, canvasSize: CGSize(width: 240, height: 240)))
        do { _ = try await LivePhotoExporter.render(project: session.project, assets: session.assets.snapshot, maxSide: 240); XCTFail("不能把缺失的 Live 静默当静态导出") }
        catch LivePhotoError.missingResources { }
    }

    func testGeneratedPairIsRecognizedByNativePhotoKit() async throws {
        let result = try await LivePhotoWriter.write(size: CGSize(width: 240, height: 320), duration: 1.5) { cg, time in
            cg.setFillColor(UIColor.systemTeal.cgColor); cg.fill(CGRect(x: 0,y: 0,width: 240,height: 320))
            cg.setFillColor(UIColor.systemYellow.cgColor)
            cg.fillEllipse(in: CGRect(x: 20 + time * 100,y: 120,width: 50,height: 50))
        }
        let live = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
        XCTAssertEqual(live.size, CGSize(width: 240,height: 320))
        let data = try Data(contentsOf: result.imageURL)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        XCTAssertEqual((props[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])?["17"] as? String, result.identifier)
        XCTAssertFalse(ImageIOHelpers.containsGPS(data))
        let asset = AVURLAsset(url: result.videoURL)
        let metadata = try await asset.load(.metadata)
        let identifier = try await metadata.first(where: { $0.identifier == .quickTimeMetadataContentIdentifier })?.load(.stringValue)
        XCTAssertEqual(identifier, result.identifier)
        let time = try await LivePhotoMedia.stillImageTime(in: asset)
        XCTAssertEqual(try XCTUnwrap(time), result.coverTime, accuracy: 0.001)
    }
}
