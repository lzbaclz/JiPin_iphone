import AVFoundation
import ImageIO
import Photos
import UIKit
import XCTest
@testable import JiPinCore

final class LivePhotoQualityTests: XCTestCase {
    private func stripedPhoto(index: Int, clip: LivePhotoClip?) throws -> ImportedPhoto {
        // Fine source detail that cannot survive a 192-pixel-wide movie thumbnail.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1; format.opaque = true; format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: 720, height: 1080), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 720, height: 1080))
            UIColor.black.setFill()
            for x in stride(from: 0, to: 720, by: 4) { context.fill(CGRect(x: x, y: 0, width: 2, height: 1080)) }
        }
        let data = try XCTUnwrap(image.pngData())
        var photo = ImportedPhoto(filename: "detail-\(index)", data: data, pixelSize: image.size, utType: "public.png")
        if var clip { clip.source.id = photo.id; photo.liveClip = clip }
        return photo
    }

    private func fixture() async throws -> (CollageProject, DataAssetLibrary) {
        let size = CGSize(width: 160, height: 240)
        let pair = try await LivePhotoWriter.write(size: size, duration: 1.5) { cg, time in
            cg.setFillColor(UIColor.orange.cgColor); cg.fill(CGRect(origin: .zero, size: size))
            cg.setFillColor(UIColor.blue.cgColor); cg.fill(CGRect(x: time * 60, y: 30, width: 30, height: 180))
        }
        let clip = LivePhotoClip(source: LivePhotoSource(id: UUID(), duration: pair.duration, stillTime: pair.coverTime,
                                                        pixelSize: pair.size, hasAudio: false), url: pair.videoURL, lease: pair.lease)
        let photos = try (0..<5).map { try stripedPhoto(index: $0, clip: $0 < 3 ? clip : nil) }
        var project = ProjectFactory.make(mode: .longStrip, photos: photos)
        project.spacing = 0; project.outerMargin = 0
        project.livePhotoSettings = LivePhotoSettings(duration: 1.5)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                                      motions: Dictionary(uniqueKeysWithValues: photos.compactMap { p in p.liveClip.map { (p.id, $0) } }))
        return (project, assets)
    }

    private func stripeContrast(_ image: CGImage, firstFrame: CGRect) throws -> Double {
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: firstFrame.minX, y: firstFrame.midY, width: 1440, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 1440 * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1440, height: 1, bitsPerComponent: 8,
                                                 bytesPerRow: 1440 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1440, height: 1))
        }
        let contrasts = stride(from: 0, to: 1440, by: 8).map { abs(Double(bytes[($0 + 1) * 4]) - Double(bytes[($0 + 5) * 4])) }
        return contrasts.reduce(0, +) / Double(contrasts.count)
    }

    func testFivePhotoLongStripRetainsOriginalDetailInBothDirections() async throws {
        let (base, assets) = try await fixture()
        for direction in [StripDirection.vertical, .horizontal] {
            var project = base
            project.longStrip?.direction = direction
            let result = try await LivePhotoExporter.render(project: project, assets: assets,
                                                            maxSide: LivePhotoExporter.motionMaxSide(for: project))
            let expected = direction == .vertical ? CGSize(width: 1440, height: 10800) : CGSize(width: 4800, height: 1440)
            let data = try Data(contentsOf: result.imageURL)
            XCTAssertEqual(ImageIOHelpers.pixelSize(of: data), expected)
            XCTAssertEqual(result.photoSize, expected)
            XCTAssertFalse(ImageIOHelpers.containsGPS(data))
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let cover = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            // Compare a full-resolution crop, so an upscaled low-resolution cover cannot pass.
            let first = try XCTUnwrap(CollageRenderer.shared.resolvedFrames(project: project, canvasSize: expected, assets: assets)[project.photoLayers[0].id])
            if direction == .vertical {
                XCTAssertGreaterThan(try stripeContrast(cover, firstFrame: first), 150)
            }
            let movie = try await LivePhotoMedia.inspectMovie(result.videoURL, id: UUID())
            XCTAssertEqual(movie.pixelSize, result.size)
            XCTAssertEqual(result.size, direction == .vertical ? CGSize(width: 512, height: 3840) : CGSize(width: 3738, height: 1120))
            XCTAssertEqual(movie.duration, 1.5, accuracy: 0.05)
            let native = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
            XCTAssertEqual(native.size, expected)
            let attachment = XCTAttachment(contentsOfFile: result.imageURL)
            attachment.name = "full-resolution-\(direction.rawValue).jpg"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }

    func testPreviewStaysSmallAndSavedQualityMatchesSelectedStandard() async throws {
        var (project, assets) = try await fixture()
        project.exportPreference.quality = .standard
        let preview = try await LivePhotoExporter.render(project: project, assets: assets, maxSide: 640, preview: true)
        XCTAssertEqual(preview.photoSize, preview.size)
        XCTAssertEqual(max(preview.size.width, preview.size.height), 640)
        let saved = try await LivePhotoExporter.render(project: project, assets: assets,
                                                       maxSide: LivePhotoExporter.motionMaxSide(for: project))
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: try Data(contentsOf: saved.imageURL)), CGSize(width: 1080, height: 8100))
        XCTAssertEqual(saved.size, CGSize(width: 256, height: 1920))
        XCTAssertNotEqual(saved.photoSize, preview.photoSize)
    }

    func testReportedOddHeightLongStripRetainsFullCoverDimensions() async throws {
        let (project, originalAssets) = try await fixture()
        var assets = originalAssets
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1; format.opaque = true
        let last = UIGraphicsImageRenderer(size: CGSize(width: 1440, height: 215), format: format).image { context in
            UIColor.magenta.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1440, height: 215))
        }
        assets.images[try XCTUnwrap(project.photoOrder.last)] = try XCTUnwrap(last.pngData())
        let result = try await LivePhotoExporter.render(project: project, assets: assets,
                                                        maxSide: LivePhotoExporter.motionMaxSide(for: project))
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: try Data(contentsOf: result.imageURL)), CGSize(width: 1440, height: 8855))
        XCTAssertEqual(result.size, CGSize(width: 624, height: 3840))
        let native = try await LivePhotoMedia.request(imageURL: result.imageURL, videoURL: result.videoURL)
        XCTAssertEqual(native.size, CGSize(width: 1440, height: 8855))
    }

    func testSavedMixedLongStripRetainsHighResolutionAndLiveSubtype() async throws {
        var authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String == "Simulator PhotoKit round-trip test only." {
            authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard authorization == .authorized else {
            throw XCTSkip("This PhotoKit round-trip requires read access granted only to the simulator test host.")
        }
        let (project, assets) = try await fixture()
        let result = try await LivePhotoExporter.render(project: project, assets: assets,
                                                        maxSide: LivePhotoExporter.motionMaxSide(for: project))
        let id = try await LivePhotoLibrary.save(result)
        let saved = try XCTUnwrap(PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject)
        XCTAssertEqual(saved.pixelWidth, 1440)
        XCTAssertEqual(saved.pixelHeight, 10800)
        XCTAssertTrue(saved.mediaSubtypes.contains(.photoLive))
        let native: PHLivePhoto = try await withCheckedThrowingContinuation { continuation in
            let options = PHLivePhotoRequestOptions(); options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestLivePhoto(for: saved, targetSize: PHImageManagerMaximumSize,
                                                      contentMode: .aspectFit, options: options) { live, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                if let live { continuation.resume(returning: live) }
                else { continuation.resume(throwing: LivePhotoError.invalidPair) }
            }
        }
        XCTAssertEqual(native.size, result.photoSize)
    }

    func testExtremeLongStripAndSquareStayWithinPhotoAndVideoBudgets() throws {
        let photos = try (0..<20).map { try stripedPhoto(index: $0, clip: nil) }
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        var project = ProjectFactory.make(mode: .longStrip, photos: photos)
        for direction in [StripDirection.vertical, .horizontal] {
            project.longStrip?.direction = direction
            let size = LivePhotoExporter.photoSize(project: project, assets: assets)
            XCTAssertLessThanOrEqual(max(size.width, size.height), JiPin.Export.maxLongSide)
            XCTAssertLessThanOrEqual(size.width * size.height, JiPin.Export.maxPixelCount)
            let motion = LivePhotoExporter.outputSize(project: project, assets: assets, maxSide: 99999)
            XCTAssertLessThanOrEqual(max(motion.width, motion.height), 3840)
            XCTAssertLessThanOrEqual(motion.width * motion.height, 4_194_304)
        }
        project.mode = .template
        project.canvas = CanvasSpec.presets.first!
        let motion = LivePhotoExporter.outputSize(project: project, assets: assets, maxSide: 99999)
        XCTAssertLessThanOrEqual(motion.width * motion.height, 4_194_304)
    }
}
