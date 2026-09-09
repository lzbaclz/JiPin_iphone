import ImageIO
import UIKit
import XCTest
import JiPinCore

final class RenderExportTests: XCTestCase {
    func testFourModesExportWithoutGPSAndWithExpectedSize() {
        let photos = makePhotos(4)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))

        let template = ProjectFactory.make(mode: .template, photos: photos)
        assertExport(template, assets: assets, quality: .standard)

        var freeform = ProjectFactory.make(mode: .freeform, photos: photos)
        freeform.objects.append(
            LayerObject(
                kind: .text,
                zIndex: 50,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.12, width: 0.8, height: 0.1),
                text: TextPayload(text: "极拼 Hello 🎉")
            )
        )
        assertExport(freeform, assets: assets, quality: .standard)

        let posterPhotos = Array(photos.prefix(3))
        let poster = ProjectFactory.make(mode: .poster, photos: posterPhotos)
        assertExport(poster, assets: assets, quality: .hd)

        let strip = ProjectFactory.make(mode: .longStrip, photos: photos)
        assertExport(strip, assets: assets, quality: .standard)
    }

    func testImportStripsGPSAndExportDoesNotCopyIt() {
        let image = solidImage(color: .red, size: CGSize(width: 400, height: 600))
        guard let gpsJPEG = ImageIOHelpers.jpegWithGPS(from: image) else {
            return XCTFail("could not write GPS jpeg")
        }
        XCTAssertTrue(ImageIOHelpers.containsGPS(gpsJPEG))
        guard let stripped = ImageIOHelpers.strippedJPEG(from: gpsJPEG, quality: 0.9) else {
            return XCTFail("strip failed")
        }
        XCTAssertFalse(ImageIOHelpers.containsGPS(stripped))

        let photo = ImportedPhoto(filename: "gps.jpg", data: stripped, pixelSize: CGSize(width: 400, height: 600), utType: "public.jpeg")
        let project = ProjectFactory.make(mode: .template, photos: [photo, photo])
        let assets = DataAssetLibrary(images: [photo.id: stripped])
        guard case .ok(let size) = ExportGeometry.outputSize(for: project, assets: assets),
              let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size)
        else {
            return XCTFail("export failed")
        }
        XCTAssertFalse(ImageIOHelpers.containsGPS(data))
    }

    func testThirtyDraftsDoNotOverwriteAndCanDuplicateDelete() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(overridesContainer: root)
        try store.prepare()
        var ids: [UUID] = []
        for i in 0..<30 {
            let photos = makePhotos(2)
            var project = ProjectFactory.make(mode: .template, photos: photos)
            project.name = "草稿 \(i)"
            try store.save(
                project: project,
                assets: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
                thumbnailJPEG: nil
            )
            ids.append(project.id)
        }
        let listed = store.listDrafts()
        XCTAssertEqual(listed.count, 30)
        XCTAssertEqual(Set(listed.map(\.id)).count, 30)
        let copyID = try store.duplicate(id: ids[0])
        XCTAssertNotEqual(copyID, ids[0])
        XCTAssertEqual(store.listDrafts().count, 31)
        try store.delete(id: ids[1])
        XCTAssertEqual(store.listDrafts().count, 30)
        XCTAssertNotNil(try store.load(id: ids[0]).project)
        XCTAssertEqual(try store.load(id: ids[0]).assets.count, 2)
        let copyAssets = try store.load(id: copyID).assets
        XCTAssertEqual(copyAssets.count, 2)
        XCTAssertEqual(try store.load(id: ids[0]).assets.keys, copyAssets.keys)
        XCTAssertLessThan(store.sharedAssetFileCount(), 30 * 2, "duplicating should share files instead of copying every blob")
    }

    func testSharedAssetsStayUntilLastDraftIsDeleted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(overridesContainer: root)
        try store.prepare()
        let photos = makePhotos(2)
        let assets = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })
        var first = ProjectFactory.make(mode: .template, photos: photos)
        first.name = "共享甲"
        var second = ProjectFactory.make(mode: .freeform, photos: photos)
        second.name = "共享乙"
        try store.save(project: first, assets: assets, thumbnailJPEG: nil)
        try store.save(project: second, assets: assets, thumbnailJPEG: nil)
        XCTAssertEqual(store.sharedAssetFileCount(), 2)
        try store.delete(id: first.id)
        XCTAssertEqual(store.listDrafts().count, 1)
        XCTAssertEqual(store.sharedAssetFileCount(), 2)
        XCTAssertEqual(try store.load(id: second.id).assets.count, 2)
        try store.delete(id: second.id)
        XCTAssertTrue(store.listDrafts().isEmpty)
        XCTAssertEqual(store.sharedAssetFileCount(), 0)
    }

    func testLegacyPerDraftAssetFolderStillLoads() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(overridesContainer: root)
        try store.prepare()
        let photos = makePhotos(2)
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.name = "旧版草稿"
        let draft = store.draftsRoot.appendingPathComponent(project.id.uuidString, isDirectory: true)
        let assetsDir = draft.appendingPathComponent("assets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(project).write(to: draft.appendingPathComponent("project.json"))
        for photo in photos {
            try photo.data.write(to: assetsDir.appendingPathComponent("\(photo.id.uuidString).jpg"))
        }
        try Data().write(to: draft.appendingPathComponent(".complete"))
        let loaded = try store.load(id: project.id)
        XCTAssertEqual(loaded.assets.count, 2)
        XCTAssertEqual(Set(loaded.assets.keys), Set(photos.map(\.id)))
        let copyID = try store.duplicate(id: project.id)
        XCTAssertEqual(store.sharedAssetFileCount(), 2)
        XCTAssertEqual(try store.load(id: copyID).assets.count, 2)
    }

    func testExtensionPhotoLimits() {
        XCTAssertEqual(PhotoLimits.validateExtension(1), .tooFew(minimum: 2))
        XCTAssertEqual(PhotoLimits.validateExtension(2), .ok)
        XCTAssertEqual(PhotoLimits.validateExtension(9), .ok)
        XCTAssertEqual(PhotoLimits.validateExtension(10), .tooMany(maximum: 9))
        XCTAssertEqual(PhotoLimits.extensionRange, 2...9)
    }

    func testFiltersDoNotAttachToText() {
        let photos = makePhotos(2)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.objects.append(
            LayerObject(kind: .text, zIndex: 9, text: TextPayload(text: "标题"))
        )
        for object in project.photoLayers {
            project.updateObject(id: object.id) { $0.photo?.filterID = "mono" }
        }
        XCTAssertTrue(project.photoLayers.allSatisfy { $0.photo?.filterID == "mono" })
        XCTAssertNil(project.objects.first { $0.kind == .text }?.photo?.filterID)
    }

    func testLongStripOutputSizeIsComputedAndLabeled() {
        let photos = makePhotos(3)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        var project = ProjectFactory.make(mode: .longStrip, photos: photos)
        project.exportPreference.quality = .standard
        switch ExportGeometry.outputSize(for: project, assets: assets) {
        case .ok(let size):
            XCTAssertEqual(size.width, JiPin.Export.longStripStandard, accuracy: 1)
            XCTAssertGreaterThan(size.height, size.width)
            let label = ExportGeometry.pixelLabel(for: project, assets: assets)
            XCTAssertTrue(label.contains("\(Int(size.width.rounded()))"))
            XCTAssertTrue(label.contains("\(Int(size.height.rounded()))"))
        case .needsChoice:
            XCTFail("3 standard photos should not exceed long-strip limits")
        }
    }

    func testLongStripCropChangesComputedOutputHeight() {
        let photos = makePhotos(2)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        var project = ProjectFactory.make(mode: .longStrip, photos: photos)
        project.exportPreference.quality = .standard
        project.spacing = 0
        project.outerMargin = 0
        guard case .ok(let full) = ExportGeometry.outputSize(for: project, assets: assets) else {
            return XCTFail("expected full long-strip size")
        }
        guard let firstID = project.photoLayers.first?.id else {
            return XCTFail("missing photo")
        }
        project.updateObject(id: firstID) {
            $0.photo?.crop.top = 0.25
            $0.photo?.crop.bottom = 0.25
        }
        guard case .ok(let cropped) = ExportGeometry.outputSize(for: project, assets: assets) else {
            return XCTFail("expected cropped long-strip size")
        }
        XCTAssertEqual(cropped.width, full.width, accuracy: 1)
        XCTAssertLessThan(cropped.height, full.height - 20)
    }

    func testMultilineChineseEnglishEmojiTextIsNotSilentlyTruncated() {
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        if let index = project.objects.firstIndex(where: { $0.kind == .photo }) {
            project.objects[index].transform = CanvasTransform(centerX: 0.12, centerY: 0.12, width: 0.18, height: 0.18)
        }
        project.objects.append(
            LayerObject(
                kind: .text,
                zIndex: 50,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.9, height: 0.16),
                text: TextPayload(
                    text: "你好 Hello\n第二行 🎉\n第三行",
                    fontSize: 0.08,
                    colorHex: "#FFFF00"
                )
            )
        )
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })),
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        let buffer = pixelBuffer(image)
        let upper = yellowCount(buffer, width: 400, height: 400, yRange: 150..<200)
        let lower = yellowCount(buffer, width: 400, height: 400, yRange: 210..<270)
        XCTAssertGreaterThan(upper, 80, "first text lines should be visible, got \(upper)")
        XCTAssertGreaterThan(lower, 80, "later text lines should not be truncated, got \(lower)")
    }

    func testPolaroidStyleLeavesWhiteFrameAroundPhoto() {
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo")
        }
        project.objects[index].transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.8, height: 0.8)
        project.objects[index].photo?.polaroid = true
        project.objects[index].photo?.contentMode = .fill
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })),
            canvasSize: CGSize(width: 200, height: 200),
            preview: false
        )
        let frame = channels(image, x: 100, y: 175)
        let photo = channels(image, x: 100, y: 100)
        XCTAssertGreaterThan(frame.0, 0.8, "polaroid bottom frame should be white, got \(frame)")
        XCTAssertGreaterThan(frame.1, 0.8, "polaroid bottom frame should be white, got \(frame)")
        XCTAssertGreaterThan(photo.0, 0.5, "photo area should remain visible, got \(photo)")
        XCTAssertLessThan(photo.1, 0.5, "photo area should not be the green canvas, got \(photo)")
    }

    func testTransparentPNGHasAlphaAndJPEGFillsBackground() {
        let photos = makePhotos(1)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background.isHidden = true
        project.exportPreference.format = .png
        project.exportPreference.transparentBackground = true
        XCTAssertTrue(CollageRenderer.allowsTransparent(project))
        let size = CGSize(width: 400, height: 400)
        guard let png = CollageRenderer.shared.pngData(project: project, assets: assets, canvasSize: size),
              let pngImage = UIImage(data: png)?.cgImage
        else {
            return XCTFail("png export failed")
        }
        let alpha = pngImage.alphaInfo
        XCTAssertTrue(
            alpha == .premultipliedLast || alpha == .premultipliedFirst || alpha == .last || alpha == .first,
            "expected alpha channel, got \(alpha.rawValue)"
        )

        project.exportPreference.format = .jpeg
        guard let jpeg = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size) else {
            return XCTFail("jpeg export failed")
        }
        XCTAssertFalse(ImageIOHelpers.containsGPS(jpeg))
        XCTAssertFalse(CollageRenderer.allowsTransparent(project))
    }

    func testExtensionExportUses2048LongSideAndKeepsDraftFlag() throws {
        let photos = makePhotos(4)
        let project = ProjectFactory.make(mode: .template, photos: photos, originatedFromExtension: true)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let size = ExportGeometry.extensionOutputSize(for: project, assets: assets)
        XCTAssertEqual(max(size.width, size.height), JiPin.Export.extensionLongSide, accuracy: 1)
        guard let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size) else {
            return XCTFail("extension jpeg failed")
        }
        XCTAssertFalse(ImageIOHelpers.containsGPS(data))

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let writer = DraftStore(overridesContainer: root)
        try writer.prepare()
        try writer.save(project: project, assets: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }), thumbnailJPEG: nil)
        let reader = DraftStore(overridesContainer: root)
        let listed = reader.listDrafts()
        XCTAssertEqual(listed.first?.originatedFromExtension, true)
        XCTAssertEqual(try reader.load(id: project.id).project.originatedFromExtension, true)
    }

    func testPhotoOnlyExportDoesNotAddBrandWatermarkText() {
        let photos = makePhotos(2)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let project = ProjectFactory.make(mode: .template, photos: photos)
        XCTAssertFalse(project.objects.contains(where: { $0.kind == .text }))
        let size = CGSize(width: 800, height: 800)
        let image = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: false)
        XCTAssertGreaterThan(image.size.width, 10)
    }

    private func assertExport(_ project: CollageProject, assets: DataAssetLibrary, quality: ExportQuality) {
        var project = project
        project.exportPreference.quality = quality
        switch ExportGeometry.outputSize(for: project, assets: assets) {
        case .ok(let size), .needsChoice(_, let size):
            XCTAssertGreaterThan(size.width, 10)
            XCTAssertGreaterThan(size.height, 10)
            guard let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size),
                  let image = UIImage(data: data)
            else {
                return XCTFail("\(project.mode) export failed")
            }
            XCTAssertFalse(ImageIOHelpers.containsGPS(data))
            XCTAssertEqual(image.size.width, size.width, accuracy: 1)
            XCTAssertEqual(image.size.height, size.height, accuracy: 1)
        }
    }

    func testFiftyConsecutiveExportsDoNotFail() {
        let photos = makePhotos(4)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.exportPreference.quality = .standard
        for i in 0..<20 {
            project.objects.append(
                LayerObject(
                    kind: i < 10 ? .text : .sticker,
                    zIndex: 40 + i,
                    transform: CanvasTransform(centerX: 0.3 + Double(i % 4) * 0.1, centerY: 0.3, width: 0.2, height: 0.12),
                    text: i < 10 ? TextPayload(text: "标注 \(i)") : nil,
                    sticker: i >= 10 ? StickerPayload(stickerID: StickerCatalog.all[i % StickerCatalog.all.count].id) : nil
                )
            )
        }
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let size = CGSize(width: 1024, height: 1024)
        var lastCount = 0
        for i in 0..<50 {
            guard let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size),
                  data.count > 100
            else {
                return XCTFail("export \(i) failed")
            }
            lastCount = data.count
        }
        XCTAssertGreaterThan(lastCount, 100)
    }

    func testSixtyObjectHDExportCompletes() {
        let photos = makePhotos(16)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.exportPreference.quality = .hd
        for i in 0..<20 {
            project.objects.append(
                LayerObject(
                    kind: .text,
                    zIndex: 40 + i,
                    transform: CanvasTransform(centerX: 0.2 + Double(i % 5) * 0.12, centerY: 0.15, width: 0.18, height: 0.08),
                    text: TextPayload(text: "标注 \(i)")
                )
            )
        }
        for i in 0..<24 {
            project.objects.append(
                LayerObject(
                    kind: .sticker,
                    zIndex: 80 + i,
                    transform: CanvasTransform(centerX: 0.2 + Double(i % 6) * 0.12, centerY: 0.82, width: 0.1, height: 0.1),
                    sticker: StickerPayload(stickerID: StickerCatalog.all[i % StickerCatalog.all.count].id)
                )
            )
        }
        XCTAssertEqual(project.objects.count, 60)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        guard case .ok(let size) = ExportGeometry.outputSize(for: project, assets: assets) else {
            return XCTFail("expected hd size")
        }
        XCTAssertEqual(max(size.width, size.height), JiPin.Export.hdLongSide, accuracy: 1)
        let started = CFAbsoluteTimeGetCurrent()
        guard let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size) else {
            return XCTFail("60-object 4096 export failed")
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        XCTAssertGreaterThan(data.count, 1000)
        XCTAssertLessThan(elapsed, 30, "simulator 60-object export hung: \(elapsed)s")
    }

    func testDoodleEraserRemovesInkWithoutPunchingPhoto() {
        let (photo, data) = splitColorPhoto()
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo")
        }
        project.objects[index].transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1)
        project.objects[index].photo?.contentMode = .fill
        project.objects.append(
            LayerObject(
                kind: .doodle,
                zIndex: 80,
                doodle: DoodlePayload(strokes: [
                    DoodleStroke(
                        points: [CGPoint(x: 0.05, y: 0.5), CGPoint(x: 0.95, y: 0.5)],
                        colorHex: "#FFFF00",
                        lineWidth: 0.12,
                        kind: .line
                    ),
                    DoodleStroke(
                        points: [CGPoint(x: 0.05, y: 0.5), CGPoint(x: 0.35, y: 0.5)],
                        lineWidth: 0.16,
                        isEraser: true,
                        kind: .line
                    )
                ])
            )
        )
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: [photo.id: data]),
            canvasSize: CGSize(width: 200, height: 100),
            preview: false
        )
        let erased = channels(image, x: 30, y: 50)
        let ink = channels(image, x: 160, y: 50)
        XCTAssertGreaterThan(erased.0, 0.55, "eraser should reveal the red photo, got \(erased)")
        XCTAssertLessThan(erased.1, 0.35, "eraser must not leave yellow ink or punch to green canvas, got \(erased)")
        XCTAssertLessThan(erased.2, 0.35, "eraser must not punch a hole to the background, got \(erased)")
        XCTAssertGreaterThan(ink.0, 0.55, "doodle ink should remain where not erased, got \(ink)")
        XCTAssertGreaterThan(ink.1, 0.55, "doodle ink should remain yellow, got \(ink)")
        XCTAssertLessThan(ink.2, 0.45, "doodle ink should remain yellow, got \(ink)")
    }

    func testIncompleteDraftAndCacheClearDoNotDestroySavedProjects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DraftStore(overridesContainer: root)
        try store.prepare()
        let photos = makePhotos(2)
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.name = "保留"
        try store.save(
            project: project,
            assets: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
            thumbnailJPEG: nil
        )
        let marker = store.draftsRoot
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent(".complete")
        try FileManager.default.removeItem(at: marker)
        XCTAssertThrowsError(try store.load(id: project.id)) { error in
            XCTAssertEqual(error as? DraftStoreError, .incomplete)
        }
        XCTAssertTrue(store.listDrafts().isEmpty)

        try Data("cache".utf8).write(to: store.cacheRoot.appendingPathComponent("tmp.bin"))
        XCTAssertGreaterThan(store.cacheSize(), 0)
        var restored = project
        restored.name = "仍在"
        try store.save(
            project: restored,
            assets: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }),
            thumbnailJPEG: nil
        )
        try store.clearExportCache()
        XCTAssertEqual(store.cacheSize(), 0)
        XCTAssertEqual(store.listDrafts().count, 1)
        XCTAssertEqual(try store.load(id: project.id).project.name, "仍在")
    }

    func testCorruptImageIsRejectedAsZeroSize() {
        let garbage = Data("not-an-image".utf8)
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: garbage), .zero)
        XCTAssertNil(ImageIOHelpers.strippedJPEG(from: garbage, quality: 0.9))
    }

    func testOrientedJPEGBakesToUprightPixelsWithoutGPS() {
        let image = solidImage(color: .blue, size: CGSize(width: 400, height: 200))
        guard let data = ImageIOHelpers.jpegWithOrientation(from: image, orientation: 6) else {
            return XCTFail("could not write oriented jpeg")
        }
        let stored = ImageIOHelpers.storedPixelSize(of: data)
        XCTAssertEqual(stored.width, 400, accuracy: 1)
        XCTAssertEqual(stored.height, 200, accuracy: 1)
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: data).width, 200, accuracy: 1)
        XCTAssertEqual(ImageIOHelpers.pixelSize(of: data).height, 400, accuracy: 1)
        guard let baked = ImageIOHelpers.fullImage(from: data) else {
            return XCTFail("bake failed")
        }
        XCTAssertEqual(CGFloat(baked.width), 200, accuracy: 2)
        XCTAssertEqual(CGFloat(baked.height), 400, accuracy: 2)
        guard let stripped = ImageIOHelpers.strippedJPEG(from: data, quality: 0.9) else {
            return XCTFail("strip failed")
        }
        XCTAssertFalse(ImageIOHelpers.containsGPS(stripped))
        let strippedStored = ImageIOHelpers.storedPixelSize(of: stripped)
        XCTAssertEqual(strippedStored.width, 200, accuracy: 2)
        XCTAssertEqual(strippedStored.height, 400, accuracy: 2)
    }

    func testCropTopRemovesVisualTopOfImage() {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let ui = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 100, width: 100, height: 100))
        }
        guard let cgImage = ui.cgImage else { return XCTFail("missing image") }
        var payload = PhotoPayload(assetID: UUID())
        payload.crop = PhotoCrop(top: 0.5)
        let cropped = PhotoEffects.shared.apply(to: cgImage, payload: payload, targetSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(CGFloat(cropped.height), 100, accuracy: 2)
        let preview = UIImage(cgImage: cropped)
        let top = channels(preview, x: 50, y: 10)
        let bottom = channels(preview, x: 50, y: 90)
        XCTAssertGreaterThan(top.2, top.0, "top crop should leave the lower blue half, got \(top)")
        XCTAssertGreaterThan(bottom.2, bottom.0, "remaining half should stay blue, got \(bottom)")
    }

    func testAlbumDecorationDrawsImportedImagePixels() {
        let yellow = solidImage(color: .yellow, size: CGSize(width: 160, height: 160))
        let data = ImageIOHelpers.pngData(from: yellow) ?? Data()
        let decoration = ImportedPhoto(filename: "deco.png", data: data, pixelSize: CGSize(width: 160, height: 160), utType: "public.png")
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        if let index = project.objects.firstIndex(where: { $0.kind == .photo }) {
            project.objects[index].transform = CanvasTransform(centerX: 0.12, centerY: 0.12, width: 0.16, height: 0.16)
        }
        project.objects.append(
            LayerObject(
                kind: .sticker,
                zIndex: 40,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.4, height: 0.4),
                sticker: StickerPayload(stickerID: "custom-image", assetID: decoration.id)
            )
        )
        var images = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })
        images[decoration.id] = data
        let rendered = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: images),
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        let buffer = pixelBuffer(rendered)
        XCTAssertGreaterThan(
            yellowCount(buffer, width: 400, height: 400, yRange: 140..<260),
            80,
            "album decoration should draw the imported image, not a placeholder"
        )
    }

    func testZeroSpacingGridDoesNotShowBackgroundAtSeam() {
        let photos = makePhotos(4)
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.layoutID = "g4-grid"
        if let layout = CollageGridLayoutCatalog.layout(id: "g4-grid") {
            ProjectFactory.applyLayout(layout, to: &project)
        }
        project.spacing = 0
        project.outerMargin = 0
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let image = CollageRenderer.shared.render(
            project: project,
            assets: assets,
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        XCTAssertEqual(image.size, CGSize(width: 400, height: 400))
        let interiors = [
            channels(image, x: 50, y: 50),
            channels(image, x: 350, y: 50),
            channels(image, x: 50, y: 350),
            channels(image, x: 350, y: 350)
        ]
        XCTAssertTrue(
            interiors.contains { $0.0 > 0.4 || $0.2 > 0.4 },
            "cells should contain photo color, got \(interiors)"
        )
        let nearSeamLeft = channels(image, x: 196, y: 80)
        let nearSeamRight = channels(image, x: 204, y: 80)
        XCTAssertFalse(
            nearSeamLeft.1 > 0.7 && nearSeamLeft.0 < 0.25 && nearSeamLeft.2 < 0.25
                && nearSeamRight.1 > 0.7 && nearSeamRight.0 < 0.25 && nearSeamRight.2 < 0.25,
            "zero spacing should not leave a green background hairline, got left \(nearSeamLeft) right \(nearSeamRight)"
        )
    }

    func testMosaicAppliesAfterCropReducesPixelSize() {
        let image = solidImage(color: .green, size: CGSize(width: 400, height: 400))
        var payload = PhotoPayload(assetID: UUID())
        payload.crop = PhotoCrop(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25)
        payload.mosaics = [MosaicStroke(points: [CGPoint(x: 0.5, y: 0.5)], radius: 0.2)]
        let result = PhotoEffects.shared.apply(to: image, payload: payload, targetSize: CGSize(width: 200, height: 200))
        XCTAssertEqual(CGFloat(result.width), 200, accuracy: 2)
        XCTAssertEqual(CGFloat(result.height), 200, accuracy: 2)
    }

    func testMosaicFollowsOriginalPhotoContentWhenCropped() {
        let source = checkerboardImage(size: CGSize(width: 400, height: 400), cell: 3)
        var payload = PhotoPayload(assetID: UUID())
        payload.crop = PhotoCrop(left: 0.5)
        let croppedOnly = UIImage(cgImage: PhotoEffects.shared.apply(to: source, payload: payload, targetSize: .zero))

        payload.mosaics = [MosaicStroke(points: [CGPoint(x: 0.2, y: 0.5)], radius: 0.1)]
        let outside = UIImage(cgImage: PhotoEffects.shared.apply(to: source, payload: payload, targetSize: .zero))
        XCTAssertLessThan(
            meanAbsDiff(croppedOnly, outside),
            0.02,
            "mosaic on the cropped-away half should not appear on the remaining photo"
        )

        payload.mosaics = [MosaicStroke(points: [CGPoint(x: 0.75, y: 0.5)], radius: 0.12)]
        let inside = UIImage(cgImage: PhotoEffects.shared.apply(to: source, payload: payload, targetSize: .zero))
        XCTAssertGreaterThan(
            meanAbsDiff(croppedOnly, inside, xRange: 80..<120, yRange: 180..<220),
            0.04,
            "mosaic on remaining content should stay on the same original pixels after crop"
        )
    }

    func testMosaicFollowsLayerRotation() {
        let source = checkerboardImage(size: CGSize(width: 200, height: 100), cell: 3)
        let data = UIImage(cgImage: source).pngData() ?? Data()
        let photo = ImportedPhoto(
            filename: "board.png",
            data: data,
            pixelSize: CGSize(width: 200, height: 100),
            utType: "public.png"
        )
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo")
        }
        project.objects[index].transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1)
        project.objects[index].photo?.contentMode = .fill
        project.objects[index].photo?.mosaics = [MosaicStroke(points: [CGPoint(x: 0.18, y: 0.5)], radius: 0.12)]
        let assets = DataAssetLibrary(images: [photo.id: data])
        let canvas = CGSize(width: 200, height: 100)
        let upright = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: canvas, preview: false)
        var plain = project
        plain.objects[index].photo?.mosaics = []
        let unmarked = CollageRenderer.shared.render(project: plain, assets: assets, canvasSize: canvas, preview: false)
        XCTAssertGreaterThan(
            meanAbsDiff(upright, unmarked, xRange: 8..<48, yRange: 30..<70),
            0.03,
            "mosaic should change the left side before rotation"
        )
        project.objects[index].transform.rotation = 180
        let rotated = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: canvas, preview: false)
        XCTAssertGreaterThan(
            meanAbsDiff(upright, rotated, xRange: 152..<192, yRange: 30..<70),
            0.03,
            "180° rotation should move the mosaicked region to the opposite side"
        )
    }

    func testMonoFilterDesaturatesPhotoPixels() {
        let source = solidImage(color: .red, size: CGSize(width: 200, height: 200))
        var payload = PhotoPayload(assetID: UUID())
        payload.filterID = "mono"
        let filtered = PhotoEffects.shared.apply(to: source, payload: payload, targetSize: CGSize(width: 200, height: 200))
        let sample = channels(UIImage(cgImage: filtered), x: 100, y: 100)
        XCTAssertEqual(sample.0, sample.1, accuracy: 0.12)
        XCTAssertEqual(sample.1, sample.2, accuracy: 0.12)
        XCTAssertGreaterThan(sample.0, 0.08)
        let unfiltered = channels(UIImage(cgImage: source), x: 100, y: 100)
        XCTAssertGreaterThan(unfiltered.0, 0.8)
        XCTAssertLessThan(unfiltered.1, 0.2)
    }

    @MainActor
    func testCompareOriginalPreviewDoesNotChangeExportPixels() {
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#808080")
        project.updateObject(id: project.photoLayers[0].id) {
            $0.transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.8, height: 0.8)
            $0.photo?.filterID = "mono"
            $0.photo?.contentMode = .fill
        }
        let assets = AssetLibrary(images: [photos[0].id: photos[0].data])
        let session = EditorSession(project: project, assets: assets)
        session.compareOriginal = true
        let preview = session.previewImage(maxSide: 400)
        XCTAssertEqual(session.project.photoLayers[0].photo?.filterID, "mono")
        guard let preview else { return XCTFail("missing preview") }
        let exported = CollageRenderer.shared.render(
            project: session.project,
            assets: DataAssetLibrary(images: assets.images),
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        let previewSample = channels(preview, x: Int(preview.size.width / 2), y: Int(preview.size.height / 2))
        let exportSample = channels(exported, x: 200, y: 200)
        XCTAssertGreaterThan(previewSample.0 - previewSample.1, 0.15, "compare-original preview should still look like the red photo, got \(previewSample)")
        XCTAssertEqual(exportSample.0, exportSample.1, accuracy: 0.15)
        XCTAssertEqual(exportSample.1, exportSample.2, accuracy: 0.15)
    }

    func testArrowShapeUsesFillColorOnGreenBackground() {
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        if let index = project.objects.firstIndex(where: { $0.kind == .photo }) {
            project.objects[index].transform = CanvasTransform(centerX: 0.08, centerY: 0.08, width: 0.1, height: 0.1)
        }
        project.objects.append(
            LayerObject(
                kind: .shape,
                zIndex: 20,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.5, width: 0.72, height: 0.28),
                shape: ShapePayload(shapeID: "arrow", fillHex: "#FF0000", stroke: StrokeStyle(colorHex: "#0000FF", width: 0.06))
            )
        )
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: [photos[0].id: photos[0].data]),
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        let sample = channels(image, x: 180, y: 200)
        XCTAssertGreaterThan(sample.0, 0.7, "arrow fill should be red, got \(sample)")
        XCTAssertLessThan(sample.1, 0.25)
    }

    func testUnknownFontFallsBackAndStillDrawsGlyphs() {
        let photos = makePhotos(1)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        if let index = project.objects.firstIndex(where: { $0.kind == .photo }) {
            project.objects[index].transform = CanvasTransform(centerX: 0.1, centerY: 0.1, width: 0.12, height: 0.12)
        }
        project.objects.append(
            LayerObject(
                kind: .text,
                zIndex: 50,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.45, width: 0.9, height: 0.2),
                text: TextPayload(text: "回退字体 Hello", fontName: "DefinitelyMissing-Font", fontSize: 0.08, colorHex: "#FFFF00")
            )
        )
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) })),
            canvasSize: CGSize(width: 400, height: 400),
            preview: false
        )
        let buffer = pixelBuffer(image)
        XCTAssertGreaterThan(
            yellowCount(buffer, width: 400, height: 400, yRange: 140..<230),
            20,
            "missing font should fall back and still draw text"
        )
    }

    func testPreviewMatchesExportLayoutAtSameCanvasSize() {
        let photos = makePhotos(4)
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.layoutID = "g4-grid"
        if let layout = CollageGridLayoutCatalog.layout(id: "g4-grid") {
            ProjectFactory.applyLayout(layout, to: &project)
        }
        project.spacing = 8
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let canvas = CGSize(width: 400, height: 400)
        let preview = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: canvas, preview: true)
        let exported = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: canvas, preview: false)
        XCTAssertEqual(preview.size, exported.size)
        XCTAssertLessThan(meanAbsDiff(preview, exported), 0.08)
    }

    func testExportSizeEstimateIsLabeledAndBelowEncodedJPEG() {
        let photos = makePhotos(4)
        let project = ProjectFactory.make(mode: .template, photos: photos)
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        guard case .ok(let size) = ExportGeometry.outputSize(for: project, assets: assets) else {
            return XCTFail("expected an unconstrained template size")
        }
        let estimate = ExportGeometry.estimatedByteCount(size: size, format: .jpeg)
        XCTAssertGreaterThan(estimate, 100_000)
        XCTAssertTrue(ExportGeometry.estimatedSizeLabel(size: size, format: .jpeg).contains("预估"))
        let pngEstimate = ExportGeometry.estimatedByteCount(size: size, format: .png)
        XCTAssertGreaterThan(pngEstimate, estimate)
    }

    func testHEICAndPNGImportRemoveGPSPreservePNGAndKeepOrder() {
        let first = solidImage(color: .red, size: CGSize(width: 240, height: 180))
        let second = solidImage(color: .blue, size: CGSize(width: 180, height: 240))
        guard let png = ImageIOHelpers.pngData(from: first) else {
            return XCTFail("png encode failed")
        }
        var items: [(filename: String, data: Data?)] = [("one.png", png)]
        if let heic = ImageIOHelpers.heicData(from: second) {
            items.append(("two.heic", heic))
        }
        items.append(("bad", Data("nope".utf8)))
        let result = ExtensionIngest.process(items)
        XCTAssertEqual(result.photos.first?.filename, "one.png")
        XCTAssertTrue(result.photos.allSatisfy { !ImageIOHelpers.containsGPS($0.data) })
        XCTAssertEqual(result.photos.first?.utType, "public.png")
        XCTAssertTrue(result.photos.allSatisfy { $0.utType == ImageIOHelpers.typeIdentifier(of: $0.data) })
        XCTAssertEqual(result.failed.count, 1)
        if items.contains(where: { $0.filename == "two.heic" }) {
            XCTAssertEqual(result.photos.map(\.filename), ["one.png", "two.heic"])
        }
    }

    func testExtensionIngestCapsAtNineAndReportsOverflow() {
        let image = solidImage(color: .red, size: CGSize(width: 80, height: 80))
        let jpeg = ImageIOHelpers.jpegData(from: image, quality: 0.9)
        let items = (0..<12).map { ("p\($0).jpg", jpeg) }
        let result = ExtensionIngest.process(items)
        XCTAssertEqual(result.photos.count, 9)
        XCTAssertEqual(result.overflowCount, 3)
        XCTAssertEqual(result.photos.map(\.filename), (0..<9).map { "p\($0).jpg" })
    }

    func testExtensionIngestDoesNotSilentlyDropFailedBeforeLayout() {
        let image = solidImage(color: .orange, size: CGSize(width: 120, height: 120))
        let jpeg = ImageIOHelpers.jpegData(from: image, quality: 0.9)
        let result = ExtensionIngest.process([
            ("ok.jpg", jpeg),
            ("broken", Data([0x00, 0x01])),
            ("ok2.jpg", jpeg)
        ])
        XCTAssertEqual(result.photos.count, 2)
        XCTAssertEqual(result.failed.count, 1)
        XCTAssertEqual(result.photos[0].filename, "ok.jpg")
        XCTAssertEqual(result.photos[1].filename, "ok2.jpg")
        XCTAssertEqual(PhotoLimits.validateExtension(result.photos.count), .ok)
    }

    func testLongChineseTextWrapsInsteadOfSilentTruncate() {
        let photos = makePhotos(2)
        var project = ProjectFactory.make(mode: .freeform, photos: photos)
        let long = String(repeating: "旅行记录今天的风景与晚餐菜单ABCDEFG🎉", count: 8)
        project.objects.append(
            LayerObject(
                kind: .text,
                zIndex: 40,
                transform: CanvasTransform(centerX: 0.5, centerY: 0.2, width: 0.8, height: 0.08),
                text: TextPayload(text: long)
            )
        )
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        let image = CollageRenderer.shared.render(
            project: project,
            assets: assets,
            canvasSize: CGSize(width: 800, height: 800),
            preview: false
        )
        XCTAssertGreaterThan(image.size.height, 10)
        XCTAssertTrue(project.objects.contains(where: { $0.text?.text == long }))
    }

    func testHorizontalFlipIsVisibleInExportPixels() {
        let (photo, data) = splitColorPhoto()
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.background = BackgroundSpec(kind: .solid, colorHex: "#FFFFFF")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo layer")
        }
        project.objects[index].transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1)
        project.objects[index].photo?.contentMode = .fill
        project.objects[index].transform.scaleX = -1
        let assets = DataAssetLibrary(images: [photo.id: data])
        let image = CollageRenderer.shared.render(
            project: project,
            assets: assets,
            canvasSize: CGSize(width: 200, height: 100),
            preview: false
        )
        let left = channels(image, x: 20, y: 50)
        let right = channels(image, x: 180, y: 50)
        XCTAssertGreaterThan(left.2, left.0, "flipped left side should be blue, got \(left)")
        XCTAssertGreaterThan(right.0, right.2, "flipped right side should be red, got \(right)")
    }

    func testVerticalFlipIsVisibleInExportPixels() {
        let size = CGSize(width: 100, height: 200)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let ui = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 100, width: 100, height: 100))
        }
        let data = ui.pngData() ?? Data()
        let photo = ImportedPhoto(filename: "vsplit.png", data: data, pixelSize: size, utType: "public.png")
        var project = ProjectFactory.make(mode: .freeform, photos: [photo])
        project.background = BackgroundSpec(kind: .solid, colorHex: "#FFFFFF")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo layer")
        }
        project.objects[index].transform = CanvasTransform(centerX: 0.5, centerY: 0.5, width: 1, height: 1, scaleY: -1)
        project.objects[index].photo?.contentMode = .fill
        let image = CollageRenderer.shared.render(
            project: project,
            assets: DataAssetLibrary(images: [photo.id: data]),
            canvasSize: size,
            preview: false
        )
        let top = channels(image, x: 50, y: 20)
        let bottom = channels(image, x: 50, y: 180)
        XCTAssertGreaterThan(top.2, top.0, "flipped top should be blue, got \(top)")
        XCTAssertGreaterThan(bottom.0, bottom.2, "flipped bottom should be red, got \(bottom)")
    }

    func testPhotoCropOffsetShiftsContentInTemplateCell() {
        let (photo, data) = splitColorPhoto()
        let photos = [photo, photo]
        var project = ProjectFactory.make(mode: .template, photos: photos)
        if let layout = CollageGridLayoutCatalog.layout(id: "g2-h") {
            ProjectFactory.applyLayout(layout, to: &project)
        }
        project.spacing = 0
        project.outerMargin = 0
        project.background = BackgroundSpec(kind: .solid, colorHex: "#00FF00")
        guard let index = project.objects.firstIndex(where: { $0.kind == .photo }) else {
            return XCTFail("missing photo")
        }
        project.objects[index].photo?.contentMode = .fit
        project.objects[index].photo?.crop.offsetX = 0.35
        let assets = DataAssetLibrary(images: [photo.id: data])
        let image = CollageRenderer.shared.render(
            project: project,
            assets: assets,
            canvasSize: CGSize(width: 200, height: 100),
            preview: false
        )
        let left = channels(image, x: 8, y: 50)
        XCTAssertGreaterThan(left.1, 0.4, "panned cell should reveal background on the uncovered side, got \(left)")
    }

    func testHD4096ExportCompletesForNinePhotoGrid() {
        let photos = makePhotos(9)
        var project = ProjectFactory.make(mode: .template, photos: photos)
        project.exportPreference.quality = .hd
        let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
        guard case .ok(let size) = ExportGeometry.outputSize(for: project, assets: assets) else {
            return XCTFail("expected hd size")
        }
        XCTAssertEqual(max(size.width, size.height), JiPin.Export.hdLongSide, accuracy: 1)
        let started = CFAbsoluteTimeGetCurrent()
        guard let data = CollageRenderer.shared.jpegData(project: project, assets: assets, canvasSize: size) else {
            return XCTFail("4096 export failed")
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        XCTAssertGreaterThan(data.count, 1000)
        XCTAssertLessThan(elapsed, 20, "simulator 4096 export hung or is far slower than expected: \(elapsed)s")
    }

    private func splitColorPhoto() -> (ImportedPhoto, Data) {
        let size = CGSize(width: 200, height: 100)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let ui = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        }
        let data = ui.pngData() ?? Data()
        let photo = ImportedPhoto(
            filename: "split.png",
            data: data,
            pixelSize: size,
            utType: "public.png"
        )
        return (photo, data)
    }

    private func channels(_ image: UIImage, x: Int, y: Int) -> (CGFloat, CGFloat, CGFloat) {
        let width = Int(image.size.width)
        let buffer = pixelBuffer(image)
        let i = (y * width + x) * 4
        return (
            CGFloat(buffer[i]) / 255,
            CGFloat(buffer[i + 1]) / 255,
            CGFloat(buffer[i + 2]) / 255
        )
    }

    private func pixelBuffer(_ image: UIImage) -> [UInt8] {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let cgImage = image.cgImage else { return }
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return buffer
    }

    private func yellowCount(_ buffer: [UInt8], width: Int, height: Int, yRange: Range<Int>) -> Int {
        var count = 0
        for y in yRange {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let r = CGFloat(buffer[i]) / 255
                let g = CGFloat(buffer[i + 1]) / 255
                let b = CGFloat(buffer[i + 2]) / 255
                if r > 0.55 && g > 0.55 && b < 0.45 { count += 1 }
            }
        }
        return count
    }

    private func checkerboardImage(size: CGSize, cell: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let width = Int(size.width)
            let height = Int(size.height)
            for y in stride(from: 0, to: height, by: cell) {
                for x in stride(from: 0, to: width, by: cell) {
                    let on = ((x / cell) + (y / cell)) % 2 == 0
                    (on ? UIColor.red : UIColor.blue).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }
        return image.cgImage!
    }

    private func meanAbsDiff(
        _ a: UIImage,
        _ b: UIImage,
        xRange: Range<Int>? = nil,
        yRange: Range<Int>? = nil
    ) -> Double {
        let width = min(Int(a.size.width), Int(b.size.width))
        let height = min(Int(a.size.height), Int(b.size.height))
        let xs = xRange ?? 0..<width
        let ys = yRange ?? 0..<height
        let bufferA = pixelBuffer(a)
        let bufferB = pixelBuffer(b)
        var total = 0.0
        var count = 0
        for y in ys {
            for x in xs {
                let i = (y * width + x) * 4
                total += abs(Double(bufferA[i]) - Double(bufferB[i])) / 255
                total += abs(Double(bufferA[i + 1]) - Double(bufferB[i + 1])) / 255
                total += abs(Double(bufferA[i + 2]) - Double(bufferB[i + 2])) / 255
                count += 3
            }
        }
        return count == 0 ? 0 : total / Double(count)
    }

    func testEveryLayoutAndPosterRendersNonEmptyImage() {
        for layout in CollageGridLayoutCatalog.all {
            let photos = makePhotos(layout.photoCount)
            let project = ProjectFactory.make(mode: .template, photos: photos, layoutID: layout.id)
            let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
            let image = CollageRenderer.shared.render(
                project: project,
                assets: assets,
                canvasSize: CGSize(width: 240, height: 240),
                preview: true
            )
            XCTAssertGreaterThan(image.size.width, 1, "layout \(layout.id) rendered empty")
        }
        for poster in PosterTemplateCatalog.all {
            let photos = makePhotos(poster.photoCount)
            let project = ProjectFactory.make(mode: .poster, photos: photos, posterID: poster.id)
            let assets = DataAssetLibrary(images: Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.data) }))
            let size = project.canvas.size(maxLongSide: 240)
            let image = CollageRenderer.shared.render(project: project, assets: assets, canvasSize: size, preview: true)
            XCTAssertGreaterThan(image.size.height, 1, "poster \(poster.id) rendered empty")
        }
    }

    private func makePhotos(_ count: Int) -> [ImportedPhoto] {
        let colors: [UIColor] = [.red, .orange, .blue, .green, .purple, .cyan]
        return (0..<count).map { index in
            let image = solidImage(color: colors[index % colors.count], size: CGSize(width: 600, height: 800))
            let data = ImageIOHelpers.jpegData(from: image, quality: 0.9) ?? Data()
            return ImportedPhoto(
                filename: "p\(index).jpg",
                data: data,
                pixelSize: CGSize(width: 600, height: 800),
                utType: "public.jpeg"
            )
        }
    }

    private func solidImage(color: UIColor, size: CGSize) -> CGImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.cgImage!
    }
}
